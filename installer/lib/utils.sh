#!/usr/bin/env bash
# utils.sh - Utilitários compartilhados do framework Arch-gabrln
#
# Filosofia de privilégios:
#   - O entrypoint roda como root (via `sudo bash` no install.sh, que é
#     inevitável: polkit não tem agent no bootstrap).
#   - Para executar como o usuário real, usamos `runuser -u USER --` em vez
#     de `sudo -u USER --`. Runuser troca o UID sem precisar de NOPASSWD
#     sudoers — o que seria o ponto de entrada para o antigo
#     setup_temp_sudoers.
#   - Polkit fica reservado para helpers invocados pelo próprio usuário
#     (gabrln-helper via pkexec) e é instalado/desinstalado por uma função
#     dedicada em errors.sh (setup_polkit_policy).

set -euo pipefail

if [[ -n "${_LIB_UTILS_SH:-}" ]]; then return 0; fi
_LIB_UTILS_SH=1

# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Diretório de cache para resultados de TOML parsing. Limpo no EXIT.
_TOML_CACHE_DIR=""

# Detecta o usuário real e seu HOME.
# Deve ser chamado após confirmar que o script roda como root.
detect_real_user() {
  if [[ "${EUID:-}" -ne 0 ]]; then
    log_error "Este comando deve ser executado com sudo."
    exit 1
  fi

  if [[ -z "${SUDO_USER:-}" ]]; then
    log_error "Não foi possível determinar SUDO_USER. Execute via 'sudo ./gabrln ...'."
    exit 1
  fi

  REAL_USER="$SUDO_USER"
  USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

  if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
    log_error "Não foi possível determinar o HOME do usuário '$REAL_USER'."
    exit 1
  fi

  export REAL_USER USER_HOME
}

# Inicializa o cache de TOML. Idempotente.
_toml_cache_init() {
  if [[ -z "$_TOML_CACHE_DIR" ]]; then
    _TOML_CACHE_DIR=$(mktemp -d -t gabrln-toml-XXXXXX) || {
      log_warn "Não foi possível criar cache TOML; usando Python a cada chamada."
      _TOML_CACHE_DIR=""
    }
  fi
}

# Limpa o cache de TOML. Registrado no EXIT trap por gabrln.
toml_cache_cleanup() {
  if [[ -n "$_TOML_CACHE_DIR" && -d "$_TOML_CACHE_DIR" ]]; then
    rm -rf "$_TOML_CACHE_DIR" 2>/dev/null || true
  fi
}

# Hash estável de um path (file ou dir) para usar como chave de cache.
_path_hash() {
  local p="$1"
  printf '%s' "$p" | sha256sum | awk '{print $1}' | head -c 16
}

# Lê um valor simples de um TOML via Python tomllib. Usa cache em /tmp.
# Uso: toml_get "arquivo.toml" "secao.chave" [default]
toml_get() {
  local file="$1"
  local key="$2"
  local default="${3:-}"

  if [[ ! -f "$file" ]]; then
    echo "$default"
    return 0
  fi

  # Se a saída for multi-linha (lista), o cache não ajuda — cai para Python direto.
  if [[ "$key" == *"[]"* || "$key" == *".*" ]]; then
    _toml_get_raw "$file" "$key" "$default"
    return $?
  fi

  _toml_cache_init
  local cache_key
  cache_key="$(_path_hash "$file")-$(printf '%s' "$key" | tr '/' '_')"
  local cache_file="$_TOML_CACHE_DIR/$cache_key"
  if [[ -f "$cache_file" ]]; then
    cat "$cache_file"
    return 0
  fi

  local result
  result=$(_toml_get_raw "$file" "$key" "$default")
  if [[ -n "$_TOML_CACHE_DIR" ]]; then
    echo "$result" >"$cache_file" 2>/dev/null || true
  fi
  echo "$result"
}

_toml_get_raw() {
  local file="$1"
  local key="$2"
  local default="$3"

  python3 - "$file" "$key" "$default" <<'PY'
import sys, tomllib
file, key, default = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(file, "rb") as f:
        data = tomllib.load(f)
    for part in key.split("."):
        if not isinstance(data, dict) or part not in data:
            print(default)
            sys.exit(0)
        data = data[part]
    if isinstance(data, list):
        print("\n".join(str(x) for x in data))
    elif isinstance(data, bool):
        print("true" if data else "false")
    elif isinstance(data, (int, float)):
        print(data)
    else:
        print(data)
except Exception as e:
    print(default)
PY
}

# Lista as chaves de uma tabela TOML.
# Uso: toml_keys "arquivo.toml" "secao"
toml_keys() {
  local file="$1"
  local section="${2:-}"

  python3 - "$file" "$section" <<'PY'
import sys, tomllib
file, section = sys.argv[1], sys.argv[2]
try:
    with open(file, "rb") as f:
        data = tomllib.load(f)
    if section:
        for part in section.split("."):
            data = data.get(part, {}) if isinstance(data, dict) else {}
    if isinstance(data, dict):
        print("\n".join(str(k) for k in data.keys()))
except Exception:
    pass
PY
}

# Extrai uma lista de strings de um array TOML.
# Uso: toml_list "arquivo.toml" "secao.chave"
toml_list() {
  local file="$1"
  local key="$2"
  python3 - "$file" "$key" <<'PY'
import sys, tomllib
file, key = sys.argv[1], sys.argv[2]
try:
    with open(file, "rb") as f:
        data = tomllib.load(f)
    for part in key.split("."):
        if not isinstance(data, dict) or part not in data:
            sys.exit(0)
        data = data[part]
    if isinstance(data, list):
        for item in data:
            if isinstance(item, str):
                print(item)
            else:
                print(item.get("name", "") if isinstance(item, dict) else item)
except Exception:
    pass
PY
}

# Extrai campos específicos de uma lista de tabelas TOML.
# Uso: toml_list_get "arquivo.toml" "secao" "campo"
toml_list_get() {
  local file="$1"
  local key="$2"
  local field="$3"
  python3 - "$file" "$key" "$field" <<'PY'
import sys, tomllib
file, key, field = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(file, "rb") as f:
        data = tomllib.load(f)
    cur = data
    for part in key.split("."):
        cur = cur.get(part, {}) if isinstance(cur, dict) else {}
    if isinstance(cur, list):
        for item in cur:
            if isinstance(item, dict):
                v = item.get(field, "")
                if v is not None:
                    print(v)
except Exception:
    pass
PY
}

# Executa um comando como o usuário real, preservando UID/GID/PATH/HOME.
# Substitui o antigo `sudo -u USER --preserve-env=PATH,HOME`.
#
# Notas:
#  - `runuser` não precisa de NOPASSWD sudoers (estamos trocando UID, não
#    escalando privilégios).
#  - `bash -lc` carrega /etc/profile, ~/.bash_profile etc. Use a versão
#    sem `-l` se quiser shell não-login.
#  - set -e -o pipefail dentro do subshell para que falhe rápido.
run_as_user() {
  local cmd="$1"
  shift || true
  if [[ "${EUID:-}" -eq 0 && -n "${REAL_USER:-}" ]]; then
    # shellcheck disable=SC2024
    runuser -u "$REAL_USER" -- bash -lc "$cmd" "$@"
  else
    bash -lc "$cmd" "$@"
  fi
}

# Variante sem login shell. Mais rápida, sem carregar profile.
run_as_user_fast() {
  local cmd="$1"
  shift || true
  if [[ "${EUID:-}" -eq 0 && -n "${REAL_USER:-}" ]]; then
    # shellcheck disable=SC2024
    runuser -u "$REAL_USER" -- bash -c "$cmd" "$@"
  else
    bash -c "$cmd" "$@"
  fi
}

# Verifica se um comando existe no PATH.
is_command() {
  command -v "$1" &>/dev/null
}

# Verifica conectividade com a internet (github.com como referência).
has_internet() {
  curl -fsSI --max-time 5 https://github.com &>/dev/null
}

# Verifica espaço livre mínimo em disco (bytes).
# Verifica $USER_HOME E / — pacotes pacman escrevem em /, dotfiles em ~.
has_free_space() {
  local min_bytes="${1:-5368709120}" # 5 GiB padrão
  local path_ok=1

  for path in "${USER_HOME:-/}" "/"; do
    [[ -d "$path" ]] || continue
    local available
    available=$(df -B1 "$path" 2>/dev/null | awk 'NR==2 {print $4}') || continue
    if [[ "$available" -lt "$min_bytes" ]]; then
      log_warn "Espaço em $path: $available bytes (mínimo: $min_bytes)."
      path_ok=0
    fi
  done

  [[ "$path_ok" -eq 1 ]]
}

# Confirmação interativa (Y/n padrão).
# Uso: confirm "mensagem"
confirm() {
  local message="${1:-Continuar?}"
  local default="${2:-n}" # y ou n
  local prompt="$message ["
  if [[ "$default" == "y" ]]; then
    prompt+="Y/n"
  else
    prompt+="y/N"
  fi
  prompt+="] "

  local response
  read -r -p "$prompt" response || return 1
  response=${response,,}
  if [[ -z "$response" ]]; then
    response="$default"
  fi
  [[ "$response" == "y" || "$response" == "s" ]]
}

# Verifica se um pacote está instalado (via pacman -Q).
pkg_installed() {
  pacman -Q "$1" &>/dev/null
}

# Verifica se uma unit systemd existe.
systemd_unit_exists() {
  systemctl list-unit-files "$1" &>/dev/null
}

# Garante que um diretório pertence ao usuário real. Cria se não existir.
chown_user_path() {
  local path="$1"
  if [[ -e "$path" ]]; then
    chown -R "$REAL_USER:$REAL_USER" "$path" 2>/dev/null || true
  else
    mkdir -p "$path"
    chown "$REAL_USER:$REAL_USER" "$path"
  fi
}

# Verifica se um comando existe para o usuário real (sem privilégios).
command_exists_user() {
  runuser -u "$REAL_USER" -- bash -c "command -v '$1'" &>/dev/null
}

# Detecta se estamos em ambiente chroot (sem /proc/1 visível).
is_in_chroot() {
  [[ "$(stat -c %d:%i / 2>/dev/null)" != "$(stat -c %d:%i /proc/1/root/ 2>/dev/null)" ]]
}

# Verifica se o usuário real está em um grupo.
user_in_group() {
  local group="$1"
  id -Gn "$REAL_USER" 2>/dev/null | tr ' ' '\n' | grep -qx "$group"
}

# Retorna os kernels CachyOS instalados.
cachyos_installed_kernels() {
  pacman -Qq 2>/dev/null | grep '^linux-cachyos' || true
}
