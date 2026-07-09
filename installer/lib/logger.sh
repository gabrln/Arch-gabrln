#!/usr/bin/env bash
# logger.sh - Logging estruturado para o framework Arch-gabrln
#
# Suporta níveis INFO/WARN/ERROR/SUCCESS/DEBUG/STEP.
# Honra NO_COLOR (https://no-color.org/), TERM=dumb, e pipes (sem TTY = sem cor).
# Flags controladas via QUIET/VERBOSE exportados antes do source.

set -euo pipefail

if [[ -n "${_LIB_LOGGER_SH:-}" ]]; then return 0; fi
_LIB_LOGGER_SH=1

# Cores
readonly C_RESET='\033[0m'
readonly C_GREEN='\033[0;32m'
readonly C_BLUE='\033[0;34m'
readonly C_YELLOW='\033[1;33m'
readonly C_RED='\033[0;31m'
readonly C_CYAN='\033[0;36m'
readonly C_GREY='\033[0;90m'

# Níveis
readonly L_DEBUG="DEBUG"
readonly L_INFO="INFO"
readonly L_WARN="WARN"
readonly L_ERROR="ERROR"
readonly L_SUCCESS="SUCCESS"
readonly L_STEP="STEP"

LOG_FILE=""

# Detecta se devemos usar cores. Considera NO_COLOR e TTY.
_use_color() {
  if [[ -n "${NO_COLOR:-}" ]]; then return 1; fi
  if [[ "${TERM:-}" == "dumb" ]]; then return 1; fi
  if [[ ! -t 1 && ! -t 2 ]]; then return 1; fi
  return 0
}

# Cache do resultado para evitar recomputar a cada chamada
if _use_color; then
  _LOG_COLOR=1
else
  _LOG_COLOR=0
fi

log_init() {
  local log_dir="$1"
  mkdir -p "$log_dir" 2>/dev/null || true
  LOG_FILE="$log_dir/gabrln-$(date +%Y%m%d-%H%M%S).log"
  # Se não conseguimos criar o log, log_file fica vazio e tudo continua
  touch "$LOG_FILE" 2>/dev/null || LOG_FILE=""
}

_log_raw() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local line="[$timestamp] [$level] $message"

  if [[ -n "$LOG_FILE" ]]; then
    # Falha de log nunca deve matar o instalador
    echo "$line" >>"$LOG_FILE" 2>/dev/null || true
  fi
}

# Decide se imprime no terminal conforme QUIET/VERBOSE.
# Defaults: INFO e acima visíveis, DEBUG apenas se VERBOSE=1, nada se QUIET=1.
_should_print() {
  local level="$1"
  if [[ "${QUIET:-0}" == "1" ]]; then
    [[ "$level" == "$L_ERROR" || "$level" == "$L_STEP" ]] && return 0
    return 1
  fi
  case "$level" in
    "$L_DEBUG")
      [[ "${VERBOSE:-0}" == "1" ]] && return 0
      return 1
      ;;
    *) return 0 ;;
  esac
}

_color_wrap() {
  local color="$1"
  local text="$2"
  if [[ "$_LOG_COLOR" -eq 1 ]]; then
    printf '%b%s%b' "$color" "$text" "$C_RESET"
  else
    printf '%s' "$text"
  fi
}

log_info() {
  local message="$1"
  _log_raw "$L_INFO" "$message"
  if _should_print "$L_INFO"; then
    _color_wrap "$C_BLUE" "[INFO] " >&1
    echo "$message" >&1
  fi
}

log_warn() {
  local message="$1"
  _log_raw "$L_WARN" "$message"
  if _should_print "$L_WARN"; then
    _color_wrap "$C_YELLOW" "[WARN] " >&2
    echo "$message" >&2
  fi
}

log_error() {
  local message="$1"
  _log_raw "$L_ERROR" "$message"
  # Erro sempre imprime
  _color_wrap "$C_RED" "[ERROR] " >&2
  echo "$message" >&2
}

log_success() {
  local message="$1"
  _log_raw "$L_SUCCESS" "$message"
  if _should_print "$L_INFO"; then
    _color_wrap "$C_GREEN" "[OK] " >&1
    echo "$message" >&1
  fi
}

log_step() {
  local message="$1"
  _log_raw "$L_STEP" "STEP: $message"
  # STEP sempre imprime (mesmo em quiet) — é o "andamento"
  if [[ "${QUIET:-0}" != "1" ]]; then
    _color_wrap "$C_CYAN" "==> " >&1
    echo "$message" >&1
  fi
}

log_debug() {
  local message="$1"
  _log_raw "$L_DEBUG" "$message"
  if _should_print "$L_DEBUG"; then
    _color_wrap "$C_GREY" "[DEBUG] " >&1
    echo "$message" >&1
  fi
}

log_cmd() {
  local cmd="$*"
  _log_raw "$L_INFO" "EXEC: $cmd"
  log_debug "$cmd"
}
