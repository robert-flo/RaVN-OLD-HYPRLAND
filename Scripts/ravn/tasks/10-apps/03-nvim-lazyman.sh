#!/usr/bin/env bash
# ─── RaVN Task: nvim-lazyman ────────────────────────────────────────────────
# Extracted from install_fnl.sh (lines 317-345)
# Optionally installs nvim-lazyman. Marked INTERACTIVE because it requires
# user confirmation and runs the lazyman.sh interactive setup.

# shellcheck disable=SC2034
PACKAGE="nvim-lazyman"
DESCRIPTION="Neovim configuration manager (paso tardado)"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=true

check() {
  # Skip if already installed
  [[ -d "$HOME/.config/nvim-Lazyman" ]]
}

install() {
  step "Instalando nvim-lazyman"

  sudo pacman -S --needed --noconfirm neovim

  if retry 3 git clone https://github.com/doctorfree/nvim-lazyman \
    "$HOME/.config/nvim-Lazyman" 2> /dev/null; then
    "$HOME/.config/nvim-Lazyman/lazyman.sh"
    success "nvim-lazyman instalado correctamente."
  else
    error_msg "No se pudo clonar nvim-lazyman."
    return 1
  fi
}

after() {
  info "Puedes instalarlo manualmente ejecutando:"
  print_log -y "  " "git clone https://github.com/doctorfree/nvim-lazyman \$HOME/.config/nvim-Lazyman && \$HOME/.config/nvim-Lazyman/lazyman.sh"
}
