if [[ -z "$XDG_CONFIG_HOME" ]]; then
    export XDG_CONFIG_HOME="$HOME/.config"
fi

if [[ -d "$XDG_CONFIG_HOME/zsh" ]]; then
    export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
fi

if [[ -d "$HOME/.local/bin" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

if [[ -d "$HOME/.local/share/pi-node/node-v22.23.1-linux-x64/bin" ]]; then
    export PATH="$HOME/.local/share/pi-node/node-v22.23.1-linux-x64/bin:$PATH"
fi
