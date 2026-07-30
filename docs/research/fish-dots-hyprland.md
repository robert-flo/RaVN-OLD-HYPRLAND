# Fish configuration from dots-hyprland

RaVN's Fish configuration and Fish-specific Starship prompt are derived from
[`end-4/dots-hyprland`](https://github.com/end-4/dots-hyprland) commit
`aed4d1ec63f584905c28d2a678db5845579fdafc`.

## Imported material

- `dots/.config/fish/config.fish`
- `dots/.config/fish/auto-Hypr.fish`
- `dots/.config/fish/fish_variables`
- `dots/.config/starship.toml`
- `dots/.config/quickshell/ii/scripts/colors/terminal/sequences.txt`

The imported files are distributed by their upstream project under the
[GNU General Public License version 3](https://github.com/end-4/dots-hyprland/blob/aed4d1ec63f584905c28d2a678db5845579fdafc/LICENSE).

## Terminal color adaptation

The imported Starship configuration uses extended indexed terminal colors. Its
upstream Fish configuration prints a Quickshell-generated `sequences.txt` to
map those indexes to Material colors. RaVN retains that mechanism without
introducing a Quickshell dependency: the fallback file lives at
`~/.config/fish/sequences.txt`, and the `fish-sequences.dcol` Wallbash template
regenerates it from the active wallpaper palette. Fish prints the file before
Starship is initialized. The Material roles are mapped to equivalent Wallbash
primary, secondary, tertiary, error, foreground, and background roles.

RaVN also sources `auto-Hypr.fish` from interactive Fish sessions. The upstream
file is stored at the Fish configuration root, which Fish does not autoload by
itself; the explicit source makes its intended TTY1 login behavior effective.

Fish explicitly selects `~/.config/starship.toml` before initializing Starship.
This prevents an exported `STARSHIP_CONFIG` from a parent Zsh session from
selecting RaVN's Zsh-specific prompt inside Fish.

The upstream `fish_variables` file is retained verbatim. It records Fisher as a
universal variable but does not install Fisher or any additional plugins.
