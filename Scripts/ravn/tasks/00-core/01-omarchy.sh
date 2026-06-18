#!/usr/bin/env bash
# ─── RaVN Task: Omarchy ─────────────────────────────────────────────────────
# Extracted from install_fnl.sh::setup_omarchy()
# Clones/updates Omarchy, integrates [omarchy] repo into pacman.conf,
# installs tobi-try + omarchy-walker, configures Walker + Elephant.

PACKAGE="omarchy"
DESCRIPTION="Omarchy desktop framework integration"
CATEGORY="core"
DEPENDS=()
INTERACTIVE=false

check() {
  # Skip if [omarchy] repo is already in pacman.conf
  grep -q '^\[omarchy\]' /etc/pacman.conf 2>/dev/null
}

install() {
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
  sudo pacman -Sy --noconfirm --needed git

  # 2. Clonar/Actualizar e inicializar el repositorio
  clone_or_update_repo "Omarchy" "$omarchy_repo" "$HOME/.local/share/omarchy" "$omarchy_ref"

  # 3. Integrar el repositorio [omarchy] en /etc/pacman.conf sin pisar la configuración actual
  info "Integrando el repositorio [omarchy] en /etc/pacman.conf..."

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
  sudo pacman -Fy

  sudo pacman -S --needed --noconfirm tobi-try
  sudo pacman -S --needed --noconfirm omarchy-walker

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
}
