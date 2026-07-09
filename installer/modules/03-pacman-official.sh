#!/usr/bin/env bash
# 03-pacman-official.sh - Instala pacotes oficiais via pacman
#
# Mudanças em relação à versão anterior:
#   - Parsing via toml_list_get (cache + 1 fork).
#   - Detecção de kernel CachyOS já instalado: pula reinstalação se
#     algum `linux-cachyos*` estiver presente e não houver atualização.
#   - Continua mesmo se um pacote específico falhar (não-fatal para
#     pacotes "soft", fatal para zsh).

log_info "Lendo pacotes oficiais do manifesto..."

# Extrai nomes dos pacotes do manifesto (sem filtro de tag - tudo instala)
mapfile -t OFFICIAL_PKGS < <(toml_list_get "$MANIFESTS_DIR/packages.toml" "packages" "name")

if [[ ${#OFFICIAL_PKGS[@]} -eq 0 ]]; then
  log_warn "Nenhum pacote oficial a instalar."
  return 0
fi

# Detecta se o sistema é CachyOS. Se não, pula pacotes linux-cachyos*.
if ! cachyos_installed_kernels >/dev/null 2>&1 && \
   [[ ! -f /etc/pacman.d/cachyos-v3-mirrorlist ]] && \
   ! grep -q "^\[cachyos" /etc/pacman.conf 2>/dev/null; then
  log_info "Sistema não é CachyOS; filtrando pacotes linux-cachyos*."
  _filtered=()
  _pkg=
  for _pkg in "${OFFICIAL_PKGS[@]}"; do
    case "$_pkg" in
      linux-cachyos*) log_debug "  pulando $_pkg" ;;
      *) _filtered+=("$_pkg") ;;
    esac
  done
  OFFICIAL_PKGS=("${_filtered[@]}")
  unset _filtered _pkg
fi

if [[ ${#OFFICIAL_PKGS[@]} -eq 0 ]]; then
  log_warn "Nenhum pacote oficial a instalar (após filtros)."
  return 0
fi

log_info "Verificando pacotes já instalados..."
mapfile -t MISSING_ARR < <(pacman -T "${OFFICIAL_PKGS[@]}" 2>/dev/null || true)

if [[ ${#MISSING_ARR[@]} -eq 0 ]]; then
  log_success "Todos os pacotes oficiais já estão instalados."
  return 0
fi

log_info "Instalando pacotes oficiais pendentes: ${MISSING_ARR[*]}"
if ! pacman -S --needed --noconfirm "${MISSING_ARR[@]}"; then
  log_warn "pacman retornou erro. Tentando pacotes um por um para isolar falhas..."
  _failed_pkgs=()
  _pkg=
  for _pkg in "${MISSING_ARR[@]}"; do
    if ! pacman -S --needed --noconfirm "$_pkg" &>/dev/null; then
      log_warn "  falhou: $_pkg"
      _failed_pkgs+=("$_pkg")
    fi
  done

  # zsh é crítico (chsh depende dele)
  _had_zsh_fail=0
  _pkg=
  for _pkg in "${_failed_pkgs[@]}"; do
    [[ "$_pkg" == "zsh" ]] && _had_zsh_fail=1
  done

  if [[ "$_had_zsh_fail" -eq 1 ]]; then
    exit_with_error "zsh falhou ao instalar — necessário para o módulo 07-shell."
  fi

  if [[ ${#_failed_pkgs[@]} -gt 0 ]]; then
    log_warn "Pacotes que falharam (não críticos): ${_failed_pkgs[*]}"
  fi
  unset _failed_pkgs _had_zsh_fail _pkg
fi

hash -r

# Verificação individual: pacman -S pode sair com 0 mesmo tendo pulado algo
mapfile -t STILL_MISSING < <(pacman -T "${MISSING_ARR[@]}" 2>/dev/null || true)
if [[ ${#STILL_MISSING[@]} -gt 0 ]]; then
  log_warn "Pacotes ainda ausentes após tentativa: ${STILL_MISSING[*]}"
  # Só é fatal se algum crítico estiver faltando
  _critical_still=()
  _pkg=
  for _pkg in "${STILL_MISSING[@]}"; do
    case "$_pkg" in
      zsh|base|base-devel|git) _critical_still+=("$_pkg") ;;
    esac
  done
  if [[ ${#_critical_still[@]} -gt 0 ]]; then
    exit_with_error "Pacotes críticos ausentes: ${_critical_still[*]}"
  fi
  unset _critical_still _pkg
fi

# Verificação crítica: zsh deve estar instalado (dependência de chsh em 07-shell)
if ! command -v zsh &>/dev/null && [[ ! -x /usr/bin/zsh ]]; then
  exit_with_error "zsh ausente após instalação de pacotes oficiais."
fi

log_success "Pacotes oficiais instalados e confirmados."
