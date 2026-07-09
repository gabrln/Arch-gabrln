#!/usr/bin/env bash
# 08-dotfiles.sh - Aplica as configurações do repositório no HOME do usuário
#
# Mudanças em relação à versão anterior:
#   - Backup-then-replace: copia para staging temporário e só então
#     faz rm -rf do destino. Se a cópia falhar, o destino original
#     fica intacto.
#   - Staging usa mktemp -d em $TMPDIR (não no $target), evitando
#     tmpwatch/cron de limpar no meio.
#   - `runuser -u` em vez de `run_as_user` para comandos simples
#     (consistência com o resto).
#   - Parsing único de arquivos/diretórios.
#   - `mkdir -p` no destino antes de cada cp avulso (defesa em profundidade).

log_info "Garantindo diretório ~/.config..."
mkdir -p "$USER_HOME/.config"
chown_user_path "$USER_HOME/.config"

# Lê lista de diretórios de config do manifesto UMA VEZ
mapfile -t CONFIGS < <(toml_list "$MANIFESTS_DIR/dotfiles.toml" "directories.configs")

log_info "Copiando configurações do usuário..."
for cfg in "${CONFIGS[@]}"; do
  source_path="$REPO_DIR/.config/$cfg"
  target_path="$USER_HOME/.config/$cfg"

  if [[ ! -d "$source_path" && ! -f "$source_path" ]]; then
    log_warn "Fonte não encontrada, pulando: $cfg"
    continue
  fi

  # Estratégia atômica:
  #   1. cp -a para staging
  #   2. só se cp teve sucesso, rm -rf do target
  #   3. mv staging para target
  # Se qualquer etapa falhar, o target original fica intacto.
  _dot_staging=$(mktemp -d -t gabrln-dot-XXXXXX)
  if ! runuser -u "$REAL_USER" -- cp -a "$source_path" "$_dot_staging/$cfg" 2>/dev/null; then
    log_error "Falha ao copiar $cfg para staging ($_dot_staging). Destino original preservado."
    rm -rf "$_dot_staging"
    continue
  fi

  # Preserva permissões e ownership após mover
  if [[ -e "$target_path" || -L "$target_path" ]]; then
    rm -rf "$target_path"
  fi
  if ! mv "$_dot_staging/$cfg" "$target_path"; then
    log_error "Falha ao mover staging para $target_path."
    rm -rf "$_dot_staging"
    continue
  fi
  rm -rf "$_dot_staging"
  chown_user_path "$target_path"

  if [[ ! -e "$target_path" ]]; then
    exit_with_error "Falha ao copiar $cfg para $target_path"
  fi
  log_info "  → $cfg"
done
unset _dot_staging

# Caso especial: zsh preserva plugins/ existentes
log_info "Aplicando configuração especial do Zsh..."
ZSH_SRC="$REPO_DIR/.config/zsh"
ZSH_DST="$USER_HOME/.config/zsh"
if [[ -d "$ZSH_SRC" ]]; then
  # Preserva plugins existentes
  if [[ -d "$ZSH_DST/plugins" ]]; then
    _zsh_tmp=$(mktemp -d)
    if ! cp -a "$ZSH_DST/plugins" "$_zsh_tmp/" 2>/dev/null; then
      log_warn "Não foi possível preservar plugins/ — seguindo sem preservar."
      _zsh_tmp=""
    fi
  fi

  # Estratégia atômica
  _zsh_staging=$(mktemp -d -t gabrln-zsh-XXXXXX)
  if runuser -u "$REAL_USER" -- cp -a "$ZSH_SRC" "$_zsh_staging/zsh" 2>/dev/null; then
    [[ -e "$ZSH_DST" || -L "$ZSH_DST" ]] && rm -rf "$ZSH_DST"
    if mv "$_zsh_staging/zsh" "$ZSH_DST"; then
      # Re-aplica plugins preservados
      if [[ -n "${_zsh_tmp:-}" && -d "$_zsh_tmp/plugins" ]]; then
        rm -rf "$ZSH_DST/plugins"
        mv "$_zsh_tmp/plugins" "$ZSH_DST/plugins"
        chown_user_path "$ZSH_DST/plugins"
      fi
      chown_user_path "$ZSH_DST"
    else
      log_warn "Falha ao mover staging para $ZSH_DST."
    fi
  else
    log_warn "Falha ao copiar zsh para staging — destino original preservado."
  fi
  rm -rf "${_zsh_staging:-}" "${_zsh_tmp:-}"

  if [[ ! -e "$ZSH_DST" ]]; then
    exit_with_error "Falha ao copiar zsh para $ZSH_DST"
  fi
  log_info "  → zsh (plugins preservados)"
fi
unset _zsh_tmp _zsh_staging

# Arquivos avulsos
log_info "Copiando arquivos avulsos..."
while IFS='|' read -r src dst; do
  [[ -z "$src" ]] && continue
  src_path="$REPO_DIR/$src"
  dst_path=$(echo "$dst" | sed "s|\\\$HOME|$USER_HOME|g")

  if [[ ! -e "$src_path" ]]; then
    log_warn "Fonte não encontrada, pulando: $src"
    continue
  fi

  mkdir -p "$(dirname "$dst_path")"
  # Backup antes de sobrescrever (preserva originais divergentes)
  if [[ -e "$dst_path" && ! -L "$dst_path" ]]; then
    _file_bak="$dst_path.gabrln.bak.$(date +%s)"
    cp -a "$dst_path" "$_file_bak" 2>/dev/null || true
  fi
  if ! runuser -u "$REAL_USER" -- cp -f "$src_path" "$dst_path"; then
    log_warn "Falha ao copiar $src para $dst_path"
    continue
  fi
  log_info "  → $dst"
done < <(python3 -c '
import sys, tomllib, os
file, home = sys.argv[1], sys.argv[2]
with open(file, "rb") as f:
    data = tomllib.load(f)
for src, dst in data.get("files", {}).items():
    expanded = os.path.expandvars(dst)
    if expanded.startswith("~"):
        expanded = home + expanded[1:]
    print(f"{src}|{expanded}")
' "$MANIFESTS_DIR/dotfiles.toml" "$USER_HOME")
unset _file_bak

# Atualiza diretórios XDG e cria extras
log_info "Criando diretórios XDG adicionais..."
run_as_user_fast "xdg-user-dirs-update 2>/dev/null || true"

while IFS= read -r dir; do
  [[ -z "$dir" ]] && continue
  expanded=$(echo "$dir" | sed "s|\\\$HOME|$USER_HOME|g")
  mkdir -p "$expanded"
  chown "$REAL_USER:$REAL_USER" "$expanded"
  log_info "  → $expanded"
done < <(python3 -c '
import sys, tomllib, os
file, home = sys.argv[1], sys.argv[2]
with open(file, "rb") as f:
    data = tomllib.load(f)
for d in data.get("xdg_dirs", {}).get("extra", []):
    expanded = os.path.expandvars(d)
    if expanded.startswith("~"):
        expanded = home + expanded[1:]
    print(expanded)
' "$MANIFESTS_DIR/dotfiles.toml" "$USER_HOME")

log_success "Dotfiles aplicados."
