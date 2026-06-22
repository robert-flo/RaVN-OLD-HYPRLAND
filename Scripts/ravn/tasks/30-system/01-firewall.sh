#!/usr/bin/env bash
# ─── RaVN Task: Firewall (UFW) ──────────────────────────────────────────────
# Extracted from install_fnl.sh::setup_firewall()
# Configures UFW firewall rules for LocalSend (port 53317).

# shellcheck disable=SC2034
PACKAGE="firewall"
DESCRIPTION="UFW firewall rules for LocalSend"
CATEGORY="system"
DEPENDS=()
INTERACTIVE=false

check() {
  # Skip if ufw is not installed
  if ! command -v ufw &> /dev/null; then
    return 0
  fi
  # Skip if ufw service is not active
  if ! systemctl is-active --quiet ufw; then
    return 0
  fi
  # Skip if rules already exist
  if sudo ufw status 2> /dev/null | grep -q "53317"; then
    return 0
  fi
  return 1
}

install() {
  step "Configurando reglas de firewall UFW para LocalSend"

  info "Configurando reglas de firewall UFW para LocalSend..."

  # Validamos si el servicio ufw está activo
  if ! systemctl is-active --quiet ufw; then
    warn_msg "UFW está instalado pero el servicio no está activo."
    return 0
  fi

  sudo ufw allow 53317/udp
  sudo ufw allow 53317/tcp

  success "Reglas de firewall configuradas correctamente para localsend."
}
