#!/usr/bin/env bash
# backup.sh - Snapshot e rollback de configurações
#
# Mudanças em relação à versão anterior:
#   - Detecção de colisão de basename: se dois paths têm o mesmo basename
#     (ex.: dotfiles/zsh/.zshrc e dotfiles/bash/.zshrc), o segundo recebe
#     sufixo .1, .2, etc. para não sobrescrever.
#   - `cp -a` agora preserva ownership quando copiando de $USER_HOME;
#     para /etc/*, usa --no-preserve=ownership (são configs do sistema).
#   - Retenção configurável via `max_backups` em config.toml.
#   - `backup_restore` faz `cp -a` em diretório temporário e depois
#     `rm -rf` + `mv` atômico, evitando target vazio em caso de falha.
#   - Mapeamento de restore reconhece sufixos `.N` e strip antes de
#     mapear para o destino original.

set -euo pipefail

if [[ -n "${_LIB_BACKUP_SH:-}" ]]; then return 0; fi
_LIB_BACKUP_SH=1

# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

BACKUP_DIR=""
BACKUP_MAX=0 # 0 = ilimitado

backup_init() {
  BACKUP_DIR="$1"
  mkdir -p "$BACKUP_DIR"
  local max
  max=$(toml_get "${CONFIG_FILE:-}" "flags.max_backups" "3")
  BACKUP_MAX="$max"
}

# Gera um nome único para um item no backup (sem colisão).
_unique_backup_name() {
  local dest_dir="$1"
  local base_name="$2"
  local candidate="$base_name"
  local n=1
  while [[ -e "$dest_dir/$candidate" ]]; do
    candidate="${base_name}.${n}"
    n=$((n + 1))
  done
  echo "$candidate"
}

# Decide se um path é do "sistema" (ownership root/root preservada) ou do
# "usuário" (ownership do $REAL_USER preservada). Diretórios /etc/* são
# sempre sistema.
_is_system_path() {
  local path="$1"
  case "$path" in
    /etc/*|/usr/*|/var/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Cria um backup com timestamp de uma lista de caminhos.
# Uso: backup_create <label> <caminho1> [caminho2] ...
backup_create() {
  local label="$1"
  shift
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local name="${label}-${timestamp}"
  local dest="$BACKUP_DIR/$name"

  mkdir -p "$dest"
  # Logs vão para stderr para não contaminar o stdout que carrega o nome
  log_info "Criando backup '$name'..." >&2

  local path
  for path in "$@"; do
    if [[ ! -e "$path" ]]; then
      log_warn "  → $path não existe, pulando." >&2
      continue
    fi

    local base
    base=$(basename "$path")
    local target_name
    target_name=$(_unique_backup_name "$dest" "$base")
    local target="$dest/$target_name"

    if _is_system_path "$path"; then
      # /etc e /var são do sistema — não preserva ownership
      cp -a --no-preserve=ownership "$path" "$target" 2>/dev/null || {
        log_warn "  → falha ao copiar $path" >&2
        continue
      }
    else
      # $USER_HOME/* — preserva ownership
      cp -a "$path" "$target" 2>/dev/null || {
        log_warn "  → falha ao copiar $path" >&2
        continue
      }
    fi
    log_info "  → $path" >&2
  done

  # Aplica retenção
  _backup_apply_retention "$label"

  # Só o nome do snapshot vai para stdout
  echo "$name"
}

# Aplica a política de retenção: mantém apenas os N mais recentes.
_backup_apply_retention() {
  local label="$1"
  [[ "$BACKUP_MAX" -le 0 ]] && return 0

  # Lista snapshots deste label, do mais recente para o mais antigo
  local -a snapshots
  mapfile -t snapshots < <(backup_list | grep "^${label}-" || true)
  local total=${#snapshots[@]}

  if [[ "$total" -le "$BACKUP_MAX" ]]; then
    return 0
  fi

  # Remove os mais antigos
  local to_remove=$((total - BACKUP_MAX))
  local i
  for ((i = total - 1; i >= total - to_remove; i--)); do
    local snap="${snapshots[$i]}"
    log_info "  → removendo backup antigo: $snap"
    rm -rf "$BACKUP_DIR/$snap"
  done
}

# Lista os backups existentes, do mais recente para o mais antigo.
backup_list() {
  find "$BACKUP_DIR" -maxdepth 1 -type d -name '*-[0-9]*' -printf '%f\n' 2>/dev/null | sort -r
}

# Resolve o destino de restore a partir do basename do item no backup.
# Remove sufixo .N e reconhece paths especiais.
_resolve_restore_target() {
  local base="$1"
  # Strip suffix .N se presente
  local stripped="$base"
  if [[ "$base" =~ ^(.+)\.([0-9]+)$ ]]; then
    stripped="${BASH_REMATCH[1]}"
  fi

  case "$stripped" in
    .config)
      echo "$USER_HOME/.config"
      return 0
      ;;
    greetd)
      echo "/etc/greetd"
      return 0
      ;;
    pam_greetd)
      echo "/etc/pam.d/greetd"
      return 0
      ;;
    *)
      # Tenta adivinhar a partir do nome do item (assumindo relativo a HOME)
      if [[ -n "${USER_HOME:-}" ]]; then
        echo "$USER_HOME/$stripped"
        return 0
      fi
      return 1
      ;;
  esac
}

# Restaura o backup mais recente com o label dado.
# Uso: backup_restore <label>
backup_restore() {
  local label="$1"
  local latest
  latest=$(backup_list | grep "^${label}-" | head -n1)

  if [[ -z "$latest" ]]; then
    log_error "Nenhum backup encontrado com label '$label'."
    return 1
  fi

  local src="$BACKUP_DIR/$latest"
  log_warn "Isso sobrescreverá os arquivos atuais com o backup '$latest'."

  if ! confirm "Continuar com o rollback?" "n"; then
    log_info "Rollback cancelado."
    return 0
  fi

  log_info "Restaurando backup '$latest'..."
  local item
  for item in "$src"/*; do
    [[ -e "$item" ]] || continue
    local rel
    rel=$(basename "$item")
    local target
    if ! target=$(_resolve_restore_target "$rel"); then
      log_warn "  → destino desconhecido para $rel, pulando."
      continue
    fi

    # Estratégia atômica: cp -a para staging, depois rm + mv
    local staging
    staging=$(mktemp -d -t gabrln-restore-XXXXXX)
    if ! cp -a "$item" "$staging/$(basename "$target")" 2>/dev/null; then
      log_warn "  → falha ao copiar $item para staging"
      rm -rf "$staging"
      continue
    fi

    # Garante que o parent existe (especialmente para /etc/greetd)
    mkdir -p "$(dirname "$target")"
    rm -rf "$target"
    if ! mv "$staging/$(basename "$target")" "$target"; then
      log_warn "  → falha ao mover $item para $target"
      rm -rf "$staging"
      continue
    fi
    rm -rf "$staging"

    # Restaura ownership se for path de usuário
    if ! _is_system_path "$target" && [[ -n "${REAL_USER:-}" ]]; then
      chown -R "$REAL_USER:$REAL_USER" "$target" 2>/dev/null || true
    fi

    log_info "  → $target"
  done

  log_success "Backup '$latest' restaurado."
}
