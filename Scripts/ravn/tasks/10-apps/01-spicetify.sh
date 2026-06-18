#!/usr/bin/env bash
# ─── RaVN Task: Spicetify (Sleek Theme) ─────────────────────────────────────
# Extracted from install_fnl.sh::setup_spicetify()
# Configures Sleek (Catppuccin) theme + adblock extension for Spotify.
# Optimized for offline execution, dry-run safety, and auto-recovery.

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

  # Skip if the theme and backup exist AND the config file is valid (not empty)
  local config_file="$HOME/.config/spicetify/config-xpui.ini"
  if [[ -d $HOME/.config/spicetify/Themes/Sleek ]] \
    && [[ -d $HOME/.config/spicetify/Backup ]] \
    && [[ -f $config_file && -s $config_file ]]; then
    return 0
  fi

  return 1
}

install() {
  if (( flg_DryRun == 1 )); then
    info "Simulación: Saltando configuración de Spicetify."
    return 0
  fi

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

  # Crear directorios de configuración de Spicetify si no existen
  mkdir -p "$HOME/.config/spicetify/Themes"
  mkdir -p "$HOME/.config/spicetify/Extensions"

  # Recuperar config-xpui.ini corrupto o vacío si aplica
  local config_file="$HOME/.config/spicetify/config-xpui.ini"
  if [[ ! -f $config_file || ! -s $config_file ]]; then
    info "Inicializando archivo de configuración de Spicetify..."
    rm -f "$config_file"
    spicetify config &>/dev/null || true
  fi

  # Desactivar las búsquedas de actualizaciones automáticas para evitar timeouts de red
  info "Desactivando búsqueda de actualizaciones en Spicetify..."
  spicetify config check_spicetify_upgrade 0 &>/dev/null || true

  # Configurar rutas locales básicas
  spicetify config spotify_path "/opt/spotify" prefs_path "$HOME/.config/spotify/prefs" &>/dev/null || true

  # Asegurar la existencia de los temas (fallback a local si falta)
  if [[ ! -d $HOME/.config/spicetify/Themes/Sleek ]]; then
    if [[ -f $cloneDir/Source/arcs/Spotify_Sleek.tar.gz ]]; then
      info "Extrayendo tema Sleek desde el archivo comprimido local..."
      tar -xzf "$cloneDir/Source/arcs/Spotify_Sleek.tar.gz" -C "$HOME/.config/spicetify/Themes/"
    else
      warn_msg "No se encontró el archivo del tema Sleek en la fuente."
    fi
  fi

  # Asegurar la existencia de la extensión adblock (fallback a red con reintentos)
  if [[ ! -f $HOME/.config/spicetify/Extensions/adblock.js ]]; then
    info "Descargando extensión adblock..."
    retry 3 download_file "https://raw.githubusercontent.com/rxri/spicetify-extensions/main/adblock/adblock.js" "$HOME/.config/spicetify/Extensions/adblock.js" || true
  fi

  # Aplicar tema y extensiones si el directorio Sleek es correcto
  if [[ -d $HOME/.config/spicetify/Themes/Sleek ]]; then
    # Inicializar backup de Spicetify si no existe
    if [[ ! -d $HOME/.config/spicetify/Backup ]]; then
      info "Creando copia de respaldo de Spotify..."
      spicetify backup &>/dev/null || true
    fi

    # Configurar parámetros del tema
    spicetify config current_theme Sleek &>/dev/null || true
    spicetify config color_scheme Catppuccin &>/dev/null || true
    spicetify config extensions adblock.js &>/dev/null || true

    # Aplicar la configuración con auto-recuperación en caso de desajuste de versión/backup
    info "Aplicando personalización a Spotify..."
    if ! spicetify apply; then
      warn_msg "spicetify apply falló. Intentando restaurar y regenerar backup..."
      spicetify restore &>/dev/null || true
      spicetify backup &>/dev/null || true
      if ! spicetify apply; then
        error_msg "No se pudo aplicar la personalización de Spicetify tras el intento de recuperación."
        return 1
      fi
    fi

    success "Spotify: Tema Sleek (Catppuccin) y adblock configurados correctamente."
  else
    error_msg "No se pudo aplicar el tema Sleek porque el directorio del tema no existe."
    return 1
  fi
}
