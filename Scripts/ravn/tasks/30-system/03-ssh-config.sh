#!/usr/bin/env bash
# ─── RaVN Task: SSH Config ──────────────────────────────────────────────────
# Extracted from install_fnl.sh (lines 270-288)
# Ensures AddKeysToAgent is configured in ~/.ssh/config.

PACKAGE="ssh-config"
DESCRIPTION="Configure AddKeysToAgent in ~/.ssh/config"
CATEGORY="system"
DEPENDS=()
INTERACTIVE=false

check() {
  # Skip if AddKeysToAgent is already configured
  [[ -f "$HOME/.ssh/config" ]] && grep -q "AddKeysToAgent" "$HOME/.ssh/config"
}

install() {
  info "Configurando AddKeysToAgent en ~/.ssh/config..."

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
}
