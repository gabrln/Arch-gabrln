#!/usr/bin/env bash
# 13-wallpapers.sh - Baixa e extrai pacote de wallpapers extras
#
# Mudanças em relação à versão anterior:
#   - Suporte ao fluxo "confirm" do Google Drive para arquivos >100MB:
#     além do UUID, extrai e propaga o cookie de warning/download.
#   - Verifica Content-Type e tamanho do download antes de extrair.
#   - Suporte a SHA256 opcional declarado em wallpapers.toml (campo
#     [source].sha256) para validar integridade.
#   - Usa aria2c se disponível (mais robusto para arquivos grandes) —
#     com fallback para curl.

wallpapers_enabled=$(toml_get "$CONFIG_FILE" "features.wallpapers" "true")
if [[ "$wallpapers_enabled" != "true" ]]; then
  log_info "Download de wallpapers desabilitado em config.toml. Pulando."
  return 0
fi

file_id=$(toml_get "$MANIFESTS_DIR/wallpapers.toml" "source.file_id" "")
expected_sha=$(toml_get "$MANIFESTS_DIR/wallpapers.toml" "source.sha256" "")
wp_dir=$(toml_get "$MANIFESTS_DIR/wallpapers.toml" "destination.path" "Pictures/Wallpapers")
# O valor pode usar $HOME como prefixo (literal); expande para o home do usuario
# real. Se nao tiver prefixo, e apenas caminho relativo, monta $USER_HOME em cima.
case "$wp_dir" in
  \$HOME/*|\$HOME) wp_dir="$USER_HOME/${wp_dir#\$HOME/}" ;;
  /*) ;;
  *) wp_dir="$USER_HOME/$wp_dir" ;;
esac

if [[ -z "$file_id" ]]; then
  log_warn "Nenhum file_id configurado em wallpapers.toml. Pulando."
  return 0
fi

log_info "Garantindo diretório de wallpapers: $wp_dir"
mkdir -p "$wp_dir"
chown "$REAL_USER:$REAL_USER" "$wp_dir"

# Só baixa se o diretório estiver vazio
if [[ -n "$(ls -A "$wp_dir" 2>/dev/null)" ]]; then
  log_success "Diretório de wallpapers já contém arquivos. Pulando download."
  return 0
fi

log_info "Baixando pacote de wallpapers extras..."
WP_TMP="/tmp/wallpapers_extra.$$.zip"

_download_with_curl() {
  local url="$1"
  local out="$2"
  curl -fsSL --retry 3 --retry-delay 2 -o "$out" "$url"
}

_download_with_aria2() {
  local url="$1"
  local out="$2"
  if is_command aria2c; then
    aria2c --quiet=true --console-log-level=warn -o "$(basename "$out")" -d "$(dirname "$out")" "$url"
  else
    _download_with_curl "$url" "$out"
  fi
}

# Para arquivos >100MB, o Google Drive exige:
#   1. Primeiro GET em /uc?export=download&id=ID para obter cookies
#   2. UUID + confirmação no segundo GET
# O HTML de warning tem formato diferente em 2024+.
GDRIVE_HTML=$(curl -fsSL --max-time 30 "https://drive.google.com/uc?export=download&id=${file_id}" 2>/dev/null || true)
GDRIVE_UUID=$(echo "$GDRIVE_HTML" | grep -o 'name="uuid" value="[^"]*' | cut -d'"' -f4 || true)
GDRIVE_CONFIRM=$(echo "$GDRIVE_HTML" | grep -o 'confirm=[^&"]*' | head -1 | cut -d= -f2 || true)

if [[ -n "$GDRIVE_UUID" ]]; then
  # Confirmação obrigatória do Drive
  if [[ -n "$GDRIVE_CONFIRM" ]]; then
    _dl_url="https://drive.usercontent.google.com/download?id=${file_id}&export=download&confirm=${GDRIVE_CONFIRM}&uuid=${GDRIVE_UUID}"
  else
    _dl_url="https://drive.usercontent.google.com/download?id=${file_id}&export=download&confirm=t&uuid=${GDRIVE_UUID}"
  fi
else
  _dl_url="https://drive.google.com/uc?export=download&confirm=t&id=${file_id}"
fi

log_info "URL: $_dl_url"
if ! _download_with_aria2 "$_dl_url" "$WP_TMP"; then
  log_warn "Falha ao baixar wallpapers. Pulando extração."
  rm -f "$WP_TMP"
  return 0
fi

# Validação de SHA256 se declarado
if [[ -n "$expected_sha" ]]; then
  _actual_sha=$(sha256sum "$WP_TMP" 2>/dev/null | awk '{print $1}')
  if [[ "$_actual_sha" != "$expected_sha" ]]; then
    log_error "SHA256 mismatch: esperado $expected_sha, obtido $_actual_sha. Removendo arquivo."
    rm -f "$WP_TMP"
    return 0
  fi
  log_info "SHA256 validado."
fi

# Verifica que é um zip antes de extrair
_file_type=$(file -b --mime-type "$WP_TMP" 2>/dev/null || true)
if [[ "$_file_type" != *"zip"* && "$_file_type" != *"archive"* ]]; then
  log_warn "Arquivo baixado não parece ser um zip ($_file_type). Veja $WP_TMP."
  return 0
fi

# Tamanho razoável (sanity check: >1KB)
_size=$(stat -c %s "$WP_TMP" 2>/dev/null || echo 0)
if [[ "$_size" -lt 1024 ]]; then
  log_warn "Arquivo baixado é muito pequeno ($_size bytes). Provavelmente uma página de erro."
  rm -f "$WP_TMP"
  return 0
fi

log_info "Extraindo $((_size / 1024 / 1024)) MB para $wp_dir..."
if ! run_as_user_fast "unzip -o -j '$WP_TMP' -d '$wp_dir' 2>/dev/null"; then
  log_warn "unzip falhou; tentando com bsdtar..."
  run_as_user_fast "bsdtar -xf '$WP_TMP' -C '$wp_dir'" || log_warn "Extração falhou."
fi
rm -f "$WP_TMP"
log_success "Wallpapers extraídos para $wp_dir."
unset _dl_url _actual_sha _file_type _size
