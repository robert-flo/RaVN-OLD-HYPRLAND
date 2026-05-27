#!/usr/bin/env bash
# shellcheck disable=SC2154
#|---/ /+--------------------------+---/ /|#
#|--/ /-| Main installation script |--/ /-|#
#|-/ /--| Roberto Flores           |-/ /--|#
#|/ /---+--------------------------+/ /---|#

cat <<"EOF"

-----------------------------------------------------------
        .
       / \       _     ___   __ _ __   __ _   _ 
      /^  \    _| |_  | _ \ / _` |\ \ / /| \ | |
     /  _  \  |_   _| ||  /| (_| | \ V / |  \| |
    /  | | ~\   |_|   |_|_\ \__,_|  \_/  |_| \_|
   /.-'   '-.\

-----------------------------------------------------------

EOF

#--------------------------------#
# import variables and functions #
#--------------------------------#
# Establece el directorio de trabajo del script e importa variables y funciones globales
# desde global_fn.sh. Si no se puede cargar el archivo, el script termina con error.
scrDir="$(dirname "$(realpath "$0")")"
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
	echo "Error: unable to source global_fn.sh..."
	exit 1
fi


#------------------#
# evaluate options #
#------------------#
# Inicialización y Evaluación de Opciones (Líneas 33-88)
# El script define una serie de banderas (flags) por defecto:
#
# flg_Install=0      : Instalar Hyprland sin configuraciones.
# flg_Restore=0      : Restaurar archivos de configuración.
# flg_Service=0      : Habilitar servicios del sistema.
# flg_DryRun=0       : Modo simulación (test run) sin ejecutar cambios.
# flg_Shell=0        : Revaluar la configuración de la Shell.
# flg_Nvidia=1       : Por defecto se asume soporte para GPUs Nvidia (acciones de Nvidia activadas).
# flg_ThemeInstall=1 : Reinstalaciones de temas activadas.
flg_Install=0
flg_Restore=0
flg_Service=0
flg_DryRun=0
flg_Shell=0
flg_Nvidia=1
flg_ThemeInstall=1

# A continuación, recorre los argumentos pasados por la línea de comandos usando un ciclo:
# while getopts idrstmnh RunStep; do:
#
# -i : Activa la instalación (flg_Install=1).
# -d : Activa la instalación y define use_default="--noconfirm" para proceder sin confirmación del usuario.
# -r : Activa la restauración de configuraciones (flg_Restore=1).
# -s : Habilita los servicios del sistema (flg_Service=1).
# -n : Desactiva el soporte Nvidia (flg_Nvidia=0) e imprime un aviso en consola.
# -h : Activa la reevaluación de la shell (flg_Shell=1) y lo registra.
# -t : Activa el modo simulación (flg_DryRun=1).
# -m : Desactiva la reinstalación de temas (flg_ThemeInstall=0).
# Cualquier otra opción: Muestra un menú de ayuda (Usage) detallando las opciones disponibles
# y las combinaciones correctas de argumentos, y finaliza el script con código de salida 1.
while getopts idrstmnh RunStep; do
	case $RunStep in
	i) flg_Install=1 ;;
	d)
		flg_Install=1
		export use_default="--noconfirm"
		;;
	r) flg_Restore=1 ;;
	s) flg_Service=1 ;;
	n)
		# shellcheck disable=SC2034
		export flg_Nvidia=0
		print_log -r "[nvidia] " -b "Ignored :: " "skipping Nvidia actions"
		;;
	h)
		# shellcheck disable=SC2034
		export flg_Shell=1
		print_log -r "[shell] " -b "Reevaluate :: " "shell options"
		;;
	t) flg_DryRun=1 ;;
	m) flg_ThemeInstall=0 ;;
	*)
		cat <<EOF
Usage: $0 [options]
            i : [i]nstall hyprland without configs
            d : install hyprland [d]efaults without configs --noconfirm
            r : [r]estore config files
            s : enable system [s]ervices
            n : ignore/[n]o [n]vidia actions (-irsn to ignore nvidia)
            h : re-evaluate S[h]ell
            m : no the[m]e reinstallations
            t : [t]est run without executing (-irst to dry run all)

NOTE:
        running without args is equivalent to -irs
        to ignore nvidia, run -irsn

WRONG:
        install.sh -n # This will not work

EOF
		exit 1
		;;
	esac
done