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

DOTBARE_DIR="${DOTBARE_DIR:-$HOME/.cfg}"
CfgDir="${cloneDir}/Configs"

SILENT=0
if [ "${1}" == "--silent" ]; then
    SILENT=1
fi

if [ ! -d "${DOTBARE_DIR}" ]; then
    [ ${SILENT} -ne 1 ] && print_log -err "El repositorio dotbare no existe en ${DOTBARE_DIR}. Inicialízalo primero."
    exit 1
fi

[ ${SILENT} -ne 1 ] && print_log -g "[sync-back]" -b " :: " "Sincronizando cambios de dotfiles desde \$HOME a ${CfgDir}..."

# Obtener todos los archivos rastreados en el repositorio bare
git --git-dir="${DOTBARE_DIR}" ls-files | while read -r rel_path; do
    if [ -n "${rel_path}" ]; then
        active_file="${HOME}/${rel_path}"
        repo_file="${CfgDir}/${rel_path}"

        if [ -f "${active_file}" ]; then
            if [ ! -e "${repo_file}" ]; then
                # El archivo no existe en el repositorio template (por ejemplo, nueva configuración agregada)
                [ ${SILENT} -ne 1 ] && print_log -y "[nuevo]" -b " :: " "${rel_path} --> Configs/"
                mkdir -p "$(dirname "${repo_file}")"
                cp "${active_file}" "${repo_file}"
            else
                # Ambos existen, comparar contenido
                if ! diff -q "${repo_file}" "${active_file}" &>/dev/null; then
                    [ ${SILENT} -ne 1 ] && print_log -y "[actualizado]" -b " :: " "${rel_path} --> Configs/"
                    cp -f "${active_file}" "${repo_file}"
                fi
            fi
        fi
    fi
done

[ ${SILENT} -ne 1 ] && print_log -g "[sync-back]" -b " :: " "Sincronización completada con éxito."
