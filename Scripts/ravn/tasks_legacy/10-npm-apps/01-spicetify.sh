#!/usr/bin/env bash
# ─── RaVN Task: Spicetify (Sleek Theme) ─────────────────────────────────────
# Rewritten based on nix-dotfiles/spotify.sh
# Configures Sleek theme with Wallbash color scheme for Spotify.
# Supports system package manager, Flatpak, and spotify-launcher.

# shellcheck disable=SC2034,SC2154
PACKAGE="spicetify"
DESCRIPTION="Spotify Sleek theme (Wallbash) via Spicetify"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  local spotify_path=""
  local shareDir=${XDG_DATA_HOME:-$HOME/.local/share}

  if [[ -n ${SPOTIFY_PATH:-} ]]; then
    spotify_path="${SPOTIFY_PATH}"
  elif [[ -d ${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify ]]; then
    spotify_path="${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify"
  elif [[ -d /var/lib/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify ]]; then
    spotify_path="/var/lib/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify"
  elif [[ -f ${shareDir}/spotify-launcher/install/usr/bin/spotify ]]; then
    spotify_path="${shareDir}/spotify-launcher/install/usr/share/spotify"
  elif [[ -d /opt/spotify ]]; then
    spotify_path="/opt/spotify"
  fi

  # Skip if spotify or spicetify is not installed/present
  if ! { { pkg_installed spotify && pkg_installed spicetify-cli; } || [[ -e $spotify_path ]]; }; then
    return 0
  fi

  # Skip if already configured to Sleek theme and Wallbash color scheme
  local current_theme
  local color_scheme
  current_theme=$(spicetify config 2>/dev/null | awk '{if ($1=="current_theme") print $2}') || true
  color_scheme=$(spicetify config 2>/dev/null | awk '{if ($1=="color_scheme") print $2}') || true

  if [[ $current_theme == "Sleek" && $color_scheme == "Wallbash" ]]; then
    return 0
  fi

  return 1
}

install() {
  if ((flg_DryRun == 1)); then
    info "Simulación: Saltando configuración de Spicetify."
    return 0
  fi

  local spotify_path=""
  local shareDir=${XDG_DATA_HOME:-$HOME/.local/share}
  local cache_dir="${cacheDir:-$XDG_CACHE_HOME/hyde}"

  # 1. Determine Spotify path and print logging
  if [[ -n ${SPOTIFY_PATH:-} ]]; then
    spotify_path="${SPOTIFY_PATH}"
    cat <<EOF
[warning]   using custom spotify path
            ensure to have proper permissions for ${SPOTIFY_PATH}
            run:
            chmod a+wr ${SPOTIFY_PATH}
            chmod a+wr -R ${SPOTIFY_PATH}/Apps

            note: run with 'sudo' if only needed.
EOF
  elif [[ -d ${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify ]]; then
    spotify_path="${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify"
    print_log -sec "Spotify" " User Flatpak"
  elif [[ -d /var/lib/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify ]]; then
    spotify_path="/var/lib/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify"
    print_log -sec "Spotify" " System Flatpak"
  elif [[ -f ${shareDir}/spotify-launcher/install/usr/bin/spotify ]]; then
    spotify_path="${shareDir}/spotify-launcher/install/usr/share/spotify"
    print_log -sec "Spotify" " Spotify-launcher"
  elif [[ -d /opt/spotify ]]; then
    spotify_path="/opt/spotify"
    print_log -sec "Spotify" " System Package Manager"
  fi

  if [[ -z $spotify_path ]]; then
    warn_msg "No se pudo detectar la ruta de instalación de Spotify."
    return 0
  fi

  # 2. Check/Set permissions
  if [[ ! -w $spotify_path || ! -w $spotify_path/Apps ]]; then
    notify-send -a "HyDE Alert" "Permission needed for Wallbash Spotify theme" || true
    info "Solicitando permisos de escritura para $spotify_path..."
    sudo chmod a+wr "$spotify_path" || true
    sudo chmod a+wr -R "$spotify_path/Apps" || true
  fi

  if { { pkg_installed spotify && pkg_installed spicetify-cli; } || [[ -e $spotify_path ]]; }; then
    print_log -sec "Spotify" -stat "path" " ${spotify_path}"

    step "Configurando Spicetify"

    # Initialize Spicetify config and prefs
    spicetify &>/dev/null || true
    mkdir -p "$HOME/.config/spotify"
    touch "$HOME/.config/spotify/prefs"

    local spotify_conf
    spotify_conf=$(spicetify -c 2>/dev/null) || true
    if [[ -f $spotify_conf ]]; then
      sed -i -e "/^prefs_path/ s+=.*$+= $HOME/.config/spotify/prefs+g" \
        -e "/^spotify_path/ s+=.*$+= $spotify_path+g" \
        -e "/^spotify_launch_flags/ s+=.*$+= --ozone-platform=wayland+g" "$spotify_conf"
    fi

    local spicetify_themes_dir="$HOME/.config/spicetify/Themes"
    mkdir -p "$spicetify_themes_dir"

    # Install Sleek theme if user.css doesn't exist
    if [[ ! -f ${spicetify_themes_dir}/Sleek/user.css ]]; then
      if [[ -f $cloneDir/Source/arcs/Spotify_Sleek.tar.gz ]]; then
        info "Extrayendo tema Sleek desde el archivo comprimido local..."
        tar -xzf "$cloneDir/Source/arcs/Spotify_Sleek.tar.gz" -C "$spicetify_themes_dir"
      else
        info "Descargando tema Sleek..."
        mkdir -p "${cache_dir}/landing"
        curl -L -o "${cache_dir}/landing/Spotify_Sleek.tar.gz" "https://github.com/HyDE-Project/HyDE/raw/master/Source/arcs/Spotify_Sleek.tar.gz"
        tar -xzf "${cache_dir}/landing/Spotify_Sleek.tar.gz" -C "$spicetify_themes_dir"
      fi
    fi

    # Apply configuration
    spicetify backup apply || true
    spicetify config current_theme Sleek || true
    spicetify config color_scheme Wallbash || true
    spicetify config sidebar_config 0 || true
    spicetify restore backup || true
    spicetify backup apply || true

    # If Spotify is running, run watcher
    if pgrep -x spotify >/dev/null; then
      pkill -x spicetify || true
      spicetify -q watch -s &
      disown
    fi

    success "Spotify: Tema Sleek (Wallbash) configurado correctamente."
  else
    warn_msg "Spotify o Spicetify no están instalados en el sistema."
  fi
}
