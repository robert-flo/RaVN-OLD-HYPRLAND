#!/usr/bin/env bash
#|---/ /+-------------------------------+---/ /|#
#|--/ /-| Script para eliminar config de RaVN|--/ /-|#
#|-/ /--| Roberto Flores                |-/ /--|#
#|/ /---+-------------------------------+/ /---|#

# ==============================================================================
# Banner inicial de advertencia e ingreso de la palabra clave de seguridad
# ==============================================================================
cat <<"EOF"

-------------------------------------------------
        .
       / \       ___       _   _ _  _
      /^  \     | _ \__ _ | | | | \| |
     /  _  \    |   / _` || |_| | .` |
    /  | | ~\   |_|_\__,_| \___/|_|\_|
   /.-'   '-.\

-------------------------------------------------


.: ADVERTENCIA :: Esto eliminará todos los archivos de configuración de RaVN :.

Por favor escribe "DONT RAVN" para continuar...
EOF

read -r PROMPT_INPUT
[ "${PROMPT_INPUT}" == "DONT RAVN" ] || exit 0

cat <<"EOF"

          _         _       _ _
  _ _ ___|_|___ ___| |_ ___| | |
 | | |   | |   |_ -|  _| .'| | |
 |___|_|_|_|_|_|___|_| |__,|_|_|


EOF

# ==============================================================================
# Inicialización de rutas e importación de funciones globales de RaVN
# ==============================================================================
scrDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

CfgLst="${scrDir}/restore_cfg.lst"
if [ ! -f "${CfgLst}" ]; then
    echo "ERROR: '${CfgLst}' does not exist..."
    exit 1
fi

BkpDir="${HOME}/.config/cfg_backups/$(date +'%y%m%d_%Hh%Mm%Ss')_remove"
mkdir -p "${BkpDir}"

# ==============================================================================
# Lectura de la lista de restauración y respaldo/eliminación de archivos activos
# ==============================================================================
cat "${CfgLst}" | while read -r lst; do
    pth=$(echo "${lst}" | awk -F '|' '{print $3}')
    pth=$(eval echo "${pth}")
    cfg=$(echo "${lst}" | awk -F '|' '{print $4}')

    echo "${cfg}" | xargs -n 1 | while read -r cfg_chk; do
        [[ -z "${pth}" ]] && continue
        if [ -d "${pth}/${cfg_chk}" ] || [ -f "${pth}/${cfg_chk}" ]; then
            tgt=$(echo "${pth}" | sed "s+^${HOME}++g")
            if [ ! -d "${BkpDir}${tgt}" ]; then
                mkdir -p "${BkpDir}${tgt}"
            fi
            mv "${pth}/${cfg_chk}" "${BkpDir}${tgt}"
            echo -e "\033[0;34m[removed]\033[0m ${pth}/${cfg_chk}"
        fi
    done
done

# ==============================================================================
# Limpieza de directorios locales de caché, configuración y estado de RaVN
# ==============================================================================
[ -d "$HOME/.config/ravn" ] && rm -rf "$HOME/.config/ravn"
[ -d "$HOME/.cache/ravn" ] && rm -rf "$HOME/.cache/ravn"
[ -d "$HOME/.local/state/ravn" ] && rm -rf "$HOME/.local/state/ravn"

# ==============================================================================
# Mensaje con las instrucciones de limpieza manual del sistema
# ==============================================================================
cat <<"NOTE"
-------------------------------------------------------
.: Acciones manuales requeridas para completar la desinstalación :.
-------------------------------------------------------

Elimina manualmente respaldos, iconos, fuentes y temas de RaVN de estas rutas:
$HOME/.config/cfg_backups               # eliminar respaldos previos
$HOME/.local/share/fonts                # eliminar fuentes de aquí
$HOME/.local/share/icons                # eliminar iconos de aquí
$HOME/.local/share/themes               # eliminar temas de aquí
$HOME/.icons                            # eliminar iconos de aquí
$HOME/.themes                           # eliminar temas de aquí

Revierte la configuración del cargador de arranque/pacman/sddm desde los respaldos:
/boot/loader/entries/*.conf.ravn.bkp    # restaurar systemd-boot desde este respaldo
/etc/default/grub.ravn.bkp              # restaurar grub desde este respaldo
/boot/grub/grub.ravn.bkp                # restaurar grub desde este respaldo
/usr/share/grub/themes                  # eliminar temas de grub de aquí
/etc/pacman.conf.ravn.bkp               # restaurar pacman desde este respaldo
/etc/sddm.conf.d/kde_settings.ravn.bkp  # restaurar sddm desde este respaldo
/usr/share/sddm/themes                  # eliminar temas de sddm de aquí

Desinstala manualmente los paquetes que ya no necesites usando estas listas:
/home/dominus/Work/RaVN/Scripts/pkg_core.lst
NOTE
