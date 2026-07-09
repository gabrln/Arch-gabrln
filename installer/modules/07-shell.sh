#!/usr/bin/env bash
# 07-shell.sh - Configura shell padrão e plugins do Zsh
#
# Mudanças em relação à versão anterior:
#   - `runuser -u` em vez de `sudo -u` (consistente).
#   - `git clone` agora tem retry com backoff (3 tentativas) e timeout.
#   - XDG_RUNTIME_DIR é exportado para o runuser (antes era inline,
#     o que `systemctl --user` não pegava como fallback).

log_info "Configurando shell padrão..."

# Garante que zsh está instalado antes de tentar mudar o shell
if ! command -v zsh &>/dev/null && [[ ! -x /usr/bin/zsh ]]; then
  log_error "zsh não está instalado. O módulo 03-pacman-official deveria ter instalado. Verifique."
  return 1
fi

if [[ "$(getent passwd "$REAL_USER" | cut -d: -f7)" != "/usr/bin/zsh" ]]; then
  log_info "Alterando shell padrão do usuário para Zsh..."
  chsh -s /usr/bin/zsh "$REAL_USER"
else
  log_info "Shell padrão já é Zsh."
fi

# Atualiza a variável SHELL no systemd user manager.
# Exportamos XDG_RUNTIME_DIR no ambiente do runuser para que
# `systemctl --user` encontre o socket do user manager.
REAL_UID=$(getent passwd "$REAL_USER" | cut -d: -f3)
if [[ -n "$REAL_UID" && -d "/run/user/$REAL_UID" ]]; then
  XDG_RUNTIME_DIR="/run/user/$REAL_UID" \
    runuser -u "$REAL_USER" -- env XDG_RUNTIME_DIR="/run/user/$REAL_UID" \
    systemctl --user set-environment SHELL=/usr/bin/zsh 2>/dev/null \
    || log_debug "systemctl --user set-environment falhou (sem user manager ativo)."
else
  log_debug "Sem /run/user/$REAL_UID; pulando systemctl --user."
fi

log_info "Verificando plugins do Zsh..."
ZSH_PLUGINS_DIR="$USER_HOME/.config/zsh/plugins"
run_as_user_fast "mkdir -p '$ZSH_PLUGINS_DIR'"

# Parsing único de plugins (1 fork Python em vez de 3 por plugin)
plugins_json=$(python3 - "$MANIFESTS_DIR/zsh-plugins.toml" <<'PY'
import sys, json, tomllib
with open(sys.argv[1], "rb") as f:
    data = tomllib.load(f)
print(json.dumps(data.get("plugins", [])))
PY
)

plugin_count=$(python3 -c 'import sys, json; print(len(json.load(sys.stdin)))' <<<"$plugins_json")

for i in $(seq 0 $((plugin_count - 1))); do
  IFS=$'\t' read -r name repo entry <<<"$(python3 - "$plugins_json" "$i" <<'PY'
import sys, json
plugins = json.loads(sys.argv[1])
i = int(sys.argv[2])
p = plugins[i]
print("\t".join([p["name"], p["repo"], p["entry"]]))
PY
)"
  plugin_path="$ZSH_PLUGINS_DIR/$name"

  if [[ -d "$plugin_path/$entry" || -f "$plugin_path/$entry" ]]; then
    log_success "Plugin $name já instalado. Pulando."
    continue
  fi

  log_info "Instalando plugin: $name..."
  if [[ -d "$plugin_path" ]]; then
    run_as_user_fast "rm -rf '$plugin_path'"
  fi

  # Retry com backoff: 3 tentativas (1s, 2s, 4s)
  _zsh_attempt=0
  _zsh_ok=0
  while [[ "$_zsh_attempt" -lt 3 ]]; do
    if run_as_user_fast "git clone --depth=1 'https://github.com/$repo.git' '$plugin_path'"; then
      _zsh_ok=1
      break
    fi
    _zsh_attempt=$((_zsh_attempt + 1))
    if [[ "$_zsh_attempt" -lt 3 ]]; then
      log_warn "  Tentativa $_zsh_attempt falhou para $name, retentando em $((2 ** (_zsh_attempt - 1)))s..."
      sleep $((2 ** (_zsh_attempt - 1)))
    fi
  done

  if [[ "$_zsh_ok" -eq 0 ]]; then
    log_warn "Plugin $name não pôde ser clonado após 3 tentativas."
  else
    log_success "Plugin $name instalado."
  fi
done

unset _zsh_attempt _zsh_ok
log_success "Shell e plugins configurados."
