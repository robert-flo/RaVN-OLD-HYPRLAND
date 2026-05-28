#!/usr/bin/env bash
#|---/ /+---------------------------+---/ /|#
#|--/ /-| Script para montar discos |--/ /-|#
#|-/ /--| Roberto Flores            |-/ /--|#
#|/ /---+---------------------------+/ /---|#

#==============================================================================
# Inicialización de rutas e importación de funciones globales de RaVN
#==============================================================================
scrDir=$(dirname "$(dirname "$(realpath "$0")")")
source "${scrDir}/global_fn.sh"
if [ $? -ne 0 ]; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi


# Iterar sobre todas las particiones del sistema que sean de tipo 'ext4'
# Lee el tipo de sistema de archivos (fst), el UUID y el nombre del dispositivo (/dev/...)
while read -r fst uuid name; do

    # Obtener la etiqueta (label) y el punto de montaje actual de la partición
    label=$(lsblk --noheadings --raw -o LABEL "${name}")
    mount=$(lsblk --noheadings --raw -o MOUNTPOINT "${name}")

    # Si la partición está montada en la raíz (/) y no tiene etiqueta,
    # le asigna la etiqueta "YoRHa"
    if [ "${mount}" == "/" ] && [ -z "${label}" ]; then
        sudo e2label "${name}" "YoRHa"

    # Si la partición está montada en /home y no tiene etiqueta,
    # le asigna la etiqueta "9S"
    elif [ "${mount}" == "/home" ] && [ -z "${label}" ]; then
        sudo e2label "${name}" "9S"

    # Si la partición NO está montada, SÍ tiene etiqueta, y NO existe ya en /etc/fstab:
    elif [ -z "${mount}" ] && [ ! -z "${label}" ] && [ $(grep "${uuid}" /etc/fstab | wc -l) -eq 0 ]; then
        # Crear el directorio de montaje en /mnt/<etiqueta> si no existe
        [ ! -d "/mnt/${label}" ] && sudo mkdir -p "/mnt/${label}"
        
        # Preparar la entrada para agregarla a /etc/fstab (montaje persistente)
        fstEntry=$(echo -e "${fstEntry}\n#/${name}\nUUID=${uuid}    /mnt/${label}    ${fst}    nosuid,nodev,nofail,x-gvfs-show    0  0\n ")
        
        # Montar la partición inmediatamente para usarla en la sesión actual
        sudo mount "${name}" "/mnt/${label}"

    else
        continue
    fi

# Buscar todas las particiones ext4 y extraer sus datos para el bucle
done < <(lsblk --noheadings --raw -o TYPE,FSTYPE,UUID,NAME | awk '{if ($1=="part" && $2=="ext4") print $2, $3, "/dev/" $4}')

# Si se prepararon nuevas particiones en fstEntry, hacerlas persistentes
if [ ! -z "${fstEntry}" ]; then
    # Añadir las nuevas entradas al final de /etc/fstab
    echo -e "${fstEntry}\n" | sudo tee -a /etc/fstab
    # Recargar el demonio de systemd para registrar los nuevos montajes
    sudo systemctl daemon-reload
fi
