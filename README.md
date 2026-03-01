📦 Essential Packages for S.I.G.M.A. / Hyprland

To ensure all scripts (such as WallustToggle, ClipManager, KillProcess, etc.) and UI elements function correctly, you need to install the following dependencies.

For Arch Linux / CachyOS users, you can copy and paste the commands below.

1. System Tools & Scripting (Required)

These packages are utilized by the custom scripts to process text (JSON), send notifications, and manage the clipboard.

sudo pacman -S --needed jq socat libnotify wl-clipboard cliphist findutils sed gawk psmisc xdg-utils


2. Interface & Shell (The Core UI)

These packages are responsible for drawing the top bar, application menus, session management, and wallpaper handling.

sudo pacman -S --needed waybar rofi-wayland swaync swww wlogout hyprlock hypridle


3. Colors & Themes (Wallust & GTK/Qt)

Required for the dynamic color extraction system (Wallust) and to ensure GTK/Qt apps follow the system theme.

# Wallust (Usually found in the AUR)
paru -S wallust-bin # or yay -S wallust-bin

# Theme Engines
sudo pacman -S --needed nwg-look kvantum qt5ct qt6ct


4. Fonts & Icons (Essential for Waybar/Rofi)

Without these, your bar and menus will display missing character squares (tofu) instead of the correct icons.

sudo pacman -S --needed ttf-jetbrains-mono-nerd ttf-font-awesome otf-font-awesome papirus-icon-theme


5. ZSH Plugins & Dependencies

Required dependencies to prevent errors when loading the customized .zshrc profile.

sudo pacman -S --needed zsh zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search pkgfile fzf zoxide expac


6. Hardware & Multimedia

Used by the Waybar modules and the custom keybindings for brightness, volume, and media control.

sudo pacman -S --needed pipewire wireplumber pavucontrol brightnessctl playerctl networkmanager blueman power-profiles-daemon


✅ Post-Installation Checklist

After installing the packages, ensure that the critical background services are enabled and running:

Network:

sudo systemctl enable --now NetworkManager


Bluetooth:

sudo systemctl enable --now bluetooth


Change Default Shell to ZSH:

chsh -s $(which zsh)


Update Pkgfile Database (Required for the command-not-found ZSH plugin to work):

sudo pkgfile --update


💡 Troubleshooting Pro Tip

If any script fails to execute properly, try running it manually from the terminal. If you encounter a "command not found" error, the name right after it is the exact package you missed installing!
