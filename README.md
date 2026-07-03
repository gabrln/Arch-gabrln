NOCTALIA V5 + NIRI + CACHYOS.

## Stack

| Camada | Ferramenta |
|--------|------------|
| Compositor | Niri |
| Shell | Noctalia V5 |
| Terminal | Kitty |
| Gerenciador de Arquivos | Yazi + Nautilus |
| Multiplexador | Zellij |
| Prompt | Starship |
| Editor | Neovim (LazyVim) |
| Pacotes | yay (AUR helper) |

## Instalação e Bootstrap Dinâmico (install.sh)

A configuração do sistema, pacotes, links simbólicos e configurações root agora são instalados e sincronizados de forma totalmente automatizada através do script `install.sh`.

Você pode executar o instalador de qualquer lugar (inclusive em uma máquina limpa) com o comando de uma linha abaixo:

```bash
curl -fsSL https://raw.githubusercontent.com/gabrln/Arch-gabrln/main/install.sh | bash
```

*(Se preferir executar localmente a partir da pasta do repositório: `cd ~/projects/Arch-gabrln && ./install.sh`)*

> [!NOTE]
> O instalador cria backups com carimbo de data/hora (timestamps) para quaisquer pastas físicas conflitantes encontradas em `~/.config/` (ex: `niri.backup.YYYYMMDD_HHMMSS`) e cria links simbólicos (`symlinks`) apontando para o seu repositório local, mantendo suas dotfiles sempre em sincronia com o Git.

## Principais Recursos Integrados

* **Navegação Vim Completa no Niri:** Mapeamentos de foco e movimentação utilizando as teclas nativas do Vim (`H/J/K/L`). O atalho do Cheatsheet foi movido para `Mod+Slash` (`Mod+/`) para liberar a tecla `H`.
* **Tema no Neovim (LazyVim):** Instalação automática do LazyVim Starter com integração contínua do tema de cores do Noctalia (via template do Matugen e recarga dinâmica em tempo real com o sinal `SIGUSR1`).
* **Suporte a Apps Root (btrfs-assistant):** Sincronização automática dos temas GTK/Qt e cursores para o usuário `root`, permitindo que aplicativos administrativos herdem o visual escuro unificado.
* **Cursor no Greeter:** Aplica o cursor do ponteiro `Bibata-Modern-Classic` diretamente na tela de login do Noctalia Greeter (`greetd`).

## Pacotes Importantes Instalados

O instalador cuida de baixar e configurar toda a base do sistema:
* **Core:** `base`, `base-devel`, `linux-cachyos`, `linux-cachyos-headers`, `git`, `docker`, `flatpak`, `brightnessctl`, `snapper`, `just`.
* **Interface Gráfica & Window Manager:** `niri`, `noctalia-git`, `noctalia-greeter-git`, `niri-scratchpad-rs-git`, `xdg-desktop-portal-gnome`, `xdg-desktop-portal-gtk`, `nwg-look`, `pavucontrol`, `bibata-cursor-theme`.
* **Aplicações:** `firefox`, `kitty`, `neovim`, `zellij`, `yazi`, `nautilus`, `vesktop`, `obsidian`, `spotify-launcher`, `prismlauncher`, `easyeffects` (Flatpak).
* **Utilidades CLI:** `zsh`, `atuin`, `starship`, `zoxide`, `direnv`, `fzf`, `ripgrep`, `fd`, `bat`, `eza`, `fastfetch`, `btop`, `grim`, `slurp`, `cliphist`, `wl-clipboard`, `wl-clip-persist`, `gnome-keyring`, `seahorse`, `rtkit`.
