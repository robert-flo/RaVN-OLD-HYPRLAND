#!/usr/bin/env bash
#|---/ /+------------------+---/ /|#
#|--/ /-| Global functions |--/ /-|#
#|-/ /--| Roberto Flores   |-/ /--|#
#|/ /---+------------------+/ /---|#

set -e

scrDir="$(dirname "$(realpath "$0")")"
cloneDir="$(dirname "${scrDir}")" # fallback, we will use CLONE_DIR now
cloneDir="${CLONE_DIR:-${cloneDir}}"
confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/ravn"
aurList=("yay" "paru")
shlList=("zsh" "fish")
pacmanCmd=${cloneDir}/Configs/.local/lib/ravn/pm.sh

export cloneDir
export confDir
export cacheDir
export aurList
export shlList


# Detecta adaptadores de gráficos (GPU) de Nvidia en el sistema.
# Opciones:
#   --verbose : Imprime en consola todas las GPUs detectadas con su índice.
#   --drivers : Mapea los códigos de GPU detectados contra la base de datos nvidia-db
#               para sugerir/imprimir los controladores Nvidia correspondientes.
#   Sin opción: Retorna 0 (éxito) si se detecta alguna GPU Nvidia, o 1 en caso contrario.
nvidia_detect() {
    readarray -t dGPU < <(lspci -k | grep -E "(VGA|3D)" | awk -F ': ' '{print $NF}')
    if [ "${1}" == "--verbose" ]; then
        for indx in "${!dGPU[@]}"; do
            echo -e "\033[0;32m[gpu$indx]\033[0m detected :: ${dGPU[indx]}"
        done
        return 0
    fi
    if [ "${1}" == "--drivers" ]; then
        while read -r -d ' ' nvcode; do
            awk -F '|' -v nvc="${nvcode}" 'substr(nvc,1,length($3)) == $3 {split(FILENAME,driver,"/"); print driver[length(driver)],"\nnvidia-utils"}' "${scrDir}"/nvidia-db/nvidia*dkms
        done <<<"${dGPU[@]}"
        return 0
    fi
    if grep -iq nvidia <<<"${dGPU[@]}"; then
        return 0
    else
        return 1
    fi
}
