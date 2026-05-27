#!/usr/bin/env bash
#|---/ /+-------------------------------------+---/ /|#
#|--/ /-| Script to apply pre install configs |--/ /-|#
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

# Inicializa la bandera de modo de prueba/simulación (flg_DryRun) por defecto en 0 si no viene definida.
flg_DryRun=${flg_DryRun:-0}

#---------------------------------------#
# Configuración del gestor de arranque GRUB #
#---------------------------------------#
# Si GRUB está instalado y existe su archivo de configuración principal, se procede a configurarlo:
# 1. Se generan copias de seguridad de la configuración actual si no existen previamente.
# 2. Si se detecta una GPU Nvidia y no está desactivado el soporte para la misma (flg_Nvidia=1),
#    se añade el parámetro 'nvidia_drm.modeset=1' a las opciones predeterminadas de arranque de Linux.
# 3. Se solicita al usuario que seleccione un tema visual para GRUB (Retroboot, Pochita o ninguno).
# 4. Si se selecciona un tema, se descomprime en el directorio de temas de GRUB y se activa modificando /etc/default/grub.
# 5. Se regenera el archivo de configuración grub.cfg para aplicar los cambios.
if pkg_installed grub && [ -f /boot/grub/grub.cfg ]; then
    print_log -sec "bootloader" -b "detected :: " "grub..."

    if [ ! -f /etc/default/grub.ravn.bkp ] && [ ! -f /boot/grub/grub.ravn.bkp ]; then
        [ "${flg_DryRun}" -eq 1 ] || sudo cp /etc/default/grub /etc/default/grub.ravn.bkp
        [ "${flg_DryRun}" -eq 1 ] || sudo cp /boot/grub/grub.cfg /boot/grub/grub.ravn.bkp

        # Validación y configuración de parámetros específicos para GPUs Nvidia detectadas.
        if nvidia_detect; then
            if [ ${flg_Nvidia} -eq 1 ]; then
                print_log -g "[bootloader] " -b "configure :: " "nvidia detected, adding nvidia_drm.modeset=1 to boot option..."
                gcld=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "/etc/default/grub" | cut -d'"' -f2 | sed 's/\b nvidia_drm.modeset=.\b//g')
                [ "${flg_DryRun}" -eq 1 ] || sudo sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/c\GRUB_CMDLINE_LINUX_DEFAULT=\"${gcld} nvidia_drm.modeset=1\"" /etc/default/grub
            else
                print_log -g "[bootloader] " -b "skip :: " "nvidia detected, skipping nvidia_drm.modeset=1 to boot option..."
            fi
        fi

        # Menú interactivo de selección de tema visual para el cargador de GRUB.
        print_log -g "[bootloader] " "Select grub theme:" -y "\n[1]" -y " Retroboot (dark)" -y "\n[2]" -y " Pochita (light)"
        read -r -p " :: Press enter to skip grub theme <or> Enter option number : " grubopt
        case ${grubopt} in
        1) grubtheme="Retroboot" ;;
        2) grubtheme="Pochita" ;;
        *) grubtheme="None" ;;
        esac

        # Aplica el tema seleccionado o ignora la instalación si el usuario decide omitirla.
        if [ "${grubtheme}" == "None" ]; then
            print_log -g "[bootloader] " -b "skip :: " "grub theme selection skipped..."
            echo ""
        else
            print_log -g "[bootloader] " -b "set :: " "grub theme // ${grubtheme}"
            echo ""
            # shellcheck disable=SC2154
            [ "${flg_DryRun}" -eq 1 ] || sudo tar -xzf "${cloneDir}/Source/arcs/Grub_${grubtheme}.tar.gz" -C /usr/share/grub/themes/
            [ "${flg_DryRun}" -eq 1 ] || sudo sed -i "/^GRUB_DEFAULT=/c\GRUB_DEFAULT=saved
            /^GRUB_GFXMODE=/c\GRUB_GFXMODE=1280x1024x32,auto
            /^GRUB_THEME=/c\GRUB_THEME=\"/usr/share/grub/themes/${grubtheme}/theme.txt\"
            /^#GRUB_THEME=/c\GRUB_THEME=\"/usr/share/grub/themes/${grubtheme}/theme.txt\"
            /^#GRUB_SAVEDEFAULT=true/c\GRUB_SAVEDEFAULT=true" /etc/default/grub
            [ "${flg_DryRun}" -eq 1 ] || sudo grub-mkconfig -o /boot/grub/grub.cfg
        fi

    else
        print_log -y "[bootloader] " -b "exist :: " "grub is already configured..."
    fi
fi

#-----------------------------------------------#
# Configuración del gestor de arranque systemd-boot #
#-----------------------------------------------#
# Si systemd y una GPU Nvidia están presentes, y el gestor activo es systemd-boot:
# 1. Se verifica si las entradas de configuración de carga de kernels ya tienen copias de seguridad.
# 2. Se realiza una copia de seguridad (.ravn.bkp) de cada archivo de configuración de entrada (.conf).
# 3. Se edita cada entrada agregando los parámetros 'quiet splash nvidia_drm.modeset=1' a la línea de opciones.
if pkg_installed systemd && nvidia_detect && [ "$(bootctl status 2>/dev/null | awk '{if ($1 == "Product:") print $2}')" == "systemd-boot" ]; then
    print_log -sec "bootloader" -stat "detected" "systemd-boot"

    if [ "$(find /boot/loader/entries/ -type f -name '*.conf.ravn.bkp' 2>/dev/null | wc -l)" -ne "$(find /boot/loader/entries/ -type f -name '*.conf' 2>/dev/null | wc -l)" ]; then
        print_log -g "[bootloader] " -b " :: " "nvidia detected, adding nvidia_drm.modeset=1 to boot option..."
        if [[ "${flg_DryRun}" -ne 1 ]]; then
            find /boot/loader/entries/ -type f -name "*.conf" | while read -r imgconf; do
                sudo cp "${imgconf}" "${imgconf}.ravn.bkp"
                sdopt=$(grep -w "^options" "${imgconf}" | sed 's/\b quiet\b//g' | sed 's/\b splash\b//g' | sed 's/\b nvidia_drm.modeset=.\b//g')
                sudo sed -i "/^options/c${sdopt} quiet splash nvidia_drm.modeset=1" "${imgconf}"
            done
        fi
    else
        print_log -y "[bootloader] " -stat "skipped" "systemd-boot is already configured..."
    fi
fi

#-----------------------------------------#
# Optimización de Pacman y Actualización  #
#-----------------------------------------#
# Si existe el archivo /etc/pacman.conf y no hay una copia de respaldo previa:
# 1. Se crea un respaldo del archivo pacman.conf (.ravn.bkp).
# 2. Se modifican opciones estéticas y de rendimiento: Color, ILoveCandy, VerbosePkgLists y ParallelDownloads (5 descargas simultáneas).
# 3. Se habilita el repositorio oficial de multilib eliminando los comentarios de su sección.
# 4. Se ejecuta una actualización completa del sistema y bases de datos de Pacman.
if [ -f /etc/pacman.conf ] && [ ! -f /etc/pacman.conf.ravn.bkp ]; then
    print_log -g "[PACMAN] " -b "modify :: " "adding extra spice to pacman..."

    # shellcheck disable=SC2154
    [ "${flg_DryRun}" -eq 1 ] || sudo cp /etc/pacman.conf /etc/pacman.conf.ravn.bkp
    [ "${flg_DryRun}" -eq 1 ] || sudo sed -i "/^#Color/c\Color\nILoveCandy
    /^#VerbosePkgLists/c\VerbosePkgLists
    /^#ParallelDownloads/c\ParallelDownloads = 5" /etc/pacman.conf
    [ "${flg_DryRun}" -eq 1 ] || sudo sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf

    print_log -g "[PACMAN] " -b "update :: " "packages..."
    [ "${flg_DryRun}" -eq 1 ] || sudo pacman -Syyu
    [ "${flg_DryRun}" -eq 1 ] || sudo pacman -Fy
else
    print_log -sec "PACMAN" -stat "skipped" "pacman is already configured..."
fi

#-------------------------------------#
# Instalación opcional de Chaotic AUR #
#-------------------------------------#
# Se comprueba si pacman ya tiene configurado el repositorio externo Chaotic AUR:
# 1. Si ya existe, se omite el proceso de instalación.
# 2. Si no existe, se muestra un temporizador de diálogo ofreciendo su instalación.
# 3. Ante una respuesta afirmativa (y en caso de no ser modo simulación), se inicializa
#    el llavero de pacman-key y se manda a llamar a chaotic_aur.sh con el flag '--install'.
if grep -q '\[chaotic-aur\]' /etc/pacman.conf; then
    print_log -sec "CHAOTIC-AUR" -stat "skipped" "Chaotic AUR entry found in pacman.conf..."
else
    prompt_timer 120 "Would you like to install Chaotic AUR? [y/n] | q to quit "
    is_chaotic_aur=false

    case "${PROMPT_INPUT}" in
    y | Y)
        is_chaotic_aur=true
        ;;
    n | N)
        is_chaotic_aur=false
        ;;
    q | Q)
        print_log -sec "Chaotic AUR" -crit "Quit" "Exiting..."
        exit 1
        ;;
    *)
        is_chaotic_aur=true
        ;;
    esac
    if [ "${is_chaotic_aur}" == true ]; then
        print_log -sec "Chaotic-aur" -stat "Installation" "Installing Chaotic AUR..."
        if [[ "${flg_DryRun}" -ne 1 ]]; then
            sudo pacman-key --init
            sudo "${scrDir}/chaotic_aur.sh" --install
        fi
    else
        print_log -sec "Chaotic-aur" -stat "Skipped" "Chaotic AUR installation skipped..."
    fi
fi
