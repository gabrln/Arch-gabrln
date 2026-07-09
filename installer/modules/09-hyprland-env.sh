#!/usr/bin/env bash
# 09-hyprland-env.sh - Validação do ambiente Hyprland e permissões
#
# Mudanças em relação à versão anterior:
#   - `find -exec chmod +x` limitado a `*/scripts/*` (não a todo .sh
#     do ~/.config — evita chmod de arquivos de plugin que devem
#     ficar sem +x).
#   - Verifica que hyprpm está funcional se instalado.

log_info "Tornando scripts executáveis em ~/.config/scripts/..."
if [[ -d "$USER_HOME/.config" ]]; then
  find "$USER_HOME/.config" -path "*/scripts/*" -type f -exec chmod +x {} + 2>/dev/null || true
fi

log_info "Validando configuração do Hyprland..."
if [[ ! -f "$USER_HOME/.config/hypr/hyprland.lua" ]]; then
  exit_with_error "hyprland.lua não encontrado em $USER_HOME/.config/hypr/. A configuração do Hyprland não foi copiada corretamente."
fi

# Verifica hyprpm se estiver presente
if is_command hyprpm; then
  if ! hyprpm version &>/dev/null; then
    log_warn "hyprpm instalado mas não funcional. Tente 'hyprpm update' manualmente."
  else
    log_info "hyprpm funcional: $(hyprpm version 2>&1 | head -1)"
  fi
fi

log_success "Ambiente Hyprland validado."
