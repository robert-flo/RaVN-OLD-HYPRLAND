#!/usr/bin/env bash
# ─── RaVN Task: SSH Agent Socket ─────────────────────────────────────────────
# Extracted from install_fnl.sh (lines 256-268)
# Enables the ssh-agent.socket systemd user unit.

# shellcheck disable=SC2034
PACKAGE="ssh-agent"
DESCRIPTION="Enable ssh-agent.socket for the current user"
CATEGORY="system"
DEPENDS=()
INTERACTIVE=false

check() {
  # Skip if ssh-agent.socket is already enabled
  systemctl --user is-enabled ssh-agent.socket &> /dev/null
}

install() {
  info "Habilitando socket de ssh-agent para el usuario..."

  if systemctl --user enable --now ssh-agent.socket 2> /dev/null; then
    success "ssh-agent.socket habilitado."
  else
    warn_msg "No se pudo habilitar ssh-agent.socket (puede que ya esté activo)."
  fi
}
