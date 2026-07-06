#!/usr/bin/env bash
# 04-yay-aur.sh - Instala pacotes AUR via yay

log_info "Lendo pacotes AUR do manifesto..."

mapfile -t AUR_PKGS < <(python3 -c '
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    data = tomllib.load(f)
for pkg in data.get("packages", []):
    print(pkg["name"])
' "$MANIFESTS_DIR/aur.toml")

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

log_info "Instalando pacotes AUR pendentes via yay: ${MISSING_ARR[*]}"
# yay nunca deve rodar como root (recusa por padrão) -> run_as_user.
# Apenas duas flags para lote nao-interativo:
#   --noconfirm   assume "sim" em todos os prompts do pacman
#   --removemake  remove makedepends apos o build sem perguntar
# As flags --nodiffmenu/--noeditmenu/--noupgrademenu/--answerclean
# foram removidas: em conjunto com --noconfirm, elas colocam o yay
# num estado onde precisa de input mas foi instruido a nao pedir,
# fazendo a instalacao falhar em vez de seguir.
quoted_args=$(printf '%q ' "${MISSING_ARR[@]}")
run_as_user "yay -S --needed --noconfirm --removemake $quoted_args"

hash -r

mapfile -t STILL_MISSING < <(pacman -T "${MISSING_ARR[@]}" 2>/dev/null || true)
if [[ ${#STILL_MISSING[@]} -gt 0 ]]; then
  exit_with_error "Pacotes AUR não confirmados após instalação: ${STILL_MISSING[*]}"
fi

log_success "Pacotes AUR instalados e confirmados."
