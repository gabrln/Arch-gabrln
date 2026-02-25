#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# SCRIPT: MagicMonitor.sh
# OBJETIVO: Ouvir o Hyprland e enviar notificações Toast para o Noctalia
# ═══════════════════════════════════════════════════════════════════════════

if ! command -v socat &>/dev/null; then
  echo "ERRO: O socat não está instalado."
  exit 1
fi

# Variável de estado (Memória do script)
MAGIC_ABERTO=false

# Ouve o canal de eventos do Hyprland continuamente
socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do

  # ─── O MAGIC FOI ABERTO ───
  if [[ "$line" == "activespecial>>special:magic,"* ]]; then
    MAGIC_ABERTO=true
    qs -c noctalia-shell ipc call toast send '{"title":"🪄 MODO MAGIC","body":"Workspace Especial Ativado","type":"notice","duration":3000}'

  # ─── OUTRO SPECIAL FOI ABERTO (Ex: Terminal) ───
  # Se abrir o terminal, garantimos que a memória sabe que o magic não está a uso
  elif [[ "$line" == "activespecial>>special:"* ]]; then
    MAGIC_ABERTO=false

  # ─── UM SPECIAL FOI FECHADO ───
  elif [[ "$line" == "activespecial>>,"* ]]; then

    # Só envia a notificação de saída SE o magic era o que estava aberto
    if [ "$MAGIC_ABERTO" = true ]; then
      qs -c noctalia-shell ipc call toast send '{"title":"🪄 MODO MAGIC","body":"Workspace Especial Desativado","type":"notice","duration":2000}'
      MAGIC_ABERTO=false # Reseta a memória
    fi

  fi

done
