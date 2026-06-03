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
pacmanCmd=${cloneDir}/Configs/.local/lib/hyde/pm.sh

export cloneDir
export confDir
export cacheDir
export aurList
export shlList

# Verifica si un paquete específico está instalado en el sistema usando pacman.
# Parámetros:
#   $1 : Nombre del paquete a comprobar (PkgIn).
# Retorno:
#   Retorna 0 si el paquete está instalado en el sistema, o 1 en caso contrario.
pkg_installed() {
    local PkgIn=$1

    if pacman -Q "${PkgIn}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Busca cuál de los paquetes de una lista está instalado en el sistema.
# Parámetros:
#   $1    : Nombre de la variable dinámica a la que se le asignará el paquete encontrado.
#   $2... : Lista de nombres de paquetes a verificar.
# Funcionamiento:
#   Itera sobre la lista de paquetes provistos. Si detecta que alguno está instalado (mediante
#   pkg_installed), guarda el nombre del paquete en la variable dinámica especificada en el
#   primer argumento, exporta dicha variable globalmente en el entorno y retorna 0.
#   Si ninguno de los paquetes de la lista está instalado, retorna 1.
chk_list() {
    vrType="$1"
    local inList=("${@:2}")
    for pkg in "${inList[@]}"; do
        if pkg_installed "${pkg}"; then
            printf -v "${vrType}" "%s" "${pkg}"
            # shellcheck disable=SC2163 # dynamic variable
            export "${vrType}" # export the variable // reference of the variable
            return 0
        fi
    done
    # print_log -sec "install" -warn "no package found in the list..." "${inList[@]}"
    return 1
}

pkg_available() {
    local PkgIn=$1

    if ${pacmanCmd} query "${PkgIn}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

aur_available() {
    local PkgIn=$1

    # shellcheck disable=SC2154
    if ${pacmanCmd} info "${PkgIn}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

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

# Temporizador interactivo para lecturas de teclado con cuenta regresiva.
# Parámetros:
#   $1 : Tiempo de espera máximo en segundos (timsec).
#   $2 : Mensaje descriptivo a mostrar en la consola (msg).
# Funcionamiento:
#   Desactiva temporalmente el modo de salida por error (set +e) para evitar que falle el script
#   en caso de timeout. Realiza una cuenta regresiva actualizando la línea actual en consola (\r).
#   Si se pulsa cualquier tecla, detiene la espera inmediatamente. Finalmente exporta la variable
#   PROMPT_INPUT con el carácter ingresado y reestablece el modo seguro (set -e).
prompt_timer() {
    set +e
    unset PROMPT_INPUT
    local timsec=$1
    local msg=$2
    while [[ ${timsec} -ge 0 ]]; do
        echo -ne "\r :: ${msg} (${timsec}s) : "
        read -rt 1 -n 1 PROMPT_INPUT && break
        ((timsec--))
    done
    export PROMPT_INPUT
    echo ""
    set -e
}
print_log() {
    local executable="${0##*/}"
    local logFile="${cacheDir}/logs/${RAVN_LOG}/${executable}.log"
    mkdir -p "$(dirname "${logFile}")"
    local section=${log_section:-}
    {
        [ -n "${section}" ] && echo -ne "\e[32m[$section] \e[0m"
        while (("$#")); do
            case "$1" in
            -r | +r)
                echo -ne "\e[31m$2\e[0m"
                shift 2
                ;; # Red
            -g | +g)
                echo -ne "\e[32m$2\e[0m"
                shift 2
                ;; # Green
            -y | +y)
                echo -ne "\e[33m$2\e[0m"
                shift 2
                ;; # Yellow
            -b | +b)
                echo -ne "\e[34m$2\e[0m"
                shift 2
                ;; # Blue
            -m | +m)
                echo -ne "\e[35m$2\e[0m"
                shift 2
                ;; # Magenta
            -c | +c)
                echo -ne "\e[36m$2\e[0m"
                shift 2
                ;; # Cyan
            -wt | +w)
                echo -ne "\e[37m$2\e[0m"
                shift 2
                ;; # White
            -n | +n)
                echo -ne "\e[96m$2\e[0m"
                shift 2
                ;; # Neon
            -stat)
                echo -ne "\e[30;46m $2 \e[0m :: "
                shift 2
                ;; # status
            -crit)
                echo -ne "\e[97;41m $2 \e[0m :: "
                shift 2
                ;; # critical
            -warn)
                echo -ne "WARNING :: \e[30;43m $2 \e[0m :: "
                shift 2
                ;; # warning
            +)
                echo -ne "\e[38;5;$2m$3\e[0m"
                shift 3
                ;; # Set color manually
            -sec)
                echo -ne "\e[32m[$2] \e[0m"
                shift 2
                ;; # section use for logs
            -err)
                echo -ne "ERROR :: \e[4;31m$2 \e[0m"
                shift 2
                ;; #error
            *)
                echo -ne "$1"
                shift
                ;;
            esac
        done
        echo ""
    } | if [ -n "${RAVN_LOG}" ]; then
        tee >(sed 's/\x1b\[[0-9;]*m//g' >>"${logFile}")
    else
        cat
    fi
}
