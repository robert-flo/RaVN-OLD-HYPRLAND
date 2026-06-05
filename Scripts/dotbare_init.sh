#!/usr/bin/env bash
# shellcheck disable=SC1091
#|---/ /+--------------------------------------------+---/ /|#
#|--/ /-| Script to initialize dotbare tracking      |--/ /-|#
#||-/ /--| Roberto Flores                             |-/ /--|#
#|/ /---+--------------------------------------------+/ /---|#

scrDir=$(dirname "$(realpath "$0")")
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

DOTBARE_DIR="${DOTBARE_DIR:-$HOME/.cfg}"
DOTBARE_TREE="${DOTBARE_TREE:-$HOME}"
CfgLst="${scrDir}/restore_cfg.psv"

if [ ! -f "${CfgLst}" ]; then
    print_log -err "restore_cfg.psv not found at ${CfgLst}."
    exit 1
fi

# Inicializar el repositorio bare si no existe
if [ ! -d "${DOTBARE_DIR}" ]; then
    print_log -g "[dotbare]" -b " :: " "Inicializando repositorio bare en ${DOTBARE_DIR}..."
    git init --bare "${DOTBARE_DIR}"
else
    print_log -g "[dotbare]" -b " :: " "Repositorio bare ya existe en ${DOTBARE_DIR}."
fi

# Configurar el repositorio bare para trabajar con $HOME
print_log -g "[dotbare]" -b " :: " "Configurando work-tree y ocultando archivos no rastreados..."
git --git-dir="${DOTBARE_DIR}" --work-tree="${DOTBARE_TREE}" config --local status.showUntrackedFiles no
git --git-dir="${DOTBARE_DIR}" --work-tree="${DOTBARE_TREE}" config --local core.worktree "${DOTBARE_TREE}"

# Registrar los archivos con bandera P
print_log -g "[dotbare]" -b " :: " "Registrando archivos personales (bandera P)..."
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
                if [ -e "${active_file}" ]; then
                    # Obtener la ruta relativa respecto a $HOME (DOTBARE_TREE)
                    rel_path="${active_file#${DOTBARE_TREE}/}"
                    repo_file="${scrDir}/../Configs/${rel_path}"

                    if [ -d "${repo_file}" ]; then
                        # Si es un directorio en el repo template, agregar solo los archivos que existen en el repo
                        find "${repo_file}" -type f | while read -r repo_f; do
                            rel_f="${repo_f#*/Configs/}"
                            act_f="${DOTBARE_TREE}/${rel_f}"
                            if [ -f "${act_f}" ]; then
                                if git --git-dir="${DOTBARE_DIR}" --work-tree="${DOTBARE_TREE}" add "${act_f}" 2>/dev/null; then
                                    print_log -g "[track]" -b " :: " "${rel_f}"
                                fi
                            fi
                        done
                    else
                        # Si es un archivo individual
                        if git --git-dir="${DOTBARE_DIR}" --work-tree="${DOTBARE_TREE}" add "${active_file}" 2>/dev/null; then
                            print_log -g "[track]" -b " :: " "${rel_path}"
                        else
                            print_log -err "No se pudo registrar: ${rel_path}"
                        fi
                    fi
                fi
            fi
        done
    fi
done < "${CfgLst}"

print_log -g "[dotbare]" -b " :: " "Rastreo selectivo configurado con éxito."
