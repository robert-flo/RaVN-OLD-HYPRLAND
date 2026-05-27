#!/usr/bin/env bash
# shellcheck disable=SC2154
#|---/ /+------------------------------------+---/ /|#
#|--/ /-| Script to extract fonts and themes |--/ /-|#
#|-/ /--| Roberto Flores                     |-/ /--|#
#|/ /---+------------------------------------+/ /---|#

# Configuración inicial del entorno y carga de scripts auxiliares:
# 1. Define flg_DryRun por defecto en 0.
# 2. Configura la sección de logs como "extract".
# 3. Importa las variables y funciones globales de global_fn.sh.
flg_DryRun=${flg_DryRun:-0}
scrDir=$(dirname "$(realpath "$0")")
export log_section="extract"
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo -e "\e[31mError: unable to source global_fn.sh...\e[0m"
    exit 1
fi

# Bucle principal de descompresión y mapeo de fuentes y recursos visuales:
# Lee línea por línea el archivo de configuración restore_fnt.lst.
# 1. Omite las líneas de comentario (#) y aquellas que no sigan el formato de dos columnas separadas por '|'.
# 2. Resuelve dinámicamente la ruta de la carpeta de destino evaluando variables de entorno en el path.
# 3. Comprueba y gestiona sistemas NixOS si intentan modificar directorios protegidos /usr/share.
# 4. Valida y crea la carpeta de destino (usando sudo en caso de no contar con permisos de escritura).
# 5. Descomprime el archivo de recursos correspondiente en su ruta de destino (empleando sudo de ser requerido).
while read -r lst; do
    # Omitir comentarios
    if [[ "$lst" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    # Validar formato de entrada
    if [ "$(echo "$lst" | awk -F '|' '{print NF}')" -ne 2 ]; then
        continue
    fi

    fnt=$(awk -F '|' '{print $1}' <<<"$lst")
    tgt=$(awk -F '|' '{print $2}' <<<"$lst")
    tgt=$(eval "echo $tgt")

    # Adaptación para sistemas basados en NixOS
    if [[ "${tgt}" =~ /(usr|usr\/local)\/share/ && -d /run/current-system/sw/share/ ]]; then
        echo "Detected NixOS system, changing target to /run/current-system/sw/share/..."
        continue
    fi

    # Creación del directorio de destino si no existe
    if [ ! -d "${tgt}" ]; then
        if ! mkdir -p "${tgt}"; then
            print_log -warn "create" "directory as root instead..."
            [ "${flg_DryRun}" -eq 1 ] || sudo mkdir -p "${tgt}"
        fi

    fi

    # Descompresión del recurso de tipografías/temas
    if [ -w "${tgt}" ]; then
        # shellcheck disable=SC2154
        [ "${flg_DryRun}" -eq 1 ] || tar -xzf "${cloneDir}/Source/arcs/${fnt}.tar.gz" -C "${tgt}/"
    else
        print_log -warn "not writable" "Extracting as root: ${tgt} "
        if [ "${flg_DryRun}" -ne 1 ]; then
            if ! sudo tar -xzf "${cloneDir}/Source/arcs/${fnt}.tar.gz" -C "${tgt}/" 2>/dev/null; then
                print_log -err "extraction by root FAILED" " giving up..."
                print_log "The above error can be ignored if the '${tgt}' is not writable..."
            fi
        fi
    fi
    print_log "${fnt}.tar.gz" -r " --> " "${tgt}... "

done <"${scrDir}/restore_fnt.lst"

# Reconstrucción de la caché de fuentes de Fontconfig en el sistema para registrar los nuevos elementos.
echo ""
print_log -stat "rebuild" "font cache"
[ "${flg_DryRun}" -eq 1 ] || fc-cache -f
