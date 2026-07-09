#!/usr/bin/env bash
# 16-services.sh - Habilita serviços systemd declarados no manifesto
#
# Mudanças em relação à versão anterior:
#   - Verifica que a unit existe antes de tentar habilitar (evita
#     warning "Failed to enable unit: unit not found" no log).
#   - Distingue falha (unit existe mas enable falhou) de skip
#     (unit não existe).
#   - Log estruturado por serviço.

log_info "Lendo serviços do manifesto..."

mapfile -t SERVICES < <(toml_list_get "$MANIFESTS_DIR/services.toml" "services" "name")

if [[ ${#SERVICES[@]} -eq 0 ]]; then
  log_warn "Nenhum serviço configurado. Pulando."
  return 0
fi

log_info "Habilitando serviços do Systemd..."
_svc_enabled=0
_svc_skipped=0
_svc_failed=0
for svc in "${SERVICES[@]}"; do
  if ! systemd_unit_exists "$svc"; then
    log_warn "  → $svc (unit não encontrada, pulando)"
    _svc_skipped=$((_svc_skipped + 1))
    continue
  fi
  if systemctl enable "$svc" 2>/dev/null; then
    log_info "  → $svc habilitado"
    _svc_enabled=$((_svc_enabled + 1))
  else
    log_warn "  → $svc falhou ao habilitar"
    _svc_failed=$((_svc_failed + 1))
  fi
done
unset _svc_enabled _svc_skipped _svc_failed

log_success "Serviços processados."
