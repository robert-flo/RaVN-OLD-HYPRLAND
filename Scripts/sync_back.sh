#!/usr/bin/env bash
# shellcheck disable=SC1091
#|---/ /+--------------------------------------------+---/ /|#
#|--/ /-| Script to sync dotfiles from HOME to repo  |--/ /-|#
#||-/ /--| Roberto Flores                             |-/ /--|#
#|/ /---+--------------------------------------------+/ /---|#

scrDir=$(dirname "$(realpath "$0")")
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

CfgLst="${scrDir}/restore_cfg.psv"
CfgDir="${cloneDir}/Configs"

SILENT=0
if [ "${1}" == "--silent" ]; then
    SILENT=1
fi

if [ ! -f "${CfgLst}" ] || [ ! -d "${CfgDir}" ]; then
    [ ${SILENT} -ne 1 ] && echo "ERROR: '${CfgLst}' or '${CfgDir}' does not exist..."
    exit 1
fi

[ ${SILENT} -ne 1 ] && print_log -g "[sync-back]" -b " :: " "Sincronizando cambios de dotfiles desde \$HOME a ${CfgDir}..."

while read -r line || [ -n "$line" ]; do
    # Omitir líneas incorrectas o comentarios
    if [ "$(awk -F '|' '{print NF}' <<<"${line}")" -ne 4 ]; then
        continue
    fi
    if [[ "${line}" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    flag=$(awk -F '|' '{print $1}' <<<"${line}")
    pth=$(awk -F '|' '{print $2}' <<<"${line}")
    pth_resolved=$(eval "echo ${pth}")
    cfg=$(awk -F '|' '{print $3}' <<<"${line}")

    if [ "${flag}" = "P" ]; then
        echo "${cfg}" | xargs -n 1 | while read -r cfg_chk; do
            if [ -n "${cfg_chk}" ]; then
                active_file="${pth_resolved}/${cfg_chk}"
                # Obtener la ruta relativa respecto a $HOME
                rel_path="${active_file#${HOME}/}"
                repo_file="${CfgDir}/${rel_path}"

                if [ -e "${active_file}" ]; then
                    if [ ! -e "${repo_file}" ]; then
                        # El archivo no existe en el repositorio (por ejemplo, nueva configuración agregada en psv)
                        [ ${SILENT} -ne 1 ] && print_log -y "[nuevo]" -b " :: " "${rel_path} --> Configs/"
                        mkdir -p "$(dirname "${repo_file}")"
                        cp -r "${active_file}" "${repo_file}"
                    else
                        # Ambos existen, comparar contenido
                        if [ -d "${active_file}" ]; then
                            # Si es un directorio, usar rsync si hay diferencias
                            if ! diff -r -q "${repo_file}" "${active_file}" &>/dev/null; then
                                [ ${SILENT} -ne 1 ] && print_log -y "[sincronizando dir]" -b " :: " "${rel_path} --> Configs/"
                                rsync -a --delete "${active_file}/" "${repo_file}/"
                            fi
                        else
                            # Si es un archivo
                            if ! diff -q "${repo_file}" "${active_file}" &>/dev/null; then
                                [ ${SILENT} -ne 1 ] && print_log -y "[actualizado]" -b " :: " "${rel_path} --> Configs/"
                                cp -f "${active_file}" "${repo_file}"
                            fi
                        fi
                    fi
                fi
            fi
        done
    fi
done < "${CfgLst}"

[ ${SILENT} -ne 1 ] && print_log -g "[sync-back]" -b " :: " "Sincronización completada con éxito."
