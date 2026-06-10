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

    # 2. Clonar/Actualizar e inicializar el repositorio
    if (( flg_DryRun != 1 )); then
      if [[ -d $HOME/.local/share/omarchy/.git ]]; then
        print_log -g "[OMARCHY] " "Actualizando repositorio Omarchy existente..."
        if cd "$HOME/.local/share/omarchy"; then
          git remote set-url origin "https://github.com/${omarchy_repo}.git"
          print_log -g "[OMARCHY] " "Obteniendo cambios de la rama: ${omarchy_ref}"
          git fetch origin "${omarchy_ref}" && git checkout "${omarchy_ref}" && git reset --hard "origin/${omarchy_ref}"
          cd - >/dev/null || true
        else
          print_log -warn "OMARCHY" "No se pudo acceder al directorio del repositorio existente."
          return 1
        fi
      else
        print_log -g "[OMARCHY] " "Clonando Omarchy desde: https://github.com/${omarchy_repo}.git"
        git clone "https://github.com/${omarchy_repo}.git" "$HOME/.local/share/omarchy" >/dev/null

        if cd "$HOME/.local/share/omarchy"; then
          print_log -g "[OMARCHY] " "Cambiando a la rama: ${omarchy_ref}"
          git fetch origin "${omarchy_ref}" && git checkout "${omarchy_ref}"
          cd - >/dev/null || true
        else
          print_log -warn "OMARCHY" "No se pudo acceder al directorio del repositorio clonado."
          return 1
        fi
      fi
    else
      print_log -y "[OMARCHY] " -b " :: " "Simulación: Se omite la clonación/actualización de Omarchy"
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
        print_log -g "[OMARCHY] " "Sincronizando bases de datos de pacman (Fy)...";
        sudo pacman -Fy

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

    # 2. Clonar/Actualizar e inicializar el repositorio
    if (( flg_DryRun != 1 )); then
      if [[ -d $HOME/.local/share/ravn/.git ]]; then
        print_log -g "[RAVN] " "Actualizando repositorio RaVN existente..."
        if cd "$HOME/.local/share/ravn"; then
          # Configurar el origen de git a SSH si hay llaves, o HTTPS de lo contrario
          if [[ -f $HOME/.ssh/id_ed25519 || -f $HOME/.ssh/id_rsa ]]; then
            git remote set-url origin "git@github.com:${ravn_repo}.git"
          else
            git remote set-url origin "https://github.com/${ravn_repo}.git"
          fi
          print_log -g "[RAVN] " "Obteniendo cambios de la rama: ${ravn_ref}"
          git fetch origin "${ravn_ref}" && git checkout "${ravn_ref}" && git reset --hard "origin/${ravn_ref}"
          cd - >/dev/null || true
        else
          print_log -warn "RAVN" "No se pudo acceder al directorio del repositorio existente."
          return 1
        fi
      else
        print_log -g "[RAVN] " "Clonando RaVN desde: https://github.com/${ravn_repo}.git"
        git clone "https://github.com/${ravn_repo}.git" "$HOME/.local/share/ravn" >/dev/null

        if cd "$HOME/.local/share/ravn"; then
          print_log -g "[RAVN] " "Cambiando a la rama: ${ravn_ref}"
          git fetch origin "${ravn_ref}" && git checkout "${ravn_ref}"

          # Cambiar origen a SSH si hay llaves SSH configuradas para facilitar los push
          if [[ -f $HOME/.ssh/id_ed25519 || -f $HOME/.ssh/id_rsa ]]; then
            print_log -g "[RAVN] " "Llave SSH detectada. Configurando el origen de git a SSH..."
            git remote set-url origin "git@github.com:${ravn_repo}.git"
          fi

          cd - >/dev/null || true
        else
          print_log -warn "RAVN" "No se pudo acceder al directorio del repositorio clonado."
          return 1
        fi
      fi
    else
      print_log -y "[RAVN] " -b " :: " "Simulación: Se omite la clonación/actualización de RaVN"
    fi
}

# Ejecutar configuración de RaVN
# setup_ravn



# ==============================================================================
# 2. Instalar gemas de Ruby (Desactivado/Ejemplo)
# ==============================================================================
# if pkg_installed ruby; then
#     print_log -g "[RUBY GEMS] " "Instalando gemas necesarias..."
#     [ ${flg_DryRun} -eq 1 ] || gem install bundler jekyll
# fi

# ==============================================================================
# 2b. Instalar herramientas npm vía omarchy-npx-install
# ==============================================================================
setup_npm_tools() {
  print_log -g "[NPM-NPX] " -b " :: " "Instalando herramientas globales vía omarchy-npx-install..."

  local npx_installer="$HOME/.local/share/omarchy/bin/omarchy-npx-install"

  if [[ -x $npx_installer ]]; then
    if (( flg_DryRun != 1 )); then
      local tools=(
        "@openai/codex:codex"
        "@google/gemini-cli:gemini"
        "@github/copilot:copilot"
        "opencode-ai:opencode"
        "playwright:playwright-cli"
        "@earendil-works/pi-coding-agent:pi"
        "@kitlangton/ghui:ghui"
      )

      for tool in "${tools[@]}"; do
        local pkg="${tool%%:*}"
        local cmd="${tool##*:}"
        print_log -b "  -> " "Configurando ${pkg} como '${cmd}'..."
        if "$npx_installer" "${pkg}" "${cmd}"; then
          print_log -g "     [OK] " "Instalado correctamente en ~/.local/bin/${cmd}"
        else
          print_log -r "     [FAIL] " "Fallo al instalar ${pkg}"
        fi
      done
    else
      print_log -y "[NPM-NPX] " -b " :: " "Simulación: Se omite la instalación de herramientas npm"
    fi
  else
    print_log -warn "NPM-NPX" "No se encontró el instalador de npx en ${npx_installer}"
  fi
}

setup_npm_tools

# ==============================================================================
# 2c. Configurar tema Sleek para Spotify vía Spicetify
# ==============================================================================
setup_spicetify() {
  if pkg_installed spotify && pkg_installed spicetify-cli; then
    print_log -g "[SPICETIFY] " -b " :: " "Configurando tema Sleek para Spotify..."
    if (( flg_DryRun != 1 )); then
      # Asegurar permisos de escritura en la carpeta de Spotify
      if [[ -d /opt/spotify ]]; then
        if [[ ! -w /opt/spotify || ! -w /opt/spotify/Apps ]]; then
          print_log -g "[SPICETIFY] " "Solicitando permisos de escritura para /opt/spotify..."
          sudo chmod a+wr /opt/spotify
          sudo chmod a+wr /opt/spotify/Apps -R
        fi
      fi

      # Crear archivo dummy de preferencias si no existe
      mkdir -p "$HOME/.config/spotify"
      if [[ ! -f $HOME/.config/spotify/prefs ]]; then
        touch "$HOME/.config/spotify/prefs"
      fi

      # Configurar rutas en spicetify y crear directorio de temas
      mkdir -p "$HOME/.config/spicetify/Themes"
      spicetify config spotify_path "/opt/spotify" prefs_path "$HOME/.config/spotify/prefs" || true

      if [[ -f $cloneDir/Source/arcs/Spotify_Sleek.tar.gz ]]; then
        tar -xzf "$cloneDir/Source/arcs/Spotify_Sleek.tar.gz" -C "$HOME/.config/spicetify/Themes/"
        # Inicializar spicetify si es la primera vez
        if [[ ! -d $HOME/.config/spicetify/Backup ]]; then
          spicetify backup apply || true
        fi
        spicetify config current_theme Sleek || true
        spicetify config color_scheme Catppuccin || true
        spicetify apply || true
        print_log -g "[SPICETIFY] " "Tema Sleek de Spotify configurado y aplicado correctamente."
      else
        print_log -warn "SPICETIFY" "No se encontró el archivo Spotify_Sleek.tar.gz en Source/arcs."
      fi
    else
      print_log -y "[SPICETIFY] " -b " :: " "Simulación: Se omite la configuración del tema de Spotify"
    fi
  else
    print_log -y "[SPICETIFY] " -b " :: " "Spotify o Spicetify-cli no están instalados. Omitiendo..."
  fi
}

setup_spicetify



# ==============================================================================
# 3. Tweaks finales y otros comandos
# ==============================================================================
print_log -g "[SSH-AGENT] " "Habilitando e iniciando el socket de ssh-agent para el usuario..."
if [[ ${flg_DryRun} -ne 1 ]]; then
    systemctl --user enable --now ssh-agent.socket
else
    print_log -y "[SSH-AGENT] " -b " :: " "Simulación: Se omite la habilitación del socket de ssh-agent"
fi

print_log -g "[SSH-CONFIG] " "Configurando AddKeysToAgent en ~/.ssh/config..."
if [[ ${flg_DryRun} -ne 1 ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    if [ ! -f "$HOME/.ssh/config" ]; then
        echo -e "Host *\n    AddKeysToAgent yes" > "$HOME/.ssh/config"
        chmod 600 "$HOME/.ssh/config"
    elif ! grep -q "AddKeysToAgent" "$HOME/.ssh/config"; then
        echo -e "\nHost *\n    AddKeysToAgent yes" >> "$HOME/.ssh/config"
    fi
else
    print_log -y "[SSH-CONFIG] " -b " :: " "Simulación: Se omite la configuración de ~/.ssh/config"
fi

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

      sudo pacman -S --needed --noconfirm neovim
      
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

