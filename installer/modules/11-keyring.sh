#!/usr/bin/env bash
# 11-keyring.sh - Garante integração do gnome-keyring com greetd
#
# Mudanças em relação à versão anterior:
#   - Adiciona após a ÚLTIMA linha auth/session, não a primeira,
#     para não estragar config PAM complexa com múltiplos blocos.
#   - Idempotente: se já existe, não duplica.

PAM_FILE="/etc/pam.d/greetd"

if [[ ! -f "$PAM_FILE" ]]; then
  log_warn "$PAM_FILE não encontrado. Pulando configuração de keyring."
  return 0
fi

log_info "Verificando integração do gnome-keyring no greetd..."

# Backup antes de modificar
if [[ ! -e "${PAM_FILE}.gabrln.bak" ]]; then
  cp -a "$PAM_FILE" "${PAM_FILE}.gabrln.bak"
  chmod 600 "${PAM_FILE}.gabrln.bak"
fi

# Garante linha de auth
if ! grep -qE '^auth\s+optional\s+pam_gnome_keyring\.so' "$PAM_FILE"; then
  log_info "Adicionando pam_gnome_keyring.so à linha de auth..."
  # Encontra o número da última linha que começa com 'auth '
  _last_auth_line=$(grep -n '^auth ' "$PAM_FILE" | tail -1 | cut -d: -f1)
  if [[ -n "$_last_auth_line" ]]; then
    # Insere DEPOIS da última linha auth
    sed -i "${_last_auth_line}a auth       optional     pam_gnome_keyring.so" "$PAM_FILE"
  else
    # Sem nenhum bloco auth — adiciona no topo (geralmente errado,
    # mas é o melhor que podemos fazer)
    sed -i '1i auth       optional     pam_gnome_keyring.so' "$PAM_FILE"
    log_warn "Nenhum bloco 'auth' encontrado em $PAM_FILE; linha adicionada no topo."
  fi
fi

# Garante linha de session
if ! grep -qE '^session\s+optional\s+pam_gnome_keyring\.so\s+auto_start' "$PAM_FILE"; then
  log_info "Adicionando pam_gnome_keyring.so auto_start à linha de session..."
  _last_session_line=$(grep -n '^session ' "$PAM_FILE" | tail -1 | cut -d: -f1)
  if [[ -n "$_last_session_line" ]]; then
    sed -i "${_last_session_line}a session    optional     pam_gnome_keyring.so auto_start" "$PAM_FILE"
  else
    sed -i '1i session    optional     pam_gnome_keyring.so auto_start' "$PAM_FILE"
    log_warn "Nenhum bloco 'session' encontrado em $PAM_FILE; linha adicionada no topo."
  fi
fi
unset _last_auth_line _last_session_line

# Validação: pam não tem um parser fácil, mas garantimos que ainda tem
# linhas auth e session
if ! grep -qE '^auth ' "$PAM_FILE" || ! grep -qE '^session ' "$PAM_FILE"; then
  log_error "$PAM_FILE ficou sem linhas auth/session após edição. Restaurando backup."
  cp -a "${PAM_FILE}.gabrln.bak" "$PAM_FILE"
  exit_with_error "Edição PAM falhou; backup restaurado."
fi

log_success "Keyring configurado."
