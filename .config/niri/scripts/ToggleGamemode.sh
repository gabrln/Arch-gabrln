#!/usr/bin/env bash
# ToggleGamemode.sh - Niri adaptation to toggle gaps and blur for gaming performance

CONFIG_FILE="$HOME/.config/niri/config.kdl"

if [[ ! -f "$CONFIG_FILE" ]]; then
  notify-send -t 3000 -i dialog-error "Erro no Modo Jogo" "Arquivo de configuração do Niri não encontrado."
  exit 1
fi

if grep -q "gaps 8" "$CONFIG_FILE"; then
  # Ativar Gamemode (gaps 0, blur passes 0)
  sed -i 's/gaps 8/gaps 0/g' "$CONFIG_FILE"
  sed -i 's/passes 2/passes 0/g' "$CONFIG_FILE"
  notify-send "Modo Jogo Ativado" "Animações, desfoque e espaçamentos desativados." -t 2000
else
  # Desativar Gamemode (restaurar gaps 8, blur passes 2)
  sed -i 's/gaps 0/gaps 8/g' "$CONFIG_FILE"
  sed -i 's/passes 0/passes 2/g' "$CONFIG_FILE"
  notify-send "Modo Jogo Desativado" "Configurações de interface restauradas." -t 2000
fi
