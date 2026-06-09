#!/bin/bash
#|---/ /+--------------------------------------+---/ /|#
#|--/ /-| Script for final configuration tweaks |--/ /-|#
#|-/ /--| Roberto Flores                       |-/ /--|#
#|/ /---+--------------------------------------+/ /---|#

# ==============================================================================
# Inicialización e importación de funciones globales de RaVN
# ==============================================================================
scrDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

flg_DryRun=${flg_DryRun:-0}

print_log -g "[FINAL CONFIG] " -b " :: " "Iniciando configuración final..."

# ==============================================================================
# 1. Configuración de Omarchy
# ==============================================================================
setup_omarchy() {
    # Usar rama personalizada si se indica, de lo contrario por defecto 'master'
    local omarchy_ref="${OMARCHY_REF:-master}"
    # Usar repositorio personalizado si se especifica, de lo contrario por defecto 'basecamp/omarchy'
    local omarchy_repo="${OMARCHY_REPO:-basecamp/omarchy}"

    print_log -g "[OMARCHY] " -b " :: " "Configurando repositorio Omarchy (${omarchy_repo}) en la rama ${omarchy_ref}..."

    # Definir el canal del mirror de Omarchy según la rama
    local omarchy_mirror="stable"
    if [[ "${omarchy_ref}" == "dev" ]]; then
        omarchy_mirror="edge"
    elif [[ "${omarchy_ref}" == "rc" ]]; then
        omarchy_mirror="rc"
    fi
    export OMARCHY_MIRROR="${omarchy_mirror}"

    # 1. Asegurar la instalación de git usando los repositorios actuales del sistema
    if [[ ${flg_DryRun} -ne 1 ]]; then
        sudo pacman -Sy --noconfirm --needed git
    else
        print_log -y "[OMARCHY] " -b " :: " "Simulación: Se omite la instalación de git"
    fi

    # 2. Clonar e inicializar el repositorio
    print_log -g "[OMARCHY] " "Clonando Omarchy desde: https://github.com/${omarchy_repo}.git"
    
    if [[ ${flg_DryRun} -ne 1 ]]; then
        rm -rf "$HOME/.local/share/omarchy/"
        git clone "https://github.com/${omarchy_repo}.git" "$HOME/.local/share/omarchy" >/dev/null
        
        if cd "$HOME/.local/share/omarchy"; then
            print_log -g "[OMARCHY] " "Cambiando a la rama: ${omarchy_ref}"
            git fetch origin "${omarchy_ref}" && git checkout "${omarchy_ref}"
            cd - >/dev/null || true
        else
            print_log -warn "OMARCHY" "No se pudo acceder al directorio del repositorio clonado."
            return 1
        fi
    else
        print_log -y "[OMARCHY] " -b " :: " "Simulación: Se omite la clonación de Omarchy"
    fi

    # 3. Integrar el repositorio [omarchy] en /etc/pacman.conf sin pisar la configuración actual
    print_log -g "[OMARCHY] " "Integrando el repositorio [omarchy] en /etc/pacman.conf..."
    if [[ ${flg_DryRun} -ne 1 ]]; then
        # Remover cualquier configuración previa de [omarchy] para evitar duplicados
        sudo sed -i '/^\[omarchy\]/,/^[[:space:]]*$/d' /etc/pacman.conf
        # Eliminar saltos de línea adicionales al final del archivo
        sudo sed -i -e :a -e '/^\n*$/{$d;N;ba}' /etc/pacman.conf
        
        # Determinar el canal para la URL
        local channel_name="${omarchy_mirror}"
        
        # Agregar el bloque al final de pacman.conf
        sudo tee -a /etc/pacman.conf >/dev/null <<EOF

[omarchy]
SigLevel = Optional TrustAll
Server = https://pkgs.omarchy.org/${channel_name}/\$arch
EOF
        
        # Sincronizar las bases de datos de pacman

        print_log -g "[OMARCHY] " -b " :: " "Instalando tobi-try (directorios independientes para cada prueba)..."
        sudo pacman -S --needed --noconfirm tobi-try


        print_log -g "[OMARCHY] " -b " :: " "Instalando dependencias necesarias para que omarchy-menu esté disponible y funcional..."
        sudo pacman -S --needed --noconfirm omarchy-walker

        # 4. Configurar Walker y Elephant (Misma lógica que walker-elephant.sh de Omarchy)
        print_log -g "[OMARCHY] " "Configurando integración de Walker y Elephant..."
        
        # Asegurar la existencia de los directorios necesarios
        mkdir -p "$HOME/.config/autostart"
        mkdir -p "$HOME/.config/systemd/user/app-walker@autostart.service.d"
        mkdir -p "$HOME/.config/elephant/menus"

        # Copiar configuraciones de autostart y reinicio de Walker
        cp "$HOME/.local/share/omarchy/default/walker/walker.desktop" "$HOME/.config/autostart/"
        cp "$HOME/.local/share/omarchy/default/walker/restart.conf" "$HOME/.config/systemd/user/app-walker@autostart.service.d/"

        # Crear enlaces simbólicos para los menús de Elephant (enlazados a upstream)
        ln -snf "$HOME/.local/share/omarchy/default/elephant/omarchy_themes.lua" "$HOME/.config/elephant/menus/omarchy_themes.lua"
        ln -snf "$HOME/.local/share/omarchy/default/elephant/omarchy_background_selector.lua" "$HOME/.config/elephant/menus/omarchy_background_selector.lua"
        ln -snf "$HOME/.local/share/omarchy/default/elephant/omarchy_unlocks.lua" "$HOME/.config/elephant/menus/omarchy_unlocks.lua"

        # Crear el hook de pacman para reiniciar walker tras actualizaciones
        sudo mkdir -p /etc/pacman.d/hooks
        sudo tee /etc/pacman.d/hooks/walker-restart.hook > /dev/null <<EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = walker
Target = walker-debug
Target = elephant*

[Action]
Description = Restarting Walker services after system update
When = PostTransaction
Exec = $HOME/.local/share/omarchy/bin/omarchy-restart-walker
EOF
    else
        print_log -y "[OMARCHY] " -b " :: " "Simulación: Se omite la integración de [omarchy] en pacman.conf"
    fi
}

# Ejecutar configuración de Omarchy
setup_omarchy

setup_ravn() {
    # Usar rama personalizada si se indica, de lo contrario por defecto la actual o 'master'
    local default_branch
    default_branch=$(git -C "$scrDir" branch --show-current 2>/dev/null || echo "master")
    local ravn_ref="${RAVN_REF:-$default_branch}"
    # Usar repositorio personalizado si se especifica, de lo contrario por defecto 'robert-flo/RaVN'
    local ravn_repo="${RAVN_REPO:-robert-flo/RaVN}"

    print_log -g "[RAVN] " -b " :: " "Configurando repositorio RaVN (${ravn_repo}) en la rama ${ravn_ref}..."

    # 1. Asegurar la instalación de git usando los repositorios actuales del sistema
    if [[ ${flg_DryRun} -ne 1 ]]; then
        sudo pacman -Sy --noconfirm --needed git
    else
        print_log -y "[RAVN] " -b " :: " "Simulación: Se omite la instalación de git"
    fi

    # 2. Clonar e inicializar el repositorio
    print_log -g "[RAVN] " "Clonando RaVN desde: https://github.com/${ravn_repo}.git"
    
    if [[ ${flg_DryRun} -ne 1 ]]; then
        rm -rf "$HOME/.local/share/ravn/"
        git clone "https://github.com/${ravn_repo}.git" "$HOME/.local/share/ravn" >/dev/null
        
        if cd "$HOME/.local/share/ravn"; then
            print_log -g "[RAVN] " "Cambiando a la rama: ${ravn_ref}"
            git fetch origin "${ravn_ref}" && git checkout "${ravn_ref}"
            cd - >/dev/null || true
        else
            print_log -warn "RAVN" "No se pudo acceder al directorio del repositorio clonado."
            return 1
        fi
    else
        print_log -y "[RAVN] " -b " :: " "Simulación: Se omite la clonación de RaVN"
    fi
}

# Ejecutar configuración de RaVN
setup_ravn



# ==============================================================================
# 2. Instalar gemas de Ruby
# ==============================================================================
# Ejemplo:
# if pkg_installed ruby; then
#     print_log -g "[RUBY GEMS] " "Instalando gemas necesarias..."
#     [ ${flg_DryRun} -eq 1 ] || gem install bundler jekyll
# fi

# ==============================================================================
# 3. Tweaks finales y otros comandos
# ==============================================================================
# Agrega aquí cualquier otra personalización o comandos finales.
# Ejemplo:
# print_log -g "[TWEAKS] " "Aplicando tweaks finales..."

# ==============================================================================
# 4. Instalar plugin de dotbare para oh-my-zsh
# ==============================================================================
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/dotbare" ]]; then
    print_log -g "[DOTBARE] " "Clonando plugin de dotbare para oh-my-zsh..."
    if (( flg_DryRun != 1 )); then
      git clone https://github.com/kazhala/dotbare.git "$HOME/.oh-my-zsh/custom/plugins/dotbare"
    else
      print_log -y "[DOTBARE] " -b " :: " "Simulación: Se omite la clonación del plugin dotbare"
    fi
  else
    print_log -g "[DOTBARE] " "El plugin de dotbare ya está instalado en oh-my-zsh."
  fi
fi

# ==============================================================================
# 5. Instalar nvim-lazyman (Opcional - Paso tardado)
# ==============================================================================
if [[ ! -d "$HOME/.config/nvim-Lazyman" ]]; then
  if [[ ${flg_DryRun} -ne 1 ]]; then
    prompt_timer 10 "Quieres instalar nvim-lazyman ahora? (Paso tardado) [y/N]"
    if [[ "${PROMPT_INPUT,,}" == "y" ]]; then
      print_log -g "[LAZYMAN] " "Instalando nvim-lazyman..."
      git clone https://github.com/doctorfree/nvim-lazyman "$HOME/.config/nvim-Lazyman"
      "$HOME/.config/nvim-Lazyman/lazyman.sh"
    else
      print_log -y "[LAZYMAN] " "Instalación omitida. Puedes instalarlo manualmente ejecutando: git clone https://github.com/doctorfree/nvim-lazyman \$HOME/.config/nvim-Lazyman && \$HOME/.config/nvim-Lazyman/lazyman.sh"
    fi
  else
    print_log -y "[LAZYMAN] " -b " :: " "Simulación: Se omite la consulta/instalación de nvim-lazyman"
  fi
else
  print_log -g "[LAZYMAN] " "nvim-lazyman ya está instalado."
fi

