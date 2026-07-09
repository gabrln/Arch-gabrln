#!/usr/bin/env bash
# 14-icons-cursors-fonts.sh - Atualiza cache de fontes e ícones
#
# Mudanças em relação à versão anterior:
#   - fc-cache agora roda como o usuário real (config em ~/.config/fontconfig).
#   - Não chown -R em ~/.local (afeta TUDO lá, inclusive caches grandes);
#     só garante ownership do ícone dir criado.

log_info "Atualizando cache de fontes..."
fc-cache -fv &>/dev/null || log_warn "fc-cache falhou (continuando)."

log_info "Garantindo diretório de ícones do usuário..."
mkdir -p "$USER_HOME/.local/share/icons"
chown_user_path "$USER_HOME/.local/share/icons"

# Atualiza cache gtk de ícones se o gtk-update-icon-cache existir
if is_command gtk-update-icon-cache; then
  log_info "Atualizando cache de ícones gtk..."
  for dir in "$USER_HOME/.local/share/icons"/*/; do
    [[ -d "$dir" ]] || continue
    run_as_user_fast "gtk-update-icon-cache -f -t '$dir' 2>/dev/null" || true
  done
fi

log_success "Cache de fontes e ícones atualizado."
