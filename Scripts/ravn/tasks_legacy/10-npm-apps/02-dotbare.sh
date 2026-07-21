#!/usr/bin/env bash
# ─── RaVN Task: Dotbare Plugin ──────────────────────────────────────────────
# Extracted from install_fnl.sh (lines 293-312)
# Installs the dotbare plugin for oh-my-zsh.

# shellcheck disable=SC2034
PACKAGE="dotbare"
DESCRIPTION="Dotbare plugin for oh-my-zsh"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  # Skip if oh-my-zsh is not installed
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    return 0
  fi
  # Skip if plugin already exists
  [[ -d "$HOME/.oh-my-zsh/custom/plugins/dotbare" ]]
}

install() {
  step "Instalando plugin dotbare para oh-my-zsh"

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "oh-my-zsh no está instalado. Omitiendo plugin dotbare."
    return 0
  fi

  retry 3 git clone https://github.com/kazhala/dotbare.git \
    "$HOME/.oh-my-zsh/custom/plugins/dotbare" 2>/dev/null

  success "Plugin dotbare instalado correctamente."
}
