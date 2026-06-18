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

step "Configuración Final"
print_log -g "[FINAL CONFIG] " -b " :: " "Iniciando configuración final..."

# ==============================================================================
# 1. Configuración de Omarchy
# ==============================================================================
setup_omarchy() {
    # Usar rama personalizada si se indica, de lo contrario por defecto 'master'
    local omarchy_ref="${OMARCHY_REF:-master}"
    # Usar repositorio personalizado si se especifica, de lo contrario por defecto 'basecamp/omarchy'
    local omarchy_repo="${OMARCHY_REPO:-basecamp/omarchy}"

    step "Configurando Omarchy (${omarchy_repo}@${omarchy_ref})"

    # Definir el canal del mirror de Omarchy según la rama
    local omarchy_mirror="stable"
    if [[ "${omarchy_ref}" == "dev" ]]; then
        omarchy_mirror="edge"
    elif [[ "${omarchy_ref}" == "rc" ]]; then
        omarchy_mirror="rc"
    fi
    export OMARCHY_MIRROR="${omarchy_mirror}"

    # 1. Asegurar la instalación de git usando los repositorios actuales del sistema
    run_with_status "Asegurando instalación de git" sudo pacman -Sy --noconfirm --needed git

    # 2. Clonar/Actualizar e inicializar el repositorio
    clone_or_update_repo "Omarchy" "$omarchy_repo" "$HOME/.local/share/omarchy" "$omarchy_ref"

    # 3. Integrar el repositorio [omarchy] en /etc/pacman.conf sin pisar la configuración actual
    info "Integrando el repositorio [omarchy] en /etc/pacman.conf..."
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
        run_with_status "Sincronizando bases de datos de pacman (Fy)" sudo pacman -Fy

        run_with_status "Instalando tobi-try" sudo pacman -S --needed --noconfirm tobi-try
        run_with_status "Instalando omarchy-walker" sudo pacman -S --needed --noconfirm omarchy-walker

        # 4. Configurar Walker y Elephant (Misma lógica que walker-elephant.sh de Omarchy)
        info "Configurando integración de Walker y Elephant..."

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
        success "Omarchy configurado correctamente."
        count_ok
    else
        print_log -y "[OMARCHY] " -b " :: " "Simulación: Se omite la integración de [omarchy] en pacman.conf"
        count_skip
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

    step "Configurando RaVN (${ravn_repo}@${ravn_ref})"

    # 1. Asegurar la instalación de git usando los repositorios actuales del sistema
    run_with_status "Asegurando instalación de git" sudo pacman -Sy --noconfirm --needed git

    # 2. Clonar/Actualizar e inicializar el repositorio
    #    El quinto argumento "ssh" habilita la detección automática de llaves SSH
    if clone_or_update_repo "RaVN" "$ravn_repo" "$HOME/.local/share/ravn" "$ravn_ref" "ssh"; then
        count_ok
    else
        count_fail
    fi
}

# Ejecutar configuración de RaVN
setup_ravn

# ==============================================================================
# 2. Instalar gemas de Ruby (Desactivado/Ejemplo)
# ==============================================================================
# if pkg_installed ruby; then
#     print_log -g "[RUBY GEMS] " "Instalando gemas necesarias..."
#     [ ${flg_DryRun} -eq 1 ] || gem install bundler jekyll
# fi

# ==============================================================================


# ==============================================================================
# 2c. Configurar tema Sleek para Spotify vía Spicetify
# ==============================================================================
setup_spicetify() {
  if pkg_installed spotify && pkg_installed spicetify-cli; then
    step "Configurando tema Sleek para Spotify"
    if (( flg_DryRun != 1 )); then
      # Asegurar permisos de escritura en la carpeta de Spotify
      if [[ -d /opt/spotify ]]; then
        if [[ ! -w /opt/spotify || ! -w /opt/spotify/Apps ]]; then
          info "Solicitando permisos de escritura para /opt/spotify..."
          sudo chmod a+wr /opt/spotify
          sudo chmod a+wr /opt/spotify/Apps -R
        fi
      fi

      # Crear archivo dummy de preferencias si no existe
      mkdir -p "$HOME/.config/spotify"
      if [[ ! -f $HOME/.config/spotify/prefs ]]; then
        touch "$HOME/.config/spotify/prefs"
      fi

      # Configurar rutas en spicetify y crear directorio de temas y extensiones
      mkdir -p "$HOME/.config/spicetify/Themes"
      mkdir -p "$HOME/.config/spicetify/Extensions"
      spicetify config spotify_path "/opt/spotify" prefs_path "$HOME/.config/spotify/prefs" &>/dev/null || true

      # Asegurar la existencia de los temas y extensiones
      # (Si no se restauraron por alguna razón, los creamos o descargamos como fallback)
      if [[ ! -d $HOME/.config/spicetify/Themes/Sleek ]]; then
        if [[ -f $cloneDir/Source/arcs/Spotify_Sleek.tar.gz ]]; then
          info "Extrayendo tema Sleek desde el archivo comprimido (fallback)..."
          tar -xzf "$cloneDir/Source/arcs/Spotify_Sleek.tar.gz" -C "$HOME/.config/spicetify/Themes/"
        else
          warn_msg "No se encontró el tema Sleek en ~/.config/spicetify/Themes/Sleek."
        fi
      fi

      if [[ ! -f $HOME/.config/spicetify/Extensions/adblock.js ]]; then
        info "Descargando extensión adblock (fallback)..."
        retry 3 download_file "https://raw.githubusercontent.com/rxri/spicetify-extensions/main/adblock/adblock.js" "$HOME/.config/spicetify/Extensions/adblock.js" || true
      fi

      # Aplicar spicetify si el tema existe
      if [[ -d $HOME/.config/spicetify/Themes/Sleek ]]; then
        # Inicializar backup de Spicetify (comando actualizado para v2.x)
        if [[ ! -d $HOME/.config/spicetify/Backup ]]; then
          run_with_status "Creando backup de Spicetify" spicetify backup
        fi
        spicetify config current_theme Sleek &>/dev/null || true
        spicetify config color_scheme Catppuccin &>/dev/null || true
        spicetify config extensions adblock.js &>/dev/null || true
        run_with_status "Aplicando tema Sleek (Catppuccin) + adblock" spicetify apply
        success "Spotify: Tema Sleek (Catppuccin) y adblock configurados correctamente."
        count_ok
      else
        error_msg "No se pudo aplicar el tema Sleek porque el directorio del tema no existe."
        count_fail
      fi
    else
      print_log -y "[SPICETIFY] " -b " :: " "Simulación: Se omite la configuración del tema de Spotify"
      count_skip
    fi
  else
    info "Spotify o Spicetify-cli no están instalados. Omitiendo..."
    count_skip
  fi
}

setup_spicetify



# ==============================================================================
# 3. Tweaks finales y otros comandos
# ==============================================================================
step "Tweaks del sistema"

setup_firewall() {
  info "Configurando reglas de firewall UFW para LocalSend..."
  if command -v ufw &>/dev/null; then
    if (( flg_DryRun != 1 )); then
      # Validamos si el servicio ufw está activo
      if systemctl is-active --quiet ufw; then
        run_with_status "Permitiendo puerto 53317/udp para localsend" sudo ufw allow 53317/udp
        run_with_status "Permitiendo puerto 53317/tcp para localsend" sudo ufw allow 53317/tcp
        success "Reglas de firewall configuradas correctamente para localsend."
        count_ok
      else
        warn_msg "UFW está instalado pero el servicio no está activo."
        count_skip
      fi
    else
      print_log -y "[UFW] " -b " :: " "Simulación: Se omite la configuración del firewall"
      count_skip
    fi
  else
    info "UFW no está instalado. Omitiendo configuración de firewall."
    count_skip
  fi
}

setup_firewall

info "Habilitando socket de ssh-agent para el usuario..."
if [[ ${flg_DryRun} -ne 1 ]]; then
    if systemctl --user enable --now ssh-agent.socket 2>/dev/null; then
        success "ssh-agent.socket habilitado."
        count_ok
    else
        warn_msg "No se pudo habilitar ssh-agent.socket (puede que ya esté activo)."
        count_skip
    fi
else
    print_log -y "[SSH-AGENT] " -b " :: " "Simulación: Se omite la habilitación del socket de ssh-agent"
    count_skip
fi

info "Configurando AddKeysToAgent en ~/.ssh/config..."
if [[ ${flg_DryRun} -ne 1 ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    if [ ! -f "$HOME/.ssh/config" ]; then
        echo -e "Host *\n    AddKeysToAgent yes" > "$HOME/.ssh/config"
        chmod 600 "$HOME/.ssh/config"
        success "Archivo ~/.ssh/config creado con AddKeysToAgent."
    elif ! grep -q "AddKeysToAgent" "$HOME/.ssh/config"; then
        echo -e "\nHost *\n    AddKeysToAgent yes" >> "$HOME/.ssh/config"
        success "AddKeysToAgent agregado a ~/.ssh/config existente."
    else
        info "AddKeysToAgent ya está configurado en ~/.ssh/config."
    fi
    count_ok
else
    print_log -y "[SSH-CONFIG] " -b " :: " "Simulación: Se omite la configuración de ~/.ssh/config"
    count_skip
fi

# ==============================================================================
# 4. Instalar plugin de dotbare para oh-my-zsh
# ==============================================================================
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/dotbare" ]]; then
    step "Instalando plugin dotbare para oh-my-zsh"
    if (( flg_DryRun != 1 )); then
      if retry 3 git clone https://github.com/kazhala/dotbare.git "$HOME/.oh-my-zsh/custom/plugins/dotbare" 2>/dev/null; then
        success "Plugin dotbare instalado correctamente."
        count_ok
      else
        error_msg "No se pudo clonar el plugin dotbare."
        count_fail
      fi
    else
      print_log -y "[DOTBARE] " -b " :: " "Simulación: Se omite la clonación del plugin dotbare"
      count_skip
    fi
  else
    info "Plugin dotbare ya está instalado en oh-my-zsh."
    count_skip
  fi
fi

# ==============================================================================
# 5. Instalar nvim-lazyman (Opcional - Paso tardado)
# ==============================================================================
if [[ ! -d "$HOME/.config/nvim-Lazyman" ]]; then
  if [[ ${flg_DryRun} -ne 1 ]]; then
    prompt_timer 10 "Quieres instalar nvim-lazyman ahora? (Paso tardado) [y/N]"
    if [[ "${PROMPT_INPUT,,}" == "y" ]]; then
      step "Instalando nvim-lazyman"

      run_with_status "Instalando neovim" sudo pacman -S --needed --noconfirm neovim

      if retry 3 git clone https://github.com/doctorfree/nvim-lazyman "$HOME/.config/nvim-Lazyman" 2>/dev/null; then
        "$HOME/.config/nvim-Lazyman/lazyman.sh"
        success "nvim-lazyman instalado correctamente."
        count_ok
      else
        error_msg "No se pudo clonar nvim-lazyman."
        count_fail
      fi
    else
      info "Instalación omitida. Puedes instalarlo manualmente ejecutando:"
      print_log -y "  " "git clone https://github.com/doctorfree/nvim-lazyman \$HOME/.config/nvim-Lazyman && \$HOME/.config/nvim-Lazyman/lazyman.sh"
      count_skip
    fi
  else
    print_log -y "[LAZYMAN] " -b " :: " "Simulación: Se omite la consulta/instalación de nvim-lazyman"
    count_skip
  fi
else
  info "nvim-lazyman ya está instalado."
  count_skip
fi

# ==============================================================================
# Resumen final
# ==============================================================================
print_summary "Final Config"
