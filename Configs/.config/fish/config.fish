# Commands to run in interactive sessions can go here
if status is-interactive
    source "$__fish_config_dir/auto-Hypr.fish"

    # Remap the indexed colors used by this Fish-specific Starship prompt.
    if test -f "$__fish_config_dir/sequences.txt"
        cat "$__fish_config_dir/sequences.txt"
    end

    # No greeting
    set fish_greeting

    # Use starship
    set -gx STARSHIP_CONFIG "$HOME/.config/starship.toml"
    function starship_transient_prompt_func
        starship module character
    end
    if test "$TERM" != "linux"
        starship init fish | source
        enable_transience
    end

    # Aliases
    # kitty doesn't clear properly so we need to do this weird printing
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias pamcan pacman
    alias q 'qs -c ii'
    if test "$TERM" != "linux"
        alias ls 'eza --icons=auto'
    end
    if test "$TERM" = "xterm-kitty"
        alias ssh 'kitten ssh'
    end
end
