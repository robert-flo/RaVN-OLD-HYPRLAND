#!/usr/bin/env bash
#|---/ /+-------------------------------------------+---/ /|#
#|--/ /-| Script to install aur helper, yay or paru |--/ /-|#
#|-/ /--| Roberto Flores                            |-/ /--|#
#|/ /---+-------------------------------------------+/ /---|#

# Establece el directorio de trabajo del script e importa variables y funciones globales
# desde global_fn.sh. Si no se puede cargar el archivo, el script termina con error.
scrDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# Comprobación preliminar de asistentes AUR en el sistema:
# Si chk_list detecta que yay o paru (o cualquier helper de la lista) ya se encuentra instalado,
# se notifica su detección en consola y se detiene la ejecución del script con éxito (exit 0).
# shellcheck disable=SC2154
if chk_list "aurhlpr" "${aurList[@]}"; then
    print_log -sec "AUR" -stat "Detected" "${aurhlpr}"
    exit 0
fi

# Preparación del entorno y carpetas temporales para clonar el código fuente:
# 1. Define el asistente de AUR a instalar (tomando el primer argumento posicional, o yay-bin por defecto).
# 2. Comprueba la existencia del directorio ~/Clone en el home del usuario:
#    - Si existe, elimina cualquier residuo de clonados previos del mismo asistente.
#    - Si no existe, crea la carpeta ~/Clone y asigna un archivo de configuración de icono (.directory).
aurhlpr="${1:-yay-bin}"

if [ -d "$HOME/Clone" ]; then
    print_log -sec "AUR" -stat "exist" "$HOME/Clone directory..."
    rm -rf "$HOME/Clone/${aurhlpr}"
else
    mkdir "$HOME/Clone"
    echo -e "[Desktop Entry]\nIcon=default-folder-git" >"$HOME/Clone/.directory"
    print_log -sec "AUR" -stat "created" "$HOME/Clone directory..."
fi

# Clonado del repositorio desde el AUR oficial:
# Requiere 'git' instalado en el sistema. En caso de no estar presente, termina con error.
if pkg_installed git; then
    git clone "https://aur.archlinux.org/${aurhlpr}.git" "$HOME/Clone/${aurhlpr}"
else
    print_log -sec "AUR" -stat "missing" "'git' as dependency..."
    exit 1
fi

# Compilación e instalación del asistente de AUR:
# Accede a la carpeta clonada y ejecuta makepkg con opciones de instalación de dependencias (-si).
# Retorna éxito si la instalación se realiza correctamente, o falla y notifica el error en caso contrario.
cd "$HOME/Clone/${aurhlpr}" || exit
# shellcheck disable=SC2154
if makepkg "${use_default}" -si; then
    print_log -sec "AUR" -stat "installed" "${aurhlpr} aur helper..."
    exit 0
else
    print_log -r "AUR" -stat "failed" "${aurhlpr} installation failed..."
    echo "${aurhlpr} installation failed..."
    exit 1
fi
