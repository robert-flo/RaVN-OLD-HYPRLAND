#!/usr/bin/env bash
#|---/ /+-------------------------------------+---/ /|#
#|--/ /-| Script de restauración de servicios |--/ /-|#
#|-/ /--| Roberto Flores                      |-/ /--|#
#|/ /---+-------------------------------------+/ /---|#

# ==============================================================================
# Inicialización e importación de funciones globales de RaVN
# ==============================================================================
scrDir="$(dirname "$(realpath "$0")")"
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

flg_DryRun=${flg_DryRun:-0}

# ==============================================================================
# Función heredada para compatibilidad con el formato antiguo system_ctl.lst
# ==============================================================================
handle_legacy_service() {
    local serviceChk="$1"
    
    # Utiliza la lógica original para compatibilidad hacia atrás
    if [[ $(systemctl list-units --all -t service --full --no-legend "${serviceChk}.service" | sed 's/^\s*//g' | cut -f1 -d' ') == "${serviceChk}.service" ]]; then
        print_log -y "[skip] " -b "active " "Service ${serviceChk}"
    else
        print_log -y "enable " "Service ${serviceChk}"
        if [ "$flg_DryRun" -ne 1 ]; then
            sudo systemctl enable "${serviceChk}.service"
        fi
    fi
}

# ==============================================================================
# Procesamiento principal y lectura de la lista de servicios restore_svc.lst
# ==============================================================================
print_log -sec "services" -stat "restore" "system services..."

while IFS='|' read -r service context command || [ -n "$service" ]; do
    # Omitir líneas vacías y comentarios
    [[ -z "$service" || "$service" =~ ^[[:space:]]*# ]] && continue
    
    # Limpiar espacios en blanco adicionales
    service=$(echo "$service" | xargs)
    context=$(echo "$context" | xargs)
    command=$(echo "$command" | xargs)
    
    # Comprobar si se trata del nuevo formato delimitado por tuberías (|) o formato heredado
    if [[ -z "$context" ]]; then
        # Formato heredado: solo el nombre del servicio
        handle_legacy_service "$service"
    else
        # Nuevo formato: servicio|contexto|comando
        # Dividir el comando en un arreglo para manejar los espacios correctamente
        read -ra cmd_array <<< "$command"
        
        print_log -y "[exec] " "Service ${service} (${context}): $command"
        
        if [ "$flg_DryRun" -ne 1 ]; then
            if [ "$context" = "user" ] ; then
                if [[ -n "${DBUS_SESSION_BUS_ADDRESS}" ]] && [[ -n $XDG_RUNTIME_DIR ]];then
                    systemctl --user "${cmd_array[@]}" "${service}.service"
                else 
                    print_log -sec "services" -stat "error" "DBUS_SESSION_BUS_ADDRESS or XDG_RUNTIME_DIR not set for user service" -y " skipping"
                fi
            else
                sudo systemctl "${cmd_array[@]}" "${service}.service"
            fi
        else
            if [ "$context" = "user" ]; then
                print_log -c "[dry-run] " "systemctl --user ${cmd_array[*]} ${service}.service"
            else
                print_log -c "[dry-run] " "sudo systemctl ${cmd_array[*]} ${service}.service"
            fi
        fi
    fi
    
done < "${scrDir}/restore_svc.lst"

print_log -sec "services" -stat "completed" "service updated successfully"
