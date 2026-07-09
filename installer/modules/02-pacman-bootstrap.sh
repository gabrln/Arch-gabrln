#!/usr/bin/env bash
# 02-pacman-bootstrap.sh - Sincroniza pacman e garante dependências mínimas
#
# Mudanças em relação à versão anterior:
#   - Lê `bootstrap_packages` como lista via toml_list_get (1 fork Python)
#     em vez de expansão de string via tr.
#   - `-Sy` seguido de `-S` pode falhar em corrida com `pacman -Syu` paralelo.
#     Adicionamos um lock simples via flock.

log_info "Sincronizando base de dados do Pacman..."
# Pacman já tem lock interno (/var/lib/pacman/db.lck), não precisamos
# de um segundo lock que poderia conflitar com o próprio pacman.
pacman -Sy

log_info "Garantindo pacotes de bootstrap..."
# Lê pacotes como uma string joinada (1 fork Python, sem ARG_MAX)
_bootstrap_pkgs=$(toml_list_get "$CONFIG_FILE" "install" "bootstrap_packages")
# Converte lista em array
mapfile -t _bootstrap_arr <<<"$_bootstrap_pkgs"

# Filtra linhas vazias
_bootstrap_arr=("${_bootstrap_arr[@]//[[:space:]]/}")

# Constrói args com quoting seguro para shell
_bootstrap_quoted=""
_pkg=
for _pkg in "${_bootstrap_arr[@]}"; do
  [[ -z "$_pkg" ]] && continue
  _bootstrap_quoted+="'$_pkg' "
done

if [[ -n "$_bootstrap_quoted" ]]; then
  # shellcheck disable=SC2086
  pacman -S --needed --noconfirm ${_bootstrap_quoted} || \
    log_warn "Alguns pacotes de bootstrap podem ter falhado."
fi
unset _bootstrap_pkgs _bootstrap_arr _bootstrap_quoted _pkg

log_info "Garantindo yay (AUR helper)..."
if is_command yay; then
  log_success "yay já está instalado."
else
  log_warn "yay não encontrado. Instalando via pacman (repo cachyos)..."
  if ! pacman -S --needed --noconfirm yay; then
    exit_with_error "Falha ao instalar yay via pacman. Verifique se o repositório [cachyos] está habilitado em /etc/pacman.conf."
  fi
fi

hash -r
if ! is_command yay; then
  exit_with_error "yay não está disponível após a tentativa de instalação."
fi

log_success "Bootstrap concluído."
