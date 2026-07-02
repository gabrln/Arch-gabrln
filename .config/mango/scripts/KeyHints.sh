#!/usr/bin/env bash

shortcuts=(
  "mangowm  ::  SUPER + Return              ::  Open Terminal                 ::  kitty"
  "mangowm  ::  SUPER + Q                   ::  Close Window                  ::  mmsg dispatch killclient"
  "mangowm  ::  ALT + F4                    ::  Force Kill Window             ::  $HOME/.config/mango/scripts/AltF4.sh"
  "mangowm  ::  SUPER + SHIFT + Q           ::  Close Window (alt)            ::  mmsg dispatch killclient"
  "mangowm  ::  SUPER + F                   ::  Toggle Fullscreen             ::  mmsg dispatch togglefullscreen"
  "mangowm  ::  SUPER + M                   ::  Toggle Maximized              ::  mmsg dispatch togglemaximizescreen"
  "mangowm  ::  SUPER + Space               ::  Toggle Float                  ::  mmsg dispatch togglefloating"
  "mangowm  ::  SUPER + O                   ::  Toggle Overlay (Sticky)       ::  mmsg dispatch toggleoverlay"
  "mangowm  ::  SUPER + R                   ::  Reload Config                 ::  mmsg dispatch reload_config"
  "mangowm  ::  SUPER + Arrow Keys          ::  Move Focus                    ::  mmsg dispatch focusdir l/r/u/d"
  "mangowm  ::  SUPER + SHIFT + Arrow Keys   ::  Move/Swap Window              ::  mmsg dispatch exchange_client l/r/u/d"
  "mangowm  ::  CTRL + ALT + Arrow Keys     ::  Resize Active Window          ::  mmsg dispatch resizewin"
  "mangowm  ::  SUPER + [1-0]               ::  Switch to Tag [1-10]          ::  mmsg dispatch view [1-10]"
  "mangowm  ::  SUPER + SHIFT + [1-0]       ::  Move Window to Tag [1-10]     ::  mmsg dispatch tag [1-10]"
  "mangowm  ::  SUPER + TAB / SHIFT + TAB   ::  Next/Prev Tag                 ::  mmsg dispatch viewtoright/viewtoleft"
  "mangowm  ::  ALT + TAB                   ::  Toggle Overview               ::  mmsg dispatch toggleoverview"
  "mangowm  ::  SUPER + J / K               ::  Focus Next/Prev Stack         ::  mmsg dispatch focusstack next/prev"
  "mangowm  ::  SUPER + Mouse Scroll        ::  Next/Prev Tag                 ::  mmsg dispatch viewtoright/viewtoleft"
  "mangowm  ::  SUPER + SHIFT + Return      ::  Toggle Dropdown Terminal      ::  kitty-drop"
  "mangowm  ::  SUPER + F1                  ::  Toggle btop Monitor           ::  btop-scratch"
  "mangowm  ::  SUPER + U                   ::  Toggle Special Scratchpad     ::  toggle_scratchpad"
  "mangowm  ::  SUPER + SHIFT + U           ::  Send Window to Scratchpad     ::  mmsg dispatch minimized"
  "mangowm  ::  SUPER + CTRL + U            ::  Restore Minimized             ::  mmsg dispatch restore_minimized"
  "mangowm  ::  ALT + E                     ::  Set Proportion 1.0            ::  mmsg dispatch set_proportion 1.0"
  "mangowm  ::  ALT + X                     ::  Switch Proportion Preset      ::  mmsg dispatch switch_proportion_preset"
  "mangowm  ::  SUPER + Left Click          ::  Move Window                   ::  moveresize curmove"
  "mangowm  ::  SUPER + Right Click         ::  Resize Window                 ::  moveresize curresize"
  "mangowm  ::  SUPER + Scroll Up           ::  Previous Tag                  ::  viewtoleft_have_client"
  "mangowm  ::  SUPER + Scroll Down         ::  Next Tag                      ::  viewtoright_have_client"
  "mangowm  ::  SUPER + H                   ::  Show MangoWM Cheat Sheet      ::  KeyHints.sh"
  "mangowm  ::  CTRL + ALT + Del            ::  Exit MangoWM Session          ::  mmsg dispatch quit"

  "noctalia  ::  SUPER + D                  ::  App Launcher                  ::  noctalia msg panel-toggle launcher"
  "noctalia  ::  SUPER + V                  ::  Clipboard Manager             ::  noctalia msg panel-toggle clipboard"
  "noctalia  ::  SUPER + P                  ::  Control Center / Audio        ::  noctalia msg panel-toggle session"
  "noctalia  ::  SUPER + I                  ::  Noctalia Settings             ::  noctalia msg settings-toggle"
  "noctalia  ::  SUPER + SHIFT + N          ::  Notification Panel            ::  noctalia msg panel-toggle control-center notifications"
  "noctalia  ::  SUPER + SHIFT + D          ::  Active Window Info            ::  $HOME/.config/mango/scripts/WindowInfo.sh"
  "noctalia  ::  CTRL + ALT + L             ::  Lock Screen                   ::  noctalia msg session lock"
  "noctalia  ::  CTRL + ALT + P             ::  Logout Menu                   ::  noctalia msg panel-toggle session"
  "noctalia  ::  SUPER + N                  ::  Toggle Night Light            ::  noctalia msg nightlight-toggle"
  "noctalia  ::  SUPER + Y                  ::  Toggle Caffeine (No Sleep)    ::  noctalia msg caffeine-toggle"
  "noctalia  ::  SUPER + W                  ::  Random Wallpaper              ::  noctalia msg wallpaper-random"
  "noctalia  ::  SUPER + SHIFT + T          ::  Toggle Dark/Light Theme       ::  noctalia msg theme-mode-toggle"
  "noctalia  ::  SUPER + SHIFT + B          ::  Toggle Screen Blur            ::  $HOME/.config/mango/scripts/ToggleBlur.sh"
  "noctalia  ::  SUPER + SHIFT + G          ::  Toggle Gamemode               ::  $HOME/.config/mango/scripts/ToggleGamemode.sh"
  "noctalia  ::  SUPER + F2                 ::  Toggle Microphone Mute        ::  noctalia msg mic-mute"
  "noctalia  ::  SUPER + Print              ::  Screenshot Fullscreen         ::  noctalia msg screenshot-fullscreen"
  "noctalia  ::  SUPER + SHIFT + Print      ::  Screenshot Region             ::  noctalia msg screenshot-region"
  "noctalia  ::  ALT + Print                ::  Screenshot Active Window      ::  noctalia msg screenshot-fullscreen pick"
  "noctalia  ::  Volume/Brightness Keys     ::  Volume/Brightness controls    ::  noctalia volume/brightness"
  "noctalia  ::  Play/Pause/Next/Prev       ::  Media controls                ::  noctalia msg media toggle/next/prev"

  "comando   ::  SUPER + Return             ::  Open Terminal                 ::  kitty"
  "comando   ::  SUPER + B                  ::  Launch Browser                ::  firefox"
  "comando   ::  SUPER + E                  ::  File Manager (Yazi)           ::  kitty -e yazi"
  "comando   ::  SUPER + SHIFT + E          ::  File Manager (Nautilus)       ::  nautilus"
  "comando   ::  c / q                      ::  Clear / Exit                  ::  c / q"
  "comando   ::  .. / ... / ....            ::  Navigate Up                    ::  cd .. / ... / ...."
  "comando   ::  ls / ll / la / lt          ::  List Files (eza)              ::  ls / ll / la / lt"
  "comando   ::  grep / find                ::  ripgrep / fd                  ::  rg / fd"
  "comando   ::  update                     ::  System Update (yay)            ::  yay -Syu"
  "comando   ::  install <pkg>              ::  Install Package               ::  yay -S"
  "comando   ::  remove <pkg>               ::  Remove Package                ::  yay -Rns"
  "comando   ::  search <pkg>               ::  Search Package                ::  yay -Ss"
  "comando   ::  make / ninja               ::  Parallel Build                ::  make -j\$(nproc) / ninja -j\$(nproc)"
  "comando   ::  conf-mango                 ::  Edit Mango Config             ::  nvim ~/.config/mango/config.conf"
  "comando   ::  conf-zsh                   ::  Edit Zsh Config               ::  nvim ~/.config/zsh/.zshrc"
  "comando   ::  conf-kitty                 ::  Edit Kitty Config             ::  nvim ~/.config/kitty/kitty.conf"
  "comando   ::  conf-zj                    ::  Edit Zellij Config            ::  nvim ~/.config/zellij/config.kdl"
  "comando   ::  reload-zsh                 ::  Reload Zsh Config             ::  source ~/.config/zsh/.zshrc"
  "comando   ::  g / gst / gd               ::  Git Status/Diff               ::  git status/diff"
  "comando   ::  ga / gc / gp / gpl         ::  Git Add/Commit/Push/Pull      ::  git add/commit/push/pull"
  "comando   ::  gl / glog / gadog          ::  Git Log                       ::  git log variants"
  "comando   ::  zj / zja / zm              ::  Zellij Sessions               ::  zellij"
  "comando   ::  zjl / zjda                 ::  Zellij List/Delete All        ::  zellij list/delete"
  "comando   ::  dk-start / dk-stop         ::  Docker Control                ::  systemctl docker"
  "comando   ::  zplu                       ::  Update Zsh Plugins            ::  zplugin-update"
  "comando   ::  y                          ::  Yazi (preserve cwd)           ::  yazi wrapper"
)

selected=$(printf "%s\n" "${shortcuts[@]}" | column -t -s '::' | \
  fzf --header=" [ ENTER: Copiar comando para o clipboard | ESC: Sair ]" \
      --layout=reverse \
      --border=rounded \
      --prompt=" Pesquisar atalho: ")

if [[ -n "$selected" ]]; then
  selected_trimmed=$(echo "$selected" | xargs)

  for item in "${shortcuts[@]}"; do
    item_formatted=$(echo "$item" | sed 's/ :: /   /g' | xargs)
    if [[ "$selected_trimmed" == "$item_formatted"* ]]; then
      action=$(echo "$item" | awk -F ' :: ' '{print $4}')
      if [[ -n "$action" ]]; then
        echo -n "$action" | wl-copy
        notify-send "Atalho Copiado" "Comando '$action' copiado para o clipboard!" -t 2000 -i edit-copy
      fi
      break
    fi
  done
fi
