#!/usr/bin/env bash
# errors.sh - Tratamento de erros, traps, cleanup e polkit policy
#
# Mudanças em relação à versão anterior:
#   - Removido `setup_temp_sudoers`: ele criava NOPASSWD no sudoers para
#     permitir que `sudo -u` rodasse sem senha. Substituído por `runuser`
#     em utils.sh (não precisa de senha) e por uma polkit policy
#     (`setup_polkit_policy`) que cobre o caso de helpers invocados pelo
#     próprio usuário via pkexec.
#   - Filtramos exit codes benignos no ERR trap (ex.: `command -v`,
#     `grep` sem match) para não rodar cleanup pesado em falso positivo.
#   - Cleanup hook também limpa o cache TOML e a polkit policy.

set -euo pipefail

if [[ -n "${_LIB_ERRORS_SH:-}" ]]; then return 0; fi
_LIB_ERRORS_SH=1

# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

declare -a _CLEANUP_HOOKS=()

# Exit codes considerados "benignos" — não disparam cleanup pesado nem
# são tratados como erro fatal pelo _error_handler.
#   1: falha genérica de `command -v`, `grep` sem match, `test` simples
#   2: misuse de shell builtin
#   3: erro de pipe em `set -o pipefail` quando o último cmd do pipe usa `|| true`
#  64: argumento de comando inválido (ex.: getopts)
# 130: Ctrl-C (mas SIGINT é tratado separadamente)
declare -a _BENIGN_EXIT_CODES=(1 2 3 64 130 141)

is_benign_exit() {
  local code="$1"
  local b
  for b in "${_BENIGN_EXIT_CODES[@]}"; do
    [[ "$code" == "$b" ]] && return 0
  done
  return 1
}

register_cleanup() {
  _CLEANUP_HOOKS+=("$1")
}

run_cleanup() {
  # Cleanup roda com set +e para que uma falha em um hook não impeça os
  # seguintes. Set +u para tolerar variáveis não-setadas durante teardown.
  set +e
  set +u
  local hook
  for hook in "${_CLEANUP_HOOKS[@]:-}"; do
    [[ -n "$hook" ]] && eval "$hook" 2>/dev/null || true
  done
  set -u
  set -e
}

_error_handler() {
  local line="$1"
  local command="$2"
  local code="$3"
  if is_benign_exit "$code"; then
    log_debug "Exit benigno ($code) na linha $line: $command"
    return 0
  fi
  log_error "Erro na linha $line (código $code): $command"
  # Cleanup pesado só em exit fatal
  run_cleanup
}

_exit_handler() {
  local code=$?
  # Cleanup sempre roda (é leve: remove polkit policy + cache TOML)
  run_cleanup
  exit "$code"
}

setup_traps() {
  trap '_error_handler "$LINENO" "$BASH_COMMAND" "$?"' ERR
  trap '_exit_handler' EXIT
  trap 'run_cleanup; exit 130' INT TERM HUP
}

exit_with_error() {
  local message="$1"
  local code="${2:-1}"
  log_error "$message"
  run_cleanup
  exit "$code"
}

# ---------------------------------------------------------------------------
# Polkit policy
# ---------------------------------------------------------------------------
#
# Quando o usuário invoca um helper nosso (gabrln-helper) via pkexec, o
# polkit abre um prompt de autenticação. Em uma instalação, queremos
# pular esse prompt para o REAL_USER, sob a action ID registrada.
#
# Implementação: arquivo .rules em /etc/polkit-1/rules.d/ (tem precedência
# sobre /usr/share). Lê REAL_USER em runtime (placeholder na install).
# Cleanup automático no EXIT remove a regra.

_POLKIT_RULES_PATH="/etc/polkit-1/rules.d/99-arch-gabrln-installer.rules"
_POLKIT_POLICY_PATH="/usr/share/polkit-1/actions/org.archlinux.pkexec.gabrln.policy"
_POLKIT_HELPER_PATH="/usr/local/bin/gabrln-helper"
_POLKIT_INSTALLED=0

# Escreve a polkit policy. Idempotente: se já existe e bate, não reescreve.
setup_polkit_policy() {
  if [[ -z "${REAL_USER:-}" ]]; then
    log_warn "REAL_USER não definido; pulando polkit policy."
    return 0
  fi

  if ! is_command pkexec; then
    log_warn "pkexec não encontrado. Instale 'polkit' (já está no manifesto)."
    return 0
  fi

  # Resolve o template dir (mesmo dir deste arquivo)
  local template_dir
  template_dir="$(dirname "${BASH_SOURCE[0]}")/../polkit"
  if [[ ! -d "$template_dir" ]]; then
    log_warn "Diretório de templates polkit não encontrado: $template_dir"
    return 0
  fi

  # Cria diretório de rules se necessário
  mkdir -p "$(dirname "$_POLKIT_RULES_PATH")" 2>/dev/null || {
    log_warn "Não foi possível criar $(dirname "$_POLKIT_RULES_PATH"). Polkit policy não instalada."
    return 0
  }

  # Rules file: renderiza template com REAL_USER
  if [[ -f "$template_dir/99-arch-gabrln-installer.rules" ]]; then
    sed "s/@REAL_USER@/${REAL_USER}/g" \
      "$template_dir/99-arch-gabrln-installer.rules" \
      >"$_POLKIT_RULES_PATH" 2>/dev/null || {
      log_warn "Não foi possível escrever $_POLKIT_RULES_PATH."
      return 0
    }
    chmod 644 "$_POLKIT_RULES_PATH"
  else
    log_warn "Template rules não encontrado em $template_dir"
    return 0
  fi

  # Policy file: copia template se ainda não existe
  if [[ ! -f "$_POLKIT_POLICY_PATH" ]]; then
    if [[ -f "$template_dir/org.archlinux.pkexec.gabrln.policy" ]]; then
      mkdir -p "$(dirname "$_POLKIT_POLICY_PATH")" 2>/dev/null || true
      install -m 644 "$template_dir/org.archlinux.pkexec.gabrln.policy" \
        "$_POLKIT_POLICY_PATH" 2>/dev/null || true
    fi
  fi

  # Helper binary: copia para /usr/local/bin se ainda não existe
  if [[ -f "$template_dir/gabrln-helper" ]] && [[ ! -f "$_POLKIT_HELPER_PATH" ]]; then
    install -m 755 "$template_dir/gabrln-helper" \
      "$_POLKIT_HELPER_PATH" 2>/dev/null || \
      log_warn "Não foi possível instalar gabrln-helper em $_POLKIT_HELPER_PATH."
  fi

  # Recarrega polkit para pegar a nova rule
  if is_command pkaction; then
    pkaction --action-id org.archlinux.pkexec.gabrln --verbose &>/dev/null || true
  fi

  # Registra cleanup
  register_cleanup "_polkit_policy_remove"
  _POLKIT_INSTALLED=1
  log_info "Polkit policy instalada para $REAL_USER."
}

_polkit_policy_remove() {
  if [[ "$_POLKIT_INSTALLED" -eq 1 && -f "$_POLKIT_RULES_PATH" ]]; then
    rm -f "$_POLKIT_RULES_PATH" 2>/dev/null || true
    log_debug "Polkit policy removida."
  fi
}

# ---------------------------------------------------------------------------
# Compatibilidade com versões antigas
# ---------------------------------------------------------------------------
# Mantemos setup_temp_sudoers como no-op para não quebrar callers antigos,
# mas com warning explícito.
setup_temp_sudoers() {
  log_debug "setup_temp_sudoers é no-op: substituição por polkit policy + runuser."
  return 0
}
