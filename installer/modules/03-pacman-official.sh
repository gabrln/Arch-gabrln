#!/usr/bin/env bash
# 03-pacman-official.sh - Instala pacotes oficiais via pacman

log_info "Lendo pacotes oficiais do manifesto..."

# Extrai nomes dos pacotes, respeitando a flag --gaming
mapfile -t OFFICIAL_PKGS < <(python3 -c '
import sys, tomllib
file, gaming = sys.argv[1], sys.argv[2] == "true"
with open(file, "rb") as f:
    data = tomllib.load(f)
for pkg in data.get("packages", []):
    tags = pkg.get("tags", [])
    if "gaming" in tags and not gaming:
        continue
    print(pkg["name"])
' "$MANIFESTS_DIR/packages.toml" "$GAMING")

if [[ ${#OFFICIAL_PKGS[@]} -eq 0 ]]; then
  log_warn "Nenhum pacote oficial a instalar."
  return 0
fi

log_info "Verificando pacotes já instalados..."
# pacman -T retorna pacotes separados por newline; usamos mapfile para
# preservar a lista como array e evitar que newlines quebrem o comando shell
mapfile -t MISSING_ARR < <(pacman -T "${OFFICIAL_PKGS[@]}" 2>/dev/null || true)

if [[ ${#MISSING_ARR[@]} -eq 0 ]]; then
  log_success "Todos os pacotes oficiais já estão instalados."
  return 0
fi

log_info "Instalando pacotes oficiais pendentes: ${MISSING_ARR[*]}"
if ! pacman -S --needed --noconfirm "${MISSING_ARR[@]}"; then
  exit_with_error "pacman falhou ao instalar pacotes oficiais. Verifique repositórios e conectividade."
fi

hash -r

# Verificação individual: pacman -S pode sair com 0 mesmo tendo pulado algo
# em cenários de conflito resolvido automaticamente ou aviso não-fatal.
# Confirmamos pacote a pacote em vez de confiar só no exit code do lote —
# é exatamente o que faltava para pegar um caso como "hyprland não instalou".
mapfile -t STILL_MISSING < <(pacman -T "${MISSING_ARR[@]}" 2>/dev/null || true)
if [[ ${#STILL_MISSING[@]} -gt 0 ]]; then
  exit_with_error "Pacotes não confirmados após instalação: ${STILL_MISSING[*]}"
fi

# Verificação crítica: zsh deve estar instalado (dependência de chsh em 07-shell)
if ! command -v zsh &>/dev/null && [[ ! -x /usr/bin/zsh ]]; then
  exit_with_error "zsh ausente após instalação de pacotes oficiais."
fi

log_success "Pacotes oficiais instalados e confirmados."
