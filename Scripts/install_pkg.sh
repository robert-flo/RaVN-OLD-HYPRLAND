#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1091
#|---/ /+----------------------------------------+---/ /|#
#|--/ /-| Script to install pkgs from input list |--/ /-|#
#|-/ /--| Roberto Flores                        |-/ /--|#
#|/ /---+----------------------------------------+/ /---|#

# Establece el directorio de trabajo del script e importa variables y funciones globales
# desde global_fn.sh. Si no se puede cargar el archivo, el script termina con error.
scrDir=$(dirname "$(realpath "$0")")
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# Configuración inicial del entorno de logs y modo prueba:
# 1. Inicializa flg_DryRun en 0 si no está declarada.
# 2. Define la sección de bitácora para logs como "package".
# 3. Invoca la instalación del asistente de AUR (install_aur.sh) usando la variable getAur.
# 4. Verifica el helper de AUR instalado para guardarlo en la variable aurhlpr.
# 5. Define el archivo origen de la lista de paquetes (por defecto install_pkg.lst si no se pasa como parámetro).
flg_DryRun=${flg_DryRun:-0}
export log_section="package"

"${scrDir}/install_aur.sh" "${getAur}" 2>&1
chk_list "aurhlpr" "${aurList[@]}"
listPkg="${1:-"${scrDir}/install_pkg.lst"}"
archPkg=()
aurhPkg=()
ofs=$IFS
IFS='|'

#-----------------------------#
# remove blacklisted packages #
#-----------------------------#
# Si existe el archivo pkg_black.lst, se remueven de la lista final de instalación
# todos los paquetes listados en él para evitar instalar paquetes conflictivos o no deseados.
if [ -f "${scrDir}/pkg_black.lst" ]; then
    grep -v -f <(grep -v '^#' "${scrDir}/pkg_black.lst" | sed 's/#.*//;s/ //g;/^$/d') <(sed 's/#.*//' "${scrDir}/install_pkg.lst") >"${scrDir}/install_pkg_filtered.lst"
    mv "${scrDir}/install_pkg_filtered.lst" "${scrDir}/install_pkg.lst"
fi

# Bucle principal para leer y clasificar cada paquete contenido en la lista origen (listPkg):
# 1. Limpia espacios del nombre de paquete y omite líneas vacías.
# 2. Si el paquete tiene dependencias listadas, verifica que estas ya se encuentren instaladas
#    o presentes en la misma lista. Si falta alguna dependencia obligatoria, omite el paquete.
# 3. Clasifica el paquete:
#    - Si ya está instalado, se registra como skip.
#    - Si está disponible en los repositorios de Arch, se añade al arreglo archPkg.
#    - Si está disponible en el AUR, se añade al arreglo aurhPkg.
#    - Si no se encuentra en ningún lado, se marca un error de paquete desconocido.
while read -r pkg deps; do
    pkg="${pkg// /}"
    if [ -z "${pkg}" ]; then
        continue
    fi

    if [ -n "${deps}" ]; then
        deps="${deps%"${deps##*[![:space:]]}"}"
        while read -r cdep; do
            pass=$(cut -d '#' -f 1 "${listPkg}" | awk -F '|' -v chk="${cdep}" '{if($1 == chk) {print 1;exit}}')
            if [ -z "${pass}" ]; then
                if pkg_installed "${cdep}"; then
                    pass=1
                else
                    break
                fi
            fi
        done < <(xargs -n1 <<<"${deps}")

        if [[ ${pass} -ne 1 ]]; then
            print_log -warn "missing" "dependency [ ${deps} ] for ${pkg}..."
            continue
        fi
    fi

    if pkg_installed "${pkg}"; then
        print_log -y "[skip] " "${pkg}"
    elif pkg_available "${pkg}"; then
        repo=$(pacman -Si "${pkg}" | awk -F ': ' '/Repository / {print $2}' | tr '\n' ' ')
        print_log -b "[queue] " "${pkg}" -b " :: " -g "${repo}"
        archPkg+=("${pkg}")
    elif aur_available "${pkg}"; then
        print_log -b "[queue] " "${pkg}" -b " :: " -g "aur"
        aurhPkg+=("${pkg}")
    else
        print_log -r "[error] " "unknown package ${pkg}..."
    fi
done < <(cut -d '#' -f 1 "${listPkg}")

IFS=${ofs}

# Procesa e instala los paquetes de un arreglo provisto (pacman o asistente AUR):
# - Si flg_DryRun=1, simula la instalación imprimiendo los nombres de los paquetes en cola.
# - Si flg_DryRun=0, ejecuta el comando de instalación correspondiente (-S) pasando confirmaciones.
install_packages() {
    local -n pkg_array=$1
    local pkg_type=$2
    local install_cmd=$3

    if [[ ${#pkg_array[@]} -gt 0 ]]; then
        print_log -b "[install] " "$pkg_type packages..."
        if [ "${flg_DryRun}" -eq 1 ]; then
            for pkg in "${pkg_array[@]}"; do
                print_log -b "[pkg] " "${pkg}"
            done
        else
            $install_cmd ${use_default:+"$use_default"} -S "${pkg_array[@]}"
        fi
    fi
}

# Ejecuta las subrutinas de instalación para paquetes oficiales de Arch y paquetes de AUR.
echo ""
install_packages archPkg "arch" "sudo pacman"
echo ""
install_packages aurhPkg "aur" "${aurhlpr}"
