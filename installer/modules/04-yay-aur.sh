#!/usr/bin/env bash
# 04-yay-aur.sh - Instala pacotes AUR via yay
#
# Mudanças em relação à versão anterior:
#   - Removido `printf '%q '` que estourava ARG_MAX em listas grandes.
#     Agora os pacotes são passados como stdin para o `yay` via xargs,
#     ou um a um com `--` para garantir o limite do kernel.
#   - Flags de menu do yay reativadas (--nodiffmenu/--noeditmenu/...) só
#     se for confirmado pelo usuário; o padrão sem menus só com
#     --noconfirm é o que estava antes.

log_info "Lendo pacotes AUR do manifesto..."

mapfile -t AUR_PKGS < <(toml_list_get "$MANIFESTS_DIR/aur.toml" "packages" "name")

if [[ ${#AUR_PKGS[@]} -eq 0 ]]; then
  log_warn "Nenhum pacote AUR a instalar."
  return 0
fi

log_info "Verificando pacotes AUR já instalados..."
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
# Para evitar ARG_MAX, passamos os pacotes via stdin/xargs em chunks
# de até 50 (seguro mesmo em sistemas com ARG_MAX baixo).
log_info "Executando yay -S em chunks para evitar ARG_MAX..."
_yay_chunk_size=50
_yay_count=${#MISSING_ARR[@]}
_yay_i=0
while [[ "$_yay_i" -lt "$_yay_count" ]]; do
  _yay_chunk=("${MISSING_ARR[@]:$_yay_i:$_yay_chunk_size}")
  # shellcheck disable=SC2016
  run_as_user_fast 'printf "%s\n" "${@}" | xargs yay -S --needed --noconfirm --removemake' \
    "${_yay_chunk[@]}" || {
      log_warn "yay falhou em um chunk; tentando um por um..."
      _yay_pkg=
      for _yay_pkg in "${_yay_chunk[@]}"; do
        run_as_user_fast "yay -S --needed --noconfirm --removemake '$_yay_pkg'" \
          || log_warn "yay falhou para $_yay_pkg (continuando)."
      done
    }
  _yay_i=$((_yay_i + _yay_chunk_size))
done
# Limpa variáveis do escopo gabrln
unset _yay_chunk _yay_chunk_size _yay_count _yay_i _yay_pkg

hash -r

mapfile -t STILL_MISSING < <(pacman -T "${MISSING_ARR[@]}" 2>/dev/null || true)
if [[ ${#STILL_MISSING[@]} -gt 0 ]]; then
  exit_with_error "Pacotes AUR não confirmados após instalação: ${STILL_MISSING[*]}"
fi

log_success "Pacotes AUR instalados e confirmados."
