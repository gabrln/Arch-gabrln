#!/usr/bin/env bash
# progress.sh - Barra de progresso simples por módulo
#
# Mudanças em relação à versão anterior:
#   - O `progress_init` agora é chamado pelo `cmd_install` e por outros
#     comandos que percorrem múltiplos módulos.
#   - Em TTYs não-interativos (logs, scripts), a barra vira um log
#     estruturado `[N/TOTAL] mensagem` para preservar auditabilidade.
#   - Aceita um label que vira prefixo, útil quando o mesmo processo
#     executa múltiplas fases (install + update).

set -euo pipefail

if [[ -n "${_LIB_PROGRESS_SH:-}" ]]; then return 0; fi
_LIB_PROGRESS_SH=1

# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

_PROGRESS_TOTAL=0
_PROGRESS_CURRENT=0
_PROGRESS_LABEL=""

# Detecta se devemos desenhar a barra (TTY interativo).
_progress_use_bar() {
  if [[ -n "${NO_COLOR:-}" ]]; then return 1; fi
  if [[ "${TERM:-}" == "dumb" ]]; then return 1; fi
  [[ -t 1 ]]
}

progress_init() {
  _PROGRESS_TOTAL="$1"
  _PROGRESS_CURRENT=0
  _PROGRESS_LABEL="${2:-}"
}

# Avança o progresso e loga uma mensagem.
progress_step() {
  local message="$1"
  _PROGRESS_CURRENT=$((_PROGRESS_CURRENT + 1))

  local label_prefix=""
  if [[ -n "$_PROGRESS_LABEL" ]]; then
    label_prefix="[$_PROGRESS_LABEL] "
  fi

  if _progress_use_bar; then
    local width=30
    local filled=$((_PROGRESS_CURRENT * width / (_PROGRESS_TOTAL > 0 ? _PROGRESS_TOTAL : 1)))
    [[ "$filled" -gt "$width" ]] && filled="$width"
    local empty=$((width - filled))
    local bar
    bar=$(printf '%*s' "$filled" '' | tr ' ' '=')
    local space
    space=$(printf '%*s' "$empty" '' | tr ' ' '-')
    printf '\r\033[K%s[%d/%d] [%s%s] %s' \
      "$label_prefix" \
      "$_PROGRESS_CURRENT" \
      "$_PROGRESS_TOTAL" \
      "$bar" \
      "$space" \
      "$message" >&1
    if [[ "$_PROGRESS_CURRENT" -eq "$_PROGRESS_TOTAL" ]]; then
      printf '\n' >&1
    fi
  else
    log_info "${label_prefix}[$_PROGRESS_CURRENT/$_PROGRESS_TOTAL] $message"
  fi
}

progress_done() {
  local message="${1:-Concluído.}"
  log_success "$message ($_PROGRESS_CURRENT/$_PROGRESS_TOTAL)"
}
