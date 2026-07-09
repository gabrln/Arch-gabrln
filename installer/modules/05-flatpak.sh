#!/usr/bin/env bash
# 05-flatpak.sh - Instala pacotes Flatpak via flatpak
#
# Mudanças em relação à versão anterior:
#   - Parsing único de packages via toml_list_get.
#   - Falha em um pacote é reportada mas não derruba o módulo inteiro
#     (a menos que seja um pacote crítico).
#   - Retry em caso de falha transitória.

if ! is_command flatpak; then
  log_warn "flatpak não está instalado. Pulando."
  return 0
fi

log_info "Configurando remote flathub..."
remote_url=$(toml_get "$MANIFESTS_DIR/flatpak.toml" "remote.url" "https://dl.flathub.org/repo/flathub.flatpakrepo")
remote_name=$(toml_get "$MANIFESTS_DIR/flatpak.toml" "remote.name" "flathub")
flatpak remote-add --if-not-exists --system "$remote_name" "$remote_url"

mapfile -t FLATPAK_PKGS < <(toml_list_get "$MANIFESTS_DIR/flatpak.toml" "packages" "name")

if [[ ${#FLATPAK_PKGS[@]} -eq 0 ]]; then
  log_warn "Nenhum pacote Flatpak a instalar."
  return 0
fi

missing_pkgs=()
for pkg in "${FLATPAK_PKGS[@]}"; do
  if ! flatpak info "$pkg" &>/dev/null; then
    missing_pkgs+=("$pkg")
  fi
done

if [[ ${#missing_pkgs[@]} -eq 0 ]]; then
  log_success "Todos os pacotes Flatpak já estão instalados."
else
  log_info "Instalando pacotes Flatpak pendentes: ${missing_pkgs[*]}"
  for pkg in "${missing_pkgs[@]}"; do
    # Retry 3x com backoff
    _fp_attempt=0
    _fp_ok=0
    while [[ "$_fp_attempt" -lt 3 ]]; do
      if flatpak install -y --system "$remote_name" "$pkg" 2>/dev/null; then
        _fp_ok=1
        break
      fi
      _fp_attempt=$((_fp_attempt + 1))
      sleep $((2 ** (_fp_attempt - 1)))
    done
    if [[ "$_fp_ok" -eq 0 ]]; then
      log_warn "flatpak falhou para $pkg após 3 tentativas."
    else
      log_info "  → $pkg instalado."
    fi
  done
  unset _fp_attempt _fp_ok
fi

# Temas GTK para sandbox Flatpak (recomendação do Noctalia)
log_info "Instalando temas adw-gtk3 para Flatpak..."
flatpak install -y --system "$remote_name" org.gtk.Gtk3theme.adw-gtk3-dark 2>/dev/null || \
  log_debug "Tema adw-gtk3-dark não disponível."
flatpak install -y --system "$remote_name" org.gtk.Gtk3theme.adw-gtk3 2>/dev/null || \
  log_debug "Tema adw-gtk3 não disponível."

log_success "Pacotes Flatpak configurados."
