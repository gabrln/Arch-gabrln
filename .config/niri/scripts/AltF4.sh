#!/usr/bin/env bash
# AltF4.sh - Niri adaptation for force closing/killing the focused window

info=$(niri msg -j windows 2>/dev/null | jq -c '.[] | select(.is_focused == true)')

if [[ -z "$info" ]]; then
  notify-send -t 3000 -i dialog-error "Erro ao Encerrar" "Nenhuma janela focada localizada no Niri."
  exit 1
fi

pid=$(echo "$info" | jq -r '.pid // empty')
appid=$(echo "$info" | jq -r '.app_id // "Desconhecido"')
title=$(echo "$info" | jq -r '.title // "Aplicativo"')

protected_apps=("noctalia" "systemd" "dbus-daemon" "dbus-broker" "Xwayland" "pipewire" "wireplumber" "greetd" "niri")

for protected in "${protected_apps[@]}"; do
  if [[ "${appid,,}" == *"${protected,,}"* ]] || [[ "${title,,}" == *"${protected,,}"* ]]; then
    notify-send -t 3000 -i dialog-error "Acesso Negado" "Não é permitido encerrar o processo do sistema: $title"
    exit 1
  fi
done

if [[ -n "$pid" ]] && [[ "$pid" -le 1000 ]]; then
  notify-send -t 3000 -i dialog-error "Acesso Negado" "Não é permitido encerrar processos do sistema (PID: $pid)"
  exit 1
fi

if [[ -n "$pid" ]]; then
  kill -9 "$pid"
  notify-send -t 4000 -i dialog-warning "Processo Encerrado" "O processo <b>$title</b> (PID: $pid, AppID: $appid) foi encerrado forçadamente."
else
  niri msg action close-window
  notify-send -t 3000 -i dialog-information "Janela Fechada" "A janela foi fechada pelo método padrão (PID não localizado)."
fi
