#!/usr/bin/env bash
# ─── RaVN Task: Spicetify (Sleek Theme) ─────────────────────────────────────
# Extracted from install_fnl.sh::setup_spicetify()
# Configures Sleek (Catppuccin) theme + adblock extension for Spotify.

PACKAGE="spicetify"
DESCRIPTION="Spotify Sleek theme (Catppuccin) + adblock via Spicetify"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  # Skip if neither Spotify nor Spicetify are installed
  if ! pkg_installed spotify || ! pkg_installed spicetify-cli; then
    # Not a failure — just not applicable
    return 0
  fi
  # Skip if the theme is already applied
  if [[ -d "$HOME/.config/spicetify/Themes/Sleek" ]] \
    && [[ -d "$HOME/.config/spicetify/Backup" ]]; then
    return 0
  fi
  return 1
}

install() {
  step "Configurando tema Sleek para Spotify"

  # Asegurar permisos de escritura en la carpeta de Spotify
  if [[ -d /opt/spotify ]]; then
    if [[ ! -w /opt/spotify || ! -w /opt/spotify/Apps ]]; then
      info "Solicitando permisos de escritura para /opt/spotify..."
      sudo chmod a+wr /opt/spotify
      sudo chmod a+wr /opt/spotify/Apps -R
    fi
  fi

  # Crear archivo dummy de preferencias si no existe
  mkdir -p "$HOME/.config/spotify"
  if [[ ! -f $HOME/.config/spotify/prefs ]]; then
    touch "$HOME/.config/spotify/prefs"
  fi

  # Configurar rutas en spicetify y crear directorio de temas y extensiones
  mkdir -p "$HOME/.config/spicetify/Themes"
  mkdir -p "$HOME/.config/spicetify/Extensions"
  spicetify config spotify_path "/opt/spotify" prefs_path "$HOME/.config/spotify/prefs" &>/dev/null || true

  # Asegurar la existencia de los temas y extensiones
  # (Si no se restauraron por alguna razón, los creamos o descargamos como fallback)
  if [[ ! -d $HOME/.config/spicetify/Themes/Sleek ]]; then
    if [[ -f $cloneDir/Source/arcs/Spotify_Sleek.tar.gz ]]; then
      info "Extrayendo tema Sleek desde el archivo comprimido (fallback)..."
      tar -xzf "$cloneDir/Source/arcs/Spotify_Sleek.tar.gz" -C "$HOME/.config/spicetify/Themes/"
    else
      warn_msg "No se encontró el tema Sleek en ~/.config/spicetify/Themes/Sleek."
    fi
  fi

  if [[ ! -f $HOME/.config/spicetify/Extensions/adblock.js ]]; then
    info "Descargando extensión adblock (fallback)..."
    retry 3 download_file "https://raw.githubusercontent.com/rxri/spicetify-extensions/main/adblock/adblock.js" "$HOME/.config/spicetify/Extensions/adblock.js" || true
  fi

  # Aplicar spicetify si el tema existe
  if [[ -d $HOME/.config/spicetify/Themes/Sleek ]]; then
    # Inicializar backup de Spicetify (comando actualizado para v2.x)
    if [[ ! -d $HOME/.config/spicetify/Backup ]]; then
      spicetify backup
    fi
    spicetify config current_theme Sleek &>/dev/null || true
    spicetify config color_scheme Catppuccin &>/dev/null || true
    spicetify config extensions adblock.js &>/dev/null || true
    spicetify apply
    success "Spotify: Tema Sleek (Catppuccin) y adblock configurados correctamente."
  else
    error_msg "No se pudo aplicar el tema Sleek porque el directorio del tema no existe."
    return 1
  fi
}
