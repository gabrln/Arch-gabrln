#!/usr/bin/env bash
# install.sh - Bootstrap thin wrapper para o framework Arch-gabrln
# Uso: curl -fsSL .../install.sh | sudo bash
#
# Sobre privilégios:
#   Este bootstrap é executado com `sudo bash` porque o polkit não tem
#   agent rodando no momento da inicialização (TTY de login, sem sessão
#   gráfica). É o ÚNICO lugar do framework que ainda usa `sudo` para
#   escalação.
#   Para descer de root para o usuário real, usamos `runuser -u USER --`
#   em vez de `sudo -u USER --` (não precisa de NOPASSWD sudoers, não
#   polui sudoers.d, é o método correto quando já somos root).
#   Polkit é instalado e gerenciado pelo framework em si (ver
#   installer/lib/errors.sh::setup_polkit_policy).

set -euo pipefail

REPO_URL="https://github.com/gabrln/Arch-gabrln.git"
CLONE_SUBDIR="Projects/Arch-gabrln"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

error() {
  echo -e "${RED}[ERRO]${NC} $1" >&2
  exit "${2:-1}"
}

info() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}

success() {
  echo -e "${GREEN}[OK]${NC} $1"
}

# Identificar usuário real
if [[ $EUID -ne 0 ]]; then
  error "Execute este script com sudo. Ex: curl ... | sudo bash"
fi

if [[ -z "${SUDO_USER:-}" ]]; then
  error "Não foi possível determinar SUDO_USER. Execute via sudo."
fi

REAL_USER="$SUDO_USER"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
  error "Não foi possível determinar o HOME do usuário '$REAL_USER'."
fi

if [[ "$REAL_USER" == "root" ]]; then
  error "Execute como usuário normal com sudo. Ex: curl ... | sudo bash"
fi

# Verifica que runuser está disponível (util-linux, parte do base)
if ! command -v runuser &>/dev/null; then
  error "Comando 'runuser' não encontrado. Instale 'util-linux'."
fi

REPO_DIR="$USER_HOME/$CLONE_SUBDIR"

# Garantir git
if ! command -v git &>/dev/null; then
  info "Instalando git..."
  pacman -Sy --needed --noconfirm git
fi

# Clonar ou atualizar o repositório
# -c safe.directory="*" inline para evitar "fatal: detected dubious ownership"
# quando o repo foi clonado por root e depois usado por outro usuário.
if [[ -d "$REPO_DIR/.git" ]]; then
  info "Atualizando repositório em $REPO_DIR..."
  # Corrige ownership caso arquivos tenham ficado como root de execução anterior
  chown -R "$REAL_USER:$REAL_USER" "$REPO_DIR" 2>/dev/null || true
  # runuser em vez de sudo -u: já somos root, só queremos trocar UID.
  # bash -lc carrega /etc/profile (que define PATH) e ~/.bash_profile
  # do usuário, preservando PATH para que git funcione corretamente.
  runuser -u "$REAL_USER" -- bash -lc "git -c safe.directory='*' -C '$REPO_DIR' pull" \
    || error "git pull falhou em $REPO_DIR"
else
  info "Clonando repositório para $REPO_DIR..."
  # Garante que o HOME do usuário existe e pertence ao usuário
  if [[ ! -d "$USER_HOME" ]]; then
    error "HOME do usuário '$REAL_USER' não existe: $USER_HOME"
  fi
  # Cria o diretório pai como root
  if ! mkdir -p "$USER_HOME/Projects" 2>/dev/null; then
    # Fallback: tenta como o usuário
    runuser -u "$REAL_USER" -- bash -lc "mkdir -p '$USER_HOME/Projects'" \
      || error "Falha ao criar $USER_HOME/Projects. Verifique permissões do $USER_HOME."
  fi
  chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/Projects"
  if [[ ! -d "$USER_HOME/Projects" ]]; then
    error "Diretório $USER_HOME/Projects não foi criado."
  fi
  runuser -u "$REAL_USER" -- bash -lc "git -c safe.directory='*' clone '$REPO_URL' '$REPO_DIR'" \
    || error "git clone falhou para $REPO_DIR"
  chown -R "$REAL_USER:$REAL_USER" "$REPO_DIR"
fi

success "Repositório pronto em $REPO_DIR"
info "Executando o framework..."

# Delegar para o entrypoint real
exec "$REPO_DIR/installer/gabrln" "$@"
