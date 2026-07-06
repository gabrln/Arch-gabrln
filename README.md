# Arch-gabrln

Ambiente Wayland para Arch/CachyOS: **Hyprland 0.55 + Noctalia V5**.
Stack de pacotes: `pacman` (oficial CachyOS) · `yay` (AUR) · `flatpak`.

## Instalação

```bash
curl -fsSL https://raw.githubusercontent.com/gabrln/Arch-gabrln/main/install.sh | sudo -E bash
```

O instalador clona o repo em `~/Projects/Arch-gabrln` e roda o framework `gabrln`. Requer Arch ou CachyOS.

## Comandos

| Comando | O que faz |
|---|---|
| `gabrln install` | Instalação completa (módulos 00–16) |
| `gabrln update` | Atualiza dotfiles, AUR `-git` e hyprpm |
| `gabrln repair` | Reaplicar configs divergentes |
| `gabrln backup` | Snapshot manual das configs |
| `gabrln rollback` | Restaurar snapshot mais recente |
| `gabrln doctor` | Diagnóstico read-only |

## Atalhos principais

- `Super + T` — Terminal (Kitty)
- `Super + D` — Launcher
- `Alt + Tab` — Overview (hyprpm scrolloverview)
- `Super + B` — Firefox
- `Super + /` — Cheat sheet completo
- `Super + Q` — Fechar janela
