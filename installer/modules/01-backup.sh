#!/usr/bin/env bash
# 01-backup.sh - Snapshot das configurações antes de modificá-las
#
# Mudanças em relação à versão anterior:
#   - Usa `_collect_backup_paths` (exportada pelo gabrln) em vez de
#     duplicar a lógica.
#   - Usa `toml_list` do utils (cache + 1 fork Python por chamada).

auto_backup=$(toml_get "$CONFIG_FILE" "flags.auto_backup" "true")

if [[ "$auto_backup" != "true" ]]; then
  log_info "Backup automático desabilitado. Pulando."
  return 0
fi

log_info "Criando snapshot das configurações atuais..."

# Coleta caminhos via helper do gabrln
mapfile -t config_paths < <(_collect_backup_paths)

# Filtra os que existem (backup_create já filtra, mas logamos quais serão tentados)
log_info "Caminhos a copiar: ${#config_paths[@]}"

backup_name=$(backup_create "pre-install" "${config_paths[@]}")
log_success "Snapshot criado: $backup_name"
