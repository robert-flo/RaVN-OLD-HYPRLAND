#!/usr/bin/env bash
#|---/ /+-------------------------------------------+---/ /|#
#|--/ /-| Script para configurar mis aplicaciones   |--/ /-|#
#|-/ /--| Roberto Flores                            |-/ /--|#
#|/ /---+-------------------------------------------+/ /---|#

# ==============================================================================
# Inicialización de rutas e importación de funciones globales de RaVN
# ==============================================================================
scrDir=$(dirname "$(dirname "$(realpath "$0")")")
source "${scrDir}/global_fn.sh"
if [ $? -ne 0 ]; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

cloneDir=$(dirname "$(realpath "$cloneDir")")

# ==============================================================================
# Limpieza de lanzadores y configuración de iconos del sistema (Requiere sudo)
# ==============================================================================
# Elimina los accesos directos redundantes de Rofi y cambia los iconos de nwg-look y swappy
# para mejorar la estética visual en el lanzador de aplicaciones.
if [ -f /usr/share/applications/rofi-theme-selector.desktop ] && [ -f /usr/share/applications/rofi.desktop ]; then
    sudo rm /usr/share/applications/rofi-theme-selector.desktop
    sudo rm /usr/share/applications/rofi.desktop
fi
if [ -f /usr/share/applications/nwg-look.desktop ]; then
    sudo sed -i "/^Icon=/c\Icon=adjust-colors" /usr/share/applications/nwg-look.desktop
fi

if [ -f /usr/share/applications/swappy.desktop ]; then
    sudo sed -i "/^Icon=/c\Icon=spectacle" /usr/share/applications/swappy.desktop
fi

# ==============================================================================
# Configuración y aprovisionamiento del perfil de Firefox
# ==============================================================================
# Si Firefox está instalado:
# 1. Localiza el perfil default-release del usuario (o lo inicializa si no existe).
# 2. Respalda el perfil anterior en ~/.config/cfg_backups.
# 3. Descomprime las configuraciones de usuario y las extensiones en el perfil.
# 4. Registra e instala las extensiones en segundo plano usando el ejecutable de Firefox.
if pkg_installed firefox; then
    mkdir -p ~/.mozilla/firefox
    FoxRel=$(find ~/.mozilla/firefox -maxdepth 1 -type d -name "*.default-release" 2>/dev/null | head -1)

    if [ -z "${FoxRel}" ]; then
        firefox &> /dev/null &
        sleep 2
        FoxRel=$(find ~/.mozilla/firefox -maxdepth 1 -type d -name "*.default-release" 2>/dev/null | head -1)
    else
        BkpDir="${HOME}/.config/cfg_backups/$(date +'%y%m%d_%Hh%Mm%Ss')_apps"
        mkdir -p "${BkpDir}"
        cp -r ~/.mozilla/firefox "${BkpDir}"
    fi

    if [ -n "${FoxRel}" ]; then
        tar -xzf "${cloneDir}/Source/arcs/Firefox_UserConfig.tar.gz" -C "${FoxRel}"
        tar -xzf "${cloneDir}/Source/arcs/Firefox_Extensions.tar.gz" -C ~/.mozilla/

        find ~/.mozilla/extensions -maxdepth 1 -type f -name "*.xpi" 2>/dev/null | while read -r fext; do
            firefox -profile "${FoxRel}" "${fext}" &> /dev/null &
        done
    else
        print_log -warn "Firefox profile (*.default-release) not found. Skipping Firefox user config."
    fi
fi
