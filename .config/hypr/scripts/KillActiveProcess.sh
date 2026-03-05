#!/usr/bin/env bash
# Force kill the active window's process (panic button)

ICON_OK="$HOME/.config/swaync/images/ja.png"
ICON_ERR="$HOME/.config/swaync/images/error.png"

if ! command -v jq &> /dev/null; then
    notify-send -u critical -i "$ICON_ERR" "Kill" "Pacote 'jq' ausente"
    exit 1
fi

window_data=$(hyprctl activewindow -j)

if [[ -z "$window_data" || "$window_data" == "{}" ]]; then
    notify-send -u low -i "$ICON_ERR" "Kill" "Nenhuma janela ativa"
    exit 1
fi

active_pid=$(echo "$window_data" | jq -r '.pid // empty')
app_class=$(echo "$window_data" | jq -r '.class // "App"')

# Validate PID is a positive integer
if [[ -z "$active_pid" || ! "$active_pid" =~ ^[1-9][0-9]*$ ]]; then
    notify-send -u critical -i "$ICON_ERR" "Kill" "PID inválido (abortado)"
    exit 1
fi

# Prevent killing system processes (PID < 100)
if [[ "$active_pid" -le 100 ]]; then
    notify-send -u critical -i "$ICON_ERR" "Kill" "Bloqueado (processo do sistema)"
    exit 1
fi

if kill -9 "$active_pid" 2>/dev/null; then
    notify-send -i "$ICON_OK" "Kill" "Processo '$app_class' finalizado 💀"
else
    notify-send -u critical -i "$ICON_ERR" "Kill" "Sem permissão ($app_class)"
fi
