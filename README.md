# Arch-gabrln

Ambiente Wayland focado em produtividade e estética unificada no **Arch Linux / CachyOS**, configurado em puro **Lua** com **Hyprland** e **Noctalia V5**.

## Stack

* **Compositor & Shell**: Hyprland (Lua Config) + Noctalia V5
* **Terminal & TUI**: Kitty, Zellij, Neovim e Yazi
* **Pacotes**: Shelly CLI (ALPM, AUR e Flatpak)
* **AI Coding**: Antigravity CLI, Herdr e Pi-coding-agent

## Instalação

O instalador automatiza a instalação de pacotes, diretórios XDG, wallpapers e sincroniza os dotfiles.

**Instalação padrão (recomendado):**
```bash
curl -fsSL https://raw.githubusercontent.com/gabrln/Arch-gabrln/main/install.sh | sudo -E bash
```

O `install.sh` é um thin wrapper que clona/atualiza este repositório em `~/Projects/Arch-gabrln` e executa o framework `gabrln`.

## Comandos do framework

Após clonar o repositório, os comandos estão disponíveis em `~/Projects/Arch-gabrln/gabrln`:

| Comando | Descrição |
|---|---|
| `gabrln install` | Instalação completa do ambiente |
| `gabrln update` | Atualiza dotfiles, pacotes AUR `-git` e manifesto hyprpm |
| `gabrln repair` | Reaplica configurações divergentes |
| `gabrln backup` | Cria snapshot manual das configurações |
| `gabrln rollback` | Restaura o snapshot mais recente |
| `gabrln doctor` | Diagnóstico somente leitura do estado atual |

Opções comuns: `--gaming` (instala pacotes com tag gaming), `--force` (ignora estado e reexecuta).

## Pós-instalação

O framework roda antes do primeiro login gráfico, num TTY sem sessão Hyprland ativa. O plugin **scrolloverview** (necessário para o atalho `Alt + Tab`) é aplicado automaticamente pelo `autostart.lua` no primeiro login, quando o Hyprland já está funcional.

Se o atalho `Alt + Tab` não funcionar após o primeiro login, execute manualmente:

```bash
hyprpm update
hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git
hyprpm enable scrolloverview
```

## Atalhos Principais

| Atalho | Ação |
|---|---|
| `Super + T` | Terminal (Kitty) |
| `Super + Shift + T` | Terminal Dropdown (Scratchpad) |
| `Super + D` | Launcher de Aplicativos |
| `Alt + Tab` | Overview de Janelas / Workspaces |
| `Super + B` | Navegador (Firefox) |
| `Super + /` | Cheat Sheet interativo de atalhos |
| `Super + G` | Modo Abas (Grupos) |
| `Super + V` | Histórico da Área de Transferência |
| `Super + Shift + W` | Alternar Tema Claro / Escuro |
| `Super + Q` / `Alt + F4` | Fechar Janela |
