#!/usr/bin/env bash
#|---/ /+-------------------------------------+---/ /|#
#|--/ /-| Script to diff config files         |--/ /-|#
#|-/ /--| Roberto Flores                     |-/ /--|#
#|/ /---+-------------------------------------+/ /---|#

# Establece el directorio de trabajo del script e importa variables y funciones globales
# desde global_fn.sh. Si no se puede cargar el archivo, el script termina con error.
scrDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# Resolución de la lista de restauración a utilizar (lst, psv, json).
# Toma como prioridad las configuraciones personalizadas del usuario si existen.
[ -f "${scrDir}/restore_cfg.lst" ] && defaultLst="restore_cfg.lst"
[ -f "${scrDir}/restore_cfg.psv" ] && defaultLst="restore_cfg.psv"
[ -f "${scrDir}/restore_cfg.json" ] && defaultLst="restore_cfg.json"
[ -f "${scrDir}/${USER}-restore_cfg.psv" ] && defaultLst="$USER-restore_cfg.psv"

CfgLst="${1:-"${scrDir}/${defaultLst}"}"
CfgDir="${2:-${cloneDir}/Configs}"

# Validación de existencia de la lista de restauración y la carpeta origen de plantillas.
if [ ! -f "${CfgLst}" ] || [ ! -d "${CfgDir}" ]; then
	echo "ERROR: '${CfgLst}' or '${CfgDir}' does not exist..."
	exit 1
fi

print_log -g "[diff]" -b " :: " "Comparando archivos locales contra plantillas en: ${CfgLst}"
echo ""

# Bucle principal de lectura y comparación de archivos:
# 1. Omite líneas de comentarios, vacías y decorativas.
# 2. Resuelve la ruta destino en el sistema (evaluando variables como $HOME).
# 3. Mapea la ruta al directorio correspondiente de plantillas en el repositorio.
# 4. Si el archivo local y la plantilla existen, realiza una comparación silenciosa (diff -q).
# 5. Si hay diferencias, imprime la ruta del archivo y provee el comando git diff listo para ejecutar.
while read -r lst || [ -n "$lst" ]; do
    # Omitir líneas incorrectas o comentarios
    if [ "$(awk -F '|' '{print NF}' <<<"${lst}")" -ne 4 ] && [ "$(awk -F '|' '{print NF}' <<<"${lst}")" -ne 5 ]; then
        continue
    fi
    if [[ "${lst}" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    flag=$(awk -F '|' '{print $1}' <<<"${lst}")
    path=$(awk -F '|' '{print $2}' <<<"${lst}")
    # Resolver variables de entorno en la ruta
    path_resolved=$(eval "echo ${path}")
    cfg=$(awk -F '|' '{print $3}' <<<"${lst}")

    # Procesa cada archivo/carpeta dentro de la configuración
    echo "${cfg}" | xargs -n 1 | while read -r cfg_chk; do
        if [[ -z "${path_resolved}" ]]; then continue; fi

        active_file="${path_resolved}/${cfg_chk}"
        relative_path="${path_resolved#$HOME/}"
        template_file="${CfgDir}/${relative_path}/${cfg_chk}"

        # Compara el archivo si existe tanto localmente como en el repositorio
        if [[ -f "${active_file}" && -f "${template_file}" ]]; then
            if ! diff -q "${template_file}" "${active_file}" >/dev/null; then
                print_log -y "[DIFERENTE] " -b " :: " "${relative_path}/${cfg_chk}"
                echo "  Ver cambios: git diff --no-index \"${template_file}\" \"${active_file}\""
                echo ""
            fi
        fi
    done
done < "${CfgLst}"
