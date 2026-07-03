#!/usr/bin/env bash
# ToggleBlur.sh - Niri adaptation to toggle window blur in config.kdl

CONFIG_FILE="$HOME/.config/niri/config.kdl"

if [[ ! -f "$CONFIG_FILE" ]]; then
  notify-send -t 3000 -i dialog-error "Erro no Blur" "Arquivo de configuração do Niri não encontrado."
  exit 1
fi

if grep -q "passes 2" "$CONFIG_FILE"; then
  sed -i 's/passes 2/passes 0/g' "$CONFIG_FILE"
  notify-send "Blur Desativado" "Efeito de desfoque das janelas desativado." -t 2000
else
  sed -i 's/passes 0/passes 2/g' "$CONFIG_FILE"
  notify-send "Blur Ativado" "Efeito de desfoque das janelas ativado." -t 2000
fi
