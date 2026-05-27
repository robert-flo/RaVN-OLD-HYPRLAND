#!/usr/bin/env bash
#|---/ /+-------------------------------------------+---/ /|#
#|--/ /-| Script para reparar enlaces simbólicos    |--/ /-|#
#|-/ /--| Roberto Flores                            |-/ /--|#
#|/ /---+-------------------------------------------+/ /---|#

# ==============================================================================
# Inicialización e importación de funciones globales de RaVN
# ==============================================================================
export scrDir=$(dirname "$(realpath "$0")")
source "${scrDir}/global_fn.sh"
if [ $? -ne 0 ]; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# ==============================================================================
# Resolución y recreación de los enlaces simbólicos en el directorio HOME
# ==============================================================================
# Busca todos los enlaces simbólicos dentro del directorio clonado. Para cada uno,
# calcula el destino relativo y vuelve a crear el enlace simbólico apuntando a
# la ruta correcta en el HOME del usuario actual.
find "${cloneDir}" -type l | while read -r slink; do
    fixd_slink=$(readlink "$slink" | cut -d '/' -f 4-)
    linkd_file=$(echo "$slink" | awk -F "${cloneDir}/Configs/" '{print $NF}')
    echo -e "\033[0;32m[link]\033[0m $HOME/$linkd_file --> $HOME/$fixd_slink..."
    ln -fs "$HOME/${fixd_slink}" "$HOME/${linkd_file}"
done

# ==============================================================================
# Recarga de la configuración de Hyprland si el compositor está activo
# ==============================================================================
if printenv HYPRLAND_INSTANCE_SIGNATURE &> /dev/null; then
    echo "reloading hyprland..."
    hyprctl reload
fi
