#!/usr/bin/env bash
# 04-shelly-aur.sh - Instala pacotes AUR via shelly

log_info "Lendo pacotes AUR do manifesto..."

mapfile -t AUR_PKGS < <(python3 -c '
import sys, tomllib
file, gaming = sys.argv[1], sys.argv[2] == "true"
with open(file, "rb") as f:
    data = tomllib.load(f)
for pkg in data.get("packages", []):
    tags = pkg.get("tags", [])
    if "gaming" in tags and not gaming:
        continue
    print(pkg["name"])
' "$MANIFESTS_DIR/aur.toml" "$GAMING")

if [[ ${#AUR_PKGS[@]} -eq 0 ]]; then
  log_warn "Nenhum pacote AUR a instalar."
  return 0
fi

log_info "Verificando pacotes AUR já instalados..."
# pacman -T retorna pacotes separados por newline; usamos mapfile para
# preservar a lista como array e evitar que newlines quebrem o comando shell
mapfile -t MISSING_ARR < <(pacman -T "${AUR_PKGS[@]}" 2>/dev/null || true)

if [[ ${#MISSING_ARR[@]} -eq 0 ]]; then
  log_success "Todos os pacotes AUR já estão instalados."
  return 0
fi

log_info "Instalando pacotes AUR pendentes via shelly aur install: ${MISSING_ARR[*]}"
# printf %q escapa os argumentos para que newlines/espaços não quebrem o bash -c
quoted_args=$(printf '%q ' "${MISSING_ARR[@]}")
run_as_user "shelly aur install --no-confirm $quoted_args"

hash -r
log_success "Pacotes AUR instalados."
