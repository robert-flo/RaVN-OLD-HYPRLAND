#!/usr/bin/env bash
#|---/ /+-----------------------------------+---/ /|#
#|--/ /-| Script para instalar flatpaks     |--/ /-|#
#|-/ /--| Roberto Flores                    |-/ /--|#
#|/ /---+-----------------------------------+/ /---|#

# ==============================================================================
# Inicialización de rutas e importación de funciones globales de RaVN
# ==============================================================================
baseDir=$(dirname "$(realpath "$0")")
scrDir=$(dirname "$(dirname "$(realpath "$0")")")

source "${scrDir}/global_fn.sh"
if [ $? -ne 0 ]; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# ==============================================================================
# Instalación del comando flatpak si no está presente en el sistema
# ==============================================================================
if ! pkg_installed flatpak; then
    sudo pacman -S flatpak
fi

# ==============================================================================
# Adición de repositorio remoto flathub e instalación de aplicaciones enlistadas
# ==============================================================================
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flats=$(awk -F '#' '{print $1}' "${baseDir}/custom_flat.lst" | sed 's/ //g' | xargs)

flatpak install --user -y flathub ${flats}
flatpak remove --unused

# ==============================================================================
# Configuración de permisos de archivos y variables para aplicar temas GTK e iconos
# ==============================================================================
gtkTheme=$(gsettings get org.gnome.desktop.interface gtk-theme | sed "s/'//g")
gtkIcon=$(gsettings get org.gnome.desktop.interface icon-theme | sed "s/'//g")

flatpak --user override --filesystem=~/.themes
flatpak --user override --filesystem=~/.icons

flatpak --user override --filesystem=~/.local/share/themes
flatpak --user override --filesystem=~/.local/share/icons

flatpak --user override --env=GTK_THEME=${gtkTheme}
flatpak --user override --env=ICON_THEME=${gtkIcon}
