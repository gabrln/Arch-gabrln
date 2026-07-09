#!/usr/bin/env bash
# state.sh - Gerenciamento de estado persistente entre execuções
#
# Mudanças em relação à versão anterior:
#   - Escritas atômicas via temp file + mv (os.replace em Python).
#   - Lock via flock para serializar leituras/escritas entre processos.
#   - Permissões 0600 (state pode conter paths de usuário).

set -euo pipefail

if [[ -n "${_LIB_STATE_SH:-}" ]]; then return 0; fi
_LIB_STATE_SH=1

# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

STATE_DIR=""
STATE_FILE=""
_STATE_LOCK=""

state_init() {
  STATE_DIR="$1"
  STATE_FILE="$STATE_DIR/state.json"
  _STATE_LOCK="$STATE_DIR/.state.lock"
  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR"
  if [[ ! -f "$STATE_FILE" ]]; then
    echo '{}' >"$STATE_FILE"
    chmod 600 "$STATE_FILE"
  fi
  # Sanity: se state.json está corrompido, faz backup e recria
  if [[ -f "$STATE_FILE" ]]; then
    if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$STATE_FILE" 2>/dev/null; then
      log_warn "state.json corrompido; fazendo backup e recriando."
      mv "$STATE_FILE" "${STATE_FILE}.corrupt-$(date +%s)"
      echo '{}' >"$STATE_FILE"
      chmod 600 "$STATE_FILE"
    fi
  fi
}

# Adquire o lock fd. Caller é responsável por chamar _state_unlock.
# Usa flock com timeout razoável (5s) para não travar a instalação.
_state_lock() {
  exec {_STATE_LOCK_FD}>"$_STATE_LOCK"
  if ! flock -w 5 "${_STATE_LOCK_FD}"; then
    log_warn "Não foi possível adquirir lock do state.json após 5s."
    return 1
  fi
}

_state_unlock() {
  if [[ -n "${_STATE_LOCK_FD:-}" ]]; then
    flock -u "${_STATE_LOCK_FD}" 2>/dev/null || true
    # Não fechamos o FD aqui — caller pode reusar no mesmo processo
  fi
}

# Calcula um hash (sha256) de um arquivo ou diretório.
# Para diretórios, usa find com -print0 + sha256sum para ser robusto a
# filenames com whitespace/newlines.
state_hash() {
  local target="$1"
  if [[ -f "$target" ]]; then
    sha256sum "$target" | awk '{print $1}'
  elif [[ -d "$target" ]]; then
    # Exclui mtime — só o conteúdo importa. Usamos ctime+mtime como
    # proxy de "estrutura de conteúdo" já que conteúdo idêntico sempre
    # gera mesmo hash.
    find "$target" -type f -print0 2>/dev/null \
      | sort -z \
      | xargs -0 sha256sum 2>/dev/null \
      | sha256sum \
      | awk '{print $1}'
  else
    echo ""
  fi
}

# Lê um campo do estado de um módulo.
# Uso: state_get <module> <field>
state_get() {
  local module="$1"
  local field="$2"

  python3 - "$STATE_FILE" "$module" "$field" <<'PY'
import sys, json
state_file, module, field = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(state_file) as f:
        data = json.load(f)
    print(data.get(module, {}).get(field, ""))
except Exception:
    print("")
PY
}

# Define um campo do estado de um módulo. Escrita atômica + lock.
# Uso: state_set <module> <field> <value>
state_set() {
  local module="$1"
  local field="$2"
  local value="$3"

  if [[ -z "$STATE_FILE" || ! -d "$STATE_DIR" ]]; then
    log_warn "state_set: state não inicializado."
    return 1
  fi

  _state_lock
  # shellcheck disable=SC2064
  trap "_state_unlock" RETURN

  python3 - "$STATE_FILE" "$module" "$field" "$value" <<'PY'
import sys, json, os, tempfile
state_file, module, field, value = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
data = {}
try:
    with open(state_file) as f:
        data = json.load(f)
except Exception:
    pass
data.setdefault(module, {})
data[module][field] = value
# Escrita atômica: escreve em temp file, depois os.replace
dirpath = os.path.dirname(state_file) or "."
fd, tmp = tempfile.mkstemp(dir=dirpath, prefix=".state.", suffix=".tmp")
try:
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.flush()
        os.fsync(f.fileno())
    os.chmod(tmp, 0o600)
    os.replace(tmp, state_file)
except Exception:
    if os.path.exists(tmp):
        os.unlink(tmp)
    raise
PY
}

# Marca um módulo como concluído, armazenando o hash do manifesto.
state_mark_done() {
  local module="$1"
  local manifest="${2:-}"
  local hash_value=""
  if [[ -n "$manifest" && -e "$manifest" ]]; then
    hash_value=$(state_hash "$manifest")
  fi
  state_set "$module" "status" "done"
  state_set "$module" "manifest_hash" "$hash_value"
  state_set "$module" "completed_at" "$(date -Iseconds)"
}

# Marca um módulo como falhado. Útil para o `run_module` seguro.
state_mark_failed() {
  local module="$1"
  local reason="${2:-unknown}"
  state_set "$module" "status" "failed"
  state_set "$module" "failure_reason" "$reason"
  state_set "$module" "failed_at" "$(date -Iseconds)"
}

# Limpa o estado de um módulo.
state_clear() {
  local module="$1"
  _state_lock
  # shellcheck disable=SC2064
  trap "_state_unlock" RETURN

  python3 - "$STATE_FILE" "$module" <<'PY'
import sys, json, os, tempfile
state_file, module = sys.argv[1], sys.argv[2]
data = {}
try:
    with open(state_file) as f:
        data = json.load(f)
except Exception:
    pass
data.pop(module, None)
dirpath = os.path.dirname(state_file) or "."
fd, tmp = tempfile.mkstemp(dir=dirpath, prefix=".state.", suffix=".tmp")
try:
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.flush()
        os.fsync(f.fileno())
    os.chmod(tmp, 0o600)
    os.replace(tmp, state_file)
except Exception:
    if os.path.exists(tmp):
        os.unlink(tmp)
    raise
PY
}

# Verifica se um módulo já foi concluído com o mesmo manifesto.
# Retorna 0 se está em dia, 1 caso contrário.
state_is_up_to_date() {
  local module="$1"
  local manifest="${2:-}"
  local status
  status=$(state_get "$module" "status")
  [[ "$status" == "done" ]] || return 1

  if [[ -n "$manifest" && -e "$manifest" ]]; then
    local current_hash
    current_hash=$(state_hash "$manifest")
    local stored_hash
    stored_hash=$(state_get "$module" "manifest_hash")
    [[ "$current_hash" == "$stored_hash" ]]
  else
    return 0
  fi
}
