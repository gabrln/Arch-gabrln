#!/bin/bash
# Scratchpad — Terminal
# Abre a janela se não existir, ou mostra/esconde se já estiver rodando

RUNNING=$(hyprctl clients -j | jq -r '.[] | select(.class == "scratch_term") | .class')

if [ -z "$RUNNING" ]; then
  kitty --class scratch_term &
  sleep 0.3
fi

hyprctl dispatch togglespecialworkspace scratch_term
