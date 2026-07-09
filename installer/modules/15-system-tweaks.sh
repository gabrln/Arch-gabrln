#!/usr/bin/env bash
# 15-system-tweaks.sh - Ajustes finos de sistema e compatibilidade root
#
# Mudanças em relação à versão anterior:
#   - `chown -R` em ~/.local substituído por chown cirúrgico só nos
#     diretórios que criamos (evita varrer 50GB de caches do user).
#   - Verifica se /root/.config/gtk-* é diretório real antes de rm -rf
#     e recriar symlink (evita perda de config se for symlink já
#     apontando para algo válido).
#   - Verifica que o symlink alvo existe antes de criar.

log_info "Ajustando permissões de configurações do usuário..."
# Surgical chown — só os diretórios que tocamos
chown_user_path "$USER_HOME/.config" 2>/dev/null || true
chown_user_path "$USER_HOME/.local/share/icons" 2>/dev/null || true
mkdir -p "$USER_HOME/.local/share/icons"

log_info "Vinculando temas para acessibilidade de aplicativos root..."
mkdir -p /root/.config /root/.local/share

# Verifica se o alvo existe antes de fazer symlink
for root_cfg in gtk-3.0 gtk-4.0; do
  _target_cfg="$USER_HOME/.config/$root_cfg"
  if [[ ! -e "$_target_cfg" ]]; then
    log_warn "Alvo $_target_cfg não existe; pulando symlink /root/.config/$root_cfg"
    continue
  fi

  # Se já é symlink válido para o destino, não toca
  if [[ -L "/root/.config/$root_cfg" ]]; then
    _current=$(readlink "/root/.config/$root_cfg")
    if [[ "$_current" == "$_target_cfg" ]]; then
      log_info "  → /root/.config/$root_cfg (já correto)"
      continue
    fi
  fi

  # Só faz rm -rf se for diretório real (não symlink)
  if [[ -d "/root/.config/$root_cfg" && ! -L "/root/.config/$root_cfg" ]]; then
    rm -rf "/root/.config/$root_cfg"
  elif [[ -L "/root/.config/$root_cfg" ]]; then
    rm -f "/root/.config/$root_cfg"
  fi
  ln -sfT "$_target_cfg" "/root/.config/$root_cfg"
  log_info "  → /root/.config/$root_cfg"
done
unset _target_cfg _current

# Mesma lógica para ícones
if [[ -e "$USER_HOME/.local/share/icons" ]]; then
  if [[ -d /root/.local/share/icons ]] && [[ ! -L /root/.local/share/icons ]]; then
    rm -rf /root/.local/share/icons
  elif [[ -L /root/.local/share/icons ]]; then
    rm -f /root/.local/share/icons
  fi
  ln -sfT "$USER_HOME/.local/share/icons" /root/.local/share/icons
  log_info "  → /root/.local/share/icons"
fi

log_info "Limpando configurações órfãs do Noctalia..."
rm -rf "$USER_HOME/.config/qt5ct"
if [[ -L "$USER_HOME/.config/qt6ct/qt6ct" ]]; then
  rm -f "$USER_HOME/.config/qt6ct/qt6ct"
  log_info "  → symlink circular qt6ct/qt6ct removido"
fi

log_success "Ajustes de sistema aplicados."
