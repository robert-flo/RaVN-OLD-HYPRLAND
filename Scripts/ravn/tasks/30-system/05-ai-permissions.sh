#!/usr/bin/env bash
# ─── RaVN Task: AI System Permissions ─────────────────────────────────────────
# Configures system-wide permissions, groups, polkit rules, sudo overrides,
# and systemd limits to allow unrestricted execution for local development.

# shellcheck disable=SC2034
PACKAGE="ai-permissions"
DESCRIPTION="System-wide permissions and overrides for local development"
CATEGORY="system"
DEPENDS=()
INTERACTIVE=false

check() {
  # 1. Check groups
  if ! id -nG "$USER" | grep -qw "systemd-journal" || ! id -nG "$USER" | grep -qw "input"; then
    return 1
  fi

  # 2. Check polkit rules file
  if [[ ! -f /etc/polkit-1/rules.d/99-wheel-nopasswd.rules ]]; then
    return 1
  fi

  # 3. Check sudoers override file
  if [[ ! -f /etc/sudoers.d/99-ai-tools ]] || [[ ! -f /etc/sudoers.d/hermes-nopasswd ]]; then
    return 1
  fi

  # 4. Check systemd system limits
  if [[ ! -f /etc/systemd/system.conf.d/99-limits.conf ]]; then
    return 1
  fi

  # 5. Check user service override
  if [[ ! -f /etc/systemd/system/user@.service.d/override.conf ]]; then
    return 1
  fi

  return 0
}

install() {
  step "Configurando permisos del sistema para herramientas de IA"

  # 1. Add user to groups
  info "Añadiendo usuario $USER a los grupos systemd-journal e input..."
  if ! id -nG "$USER" | grep -qw "systemd-journal"; then
    sudo usermod -aG systemd-journal "$USER"
  fi
  if ! id -nG "$USER" | grep -qw "input"; then
    sudo usermod -aG input "$USER"
  fi

  # 2. Create polkit rules
  info "Creando reglas de Polkit en /etc/polkit-1/rules.d/99-wheel-nopasswd.rules..."
  sudo mkdir -p /etc/polkit-1/rules.d
  sudo tee /etc/polkit-1/rules.d/99-wheel-nopasswd.rules > /dev/null << 'EOF'
/* Allow wheel users to execute commands without password */
polkit.addRule(function(action, subject) {
  if (subject.isInGroup("wheel")) {
    // Allow system operations without password
    if (action.id == "org.freedesktop.systemd1.manage-units" ||
        action.id == "org.freedesktop.NetworkManager.network-control" ||
        action.id == "org.freedesktop.login1.power-off" ||
        action.id == "org.freedesktop.login1.reboot") {
      return polkit.Result.YES;
    }
  }
});
EOF

  # 3. Create sudoers override
  info "Configurando excepciones de sudo en /etc/sudoers.d/99-ai-tools..."
  sudo mkdir -p /etc/sudoers.d
  sudo tee /etc/sudoers.d/99-ai-tools > /dev/null << 'EOF'
# Keep important environment variables
Defaults env_keep += "SSH_AUTH_SOCK"
Defaults env_keep += "NIX_PATH"
# Avoid warnings: use the target user's (root) HOME when running sudo
Defaults always_set_home

# Remember password for 60 minutes after entering it
Defaults timestamp_timeout=60

# One password applies to all open terminals
Defaults !tty_tickets

# Don't show warning message every time
Defaults !lecture

# Allow use_pty to prevent "no new privileges"
Defaults use_pty
EOF
  sudo chmod 0440 /etc/sudoers.d/99-ai-tools

  info "Configurando excepciones de sudo para hermes en /etc/sudoers.d/hermes-nopasswd..."
  sudo tee /etc/sudoers.d/hermes-nopasswd > /dev/null << 'EOF'
dominus ALL=(ALL) NOPASSWD: ALL
EOF
  sudo chmod 0440 /etc/sudoers.d/hermes-nopasswd
  if ! sudo visudo -c -f /etc/sudoers.d/hermes-nopasswd > /dev/null 2>&1; then
    error_msg "Error de sintaxis en /etc/sudoers.d/hermes-nopasswd. Revirtiendo..."
    sudo rm -f /etc/sudoers.d/hermes-nopasswd
    return 1
  fi

  # 4. Create systemd limits
  info "Configurando DefaultTasksMax=infinity en /etc/systemd/system.conf.d/99-limits.conf..."
  sudo mkdir -p /etc/systemd/system.conf.d
  sudo tee /etc/systemd/system.conf.d/99-limits.conf > /dev/null << 'EOF'
[Manager]
DefaultTasksMax=infinity
EOF

  # 5. Create user@ service override
  info "Configurando override para user@.service..."
  sudo mkdir -p /etc/systemd/system/user@.service.d
  sudo tee /etc/systemd/system/user@.service.d/override.conf > /dev/null << 'EOF'
[Service]
Delegate=yes
PrivateDevices=no
PrivateTmp=no
NoNewPrivileges=no
EOF

  # Reload systemd manager configurations
  info "Recargando configuración de systemd..."
  sudo systemctl daemon-reload

  success "Permisos del sistema para herramientas de IA configurados correctamente."
}
