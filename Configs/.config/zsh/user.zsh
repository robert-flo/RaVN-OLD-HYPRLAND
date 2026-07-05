#  Startup 
# Commands to execute at the end of init (before the prompt is shown)
# Check if the interactive shell option is set
if [[ $- == *i* ]]; then
    # Launch the herdr terminal workspace manager. `herdr` attaches to the
    # persistent session if one is already running, otherwise it starts a
    # server and opens the TUI. When herdr exits, the zsh prompt stays
    # available as a fallback, so alias/completion/plugin state is preserved.
    if command -v herdr >/dev/null; then
        herdr
    fi
fi

#   Overrides 
# HYDE_ZSH_NO_PLUGINS=1 # Set to 1 to disable loading of oh-my-zsh plugins, useful if you want to use your zsh plugins system
# unset HYDE_ZSH_PROMPT # Uncomment to unset/disable loading of prompts from HyDE and let you load your own prompts
# HYDE_ZSH_COMPINIT_CHECK=1 # Set 24 (hours) per compinit security check // lessens startup time
# HYDE_ZSH_OMZ_DEFER=1 # Set to 1 to defer loading of oh-my-zsh plugins ONLY if prompt is already loaded

zstyle :omz:plugins:ssh-agent lifetime 24h
zstyle :omz:plugins:ssh-agent identities id_ed25519

if [[ ${HYDE_ZSH_NO_PLUGINS} != "1" ]]; then
    #  OMZ Plugins 
    # manually add your oh-my-zsh plugins here
    plugins=(
        "sudo"
        "ssh-agent"
    )
fi


# unset -f command_not_found_handler # Uncomment to prevent searching for commands not found in package manager

# Initialize try so it can register commands/environments from ~/src/tries.
eval "$(try init ~/src/tries)"

# Add user-installed mise executables to PATH.
add_to_path "$HOME/.local/share/mise/shims"

#  Emacs 
export EDITOR="emacsclient -nw"
export VISUAL="emacsclient -nw"

#  Go 
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin:/usr/local/go/bin

#  Waybar Tasks & Countdowns Custom Aliases 
# Interactive Terminal UIs (TUI)
alias todo="~/.local/share/waybar/scripts/todo/todo.sh --show-tui"
alias countdown="~/.local/share/waybar/scripts/countdown/countdown.sh --show-tui"

# Direct raw JSON configuration edits
alias todo-edit='${EDITOR:-nano} ~/.local/state/waybar/todo.json'
alias countdown-edit='${EDITOR:-nano} ~/.local/state/waybar/countdown.json'

#  GitHub CLI Configuration 
export GH_EDITOR="${EDITOR:-nvim}"
export GH_PAGER="less -FR"
# Source Git and GitHub CLI shell aliases
if [[ -f ~/.config/git/shell_aliases ]]; then
    source ~/.config/git/shell_aliases
fi

#  Personal Overrides & Custom Aliases 
export MANPAGER='nvim +Man!'
export PYTHON_BASIC_REPL=1
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
if [[ ! -d $NPM_CONFIG_PREFIX/bin ]]; then
  mkdir -p "$NPM_CONFIG_PREFIX/bin"
fi
add_to_path "$NPM_CONFIG_PREFIX/bin"


alias fn='nvim $(fzf)'
alias fp='zathura $(fzf)'
alias da='direnv allow .'
alias lzd='DOCKER_HOST=unix:///run/user/1000/podman/podman.sock lazydocker'
alias rviz2='QT_QPA_PLATFORM=xcb rviz2'
alias t='tree --depth=1'
alias tt='tree --depth=2'
alias ttt='tree --depth=3'
