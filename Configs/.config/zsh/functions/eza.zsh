# Keep `l` available for ~/.local/bin/l (git pull).
unalias l 2>/dev/null || true
# Keep `d` available for ~/.local/bin/d (git diff).
unfunction d 2>/dev/null || true

if command -v "eza" &>/dev/null; then
    alias lll='eza -lh --icons=auto' \
        ll='eza -lha --icons=auto --sort=name --group-directories-first' \
        ld='eza -lhD --icons=auto' \
        lt='eza --icons=auto --tree'
fi
