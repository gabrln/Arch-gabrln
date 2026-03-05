# ─────────────────────────────────────────────────────────────────────────────
#  .zshrc - GSOURZA EDITION (Otimizado & Organizado)
# ─────────────────────────────────────────────────────────────────────────────

# --- POWERLEVEL10K INSTANT PROMPT ---
# Deve ficar no topo.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- VARIÁVEIS DE AMBIENTE (Ambiente e Ferramentas) ---
export ZSH="/usr/share/oh-my-zsh"
export EDITOR="nvim"
export FZF_BASE=/usr/share/fzf
export QT_QPA_PLATFORMTHEME=qt6ct
export HISTCONTROL=ignoreboth
export HISTORY_IGNORE="(\&|[bf]g|c|clear|history|exit|q|pwd|* --help)"
export TERMINAL=kitty

# Cores customizadas para páginas de man via `less`
export LESS_TERMCAP_md="$(tput bold 2> /dev/null; tput setaf 2 2> /dev/null)"
export LESS_TERMCAP_me="$(tput sgr0 2> /dev/null)"

# --- CONFIGURAÇÃO OH-MY-ZSH ---
DISABLE_MAGIC_FUNCTIONS="true"
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"

# PLUGINS OH-MY-ZSH (Plugins internos do framework)
# Recomendação: Adicionados 'sudo', 'web-search' e 'copypath'
plugins=(git fzf extract sudo web-search copypath z)

# Iniciar Oh My Zsh
source $ZSH/oh-my-zsh.sh

# ─────────────────────────────────────────────────────────────────────────────
#  ALIASES - SISTEMA E NAVEGAÇÃO
# ─────────────────────────────────────────────────────────────────────────────
alias c="clear"
alias q="exit"
alias please="sudo"
alias tb="nc termbin.com 9999"

# Compilação Otimizada
alias make="make -j$(nproc)"
alias ninja="ninja -j$(nproc)"
alias n="ninja"

# Gestão de Pacotes (Arch/Pacman)
alias update="sudo pacman -Syu"
alias rmpkg="sudo pacman -Rsn"
alias cleanch="sudo pacman -Scc"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias cleanup="sudo pacman -Rsn $(pacman -Qtdq)"

# Logs e Histórico
alias jctl="journalctl -p 3 -xb"
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -20 | nl"

# ─────────────────────────────────────────────────────────────────────────────
#  PLUGINS EXTERNOS (Sourcing Manual Arch Linux)
# ─────────────────────────────────────────────────────────────────────────────
# Nota: Garante que estes pacotes estão instalados via pacman
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
source /usr/share/doc/pkgfile/command-not-found.zsh

# --- POWERLEVEL10K TEMA ---
# Deve ficar no final.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# --- COMPORTAMENTO FINAL ---
# Desativa a correção automática que costuma incomodar em scripts
unsetopt CORRECT
unsetopt CORRECT_ALL
export PATH=$HOME/.local/bin:$PATH
