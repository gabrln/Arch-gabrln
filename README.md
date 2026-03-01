# Dependências 

Pacotes necessários para Arch Linux / CachyOS.

## 📦 Instalação

```bash
# System Tools & Scripting
sudo pacman -S --needed jq socat libnotify wl-clipboard cliphist findutils sed gawk psmisc xdg-utils

# Interface & Core UI
sudo pacman -S --needed waybar rofi-wayland swaync swww wlogout hyprlock hypridle

# Colors & Theme Engines
paru -S wallust-bin
sudo pacman -S --needed nwg-look kvantum qt5ct qt6ct

# Fonts & Icons
sudo pacman -S --needed ttf-jetbrains-mono-nerd ttf-font-awesome otf-font-awesome papirus-icon-theme

# ZSH Environment
sudo pacman -S --needed zsh zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search pkgfile fzf zoxide expac

# Hardware & Multimedia
sudo pacman -S --needed pipewire wireplumber pavucontrol brightnessctl playerctl networkmanager blueman power-profiles-daemon

✅ Pós-instalação

# Habilitar serviços
sudo systemctl enable --now NetworkManager bluetooth

# Mudar shell para ZSH (logout/login depois)
chsh -s $(which zsh)

# Atualizar pkgfile (para command-not-found)
sudo pkgfile --update
