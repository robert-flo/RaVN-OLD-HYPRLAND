#!/usr/bin/env bash
# ─── RaVN Task: Omarchy ─────────────────────────────────────────────────────
# Installs Omarchy packages and configures Walker + Elephant integration.
# The [omarchy] repository itself is configured earlier (before install_pkg.sh)
# by the omarchy-repo task; this task uses the shared helper as a fallback so it
# remains safe to run standalone.

# shellcheck disable=SC2034
PACKAGE="omarchy"
DESCRIPTION="Omarchy packages and Walker/Elephant integration"
CATEGORY="core"
DEPENDS=()
INTERACTIVE=false

flg_DryRun=${flg_DryRun:-0}

# shellcheck disable=SC1091
source "${RAVN_DIR}/lib/omarchy.sh"

# check — return 0 if all Omarchy packages and the repo are already configured.
check() {
  omarchy_repo_is_configured &&
    pkg_installed tobi-try &&
    pkg_installed omarchy-walker
}

# install — ensure the repo is present, install Omarchy packages, and set up
# Walker + Elephant.
install() {
  # Fallback: configure the repo if this task is run without the early phase.
  if ! omarchy_repo_is_configured; then
    setup_omarchy_repo
  fi

  step "Installing Omarchy packages"

  # Install Omarchy packages.
  run_with_status "Installing tobi-try" \
    sudo pacman -S --needed --noconfirm tobi-try

  run_with_status "Installing omarchy-walker" \
    sudo pacman -S --needed --noconfirm omarchy-walker
}

# after — configure Walker and Elephant integration.
after() {
  info "Configuring Walker and Elephant integration..."

  mkdir -p "${HOME}/.config/autostart"
  mkdir -p "${HOME}/.config/systemd/user/app-walker@autostart.service.d"
  mkdir -p "${HOME}/.config/elephant/menus"

  cp "${OMARCHY_DEST}/default/walker/walker.desktop" "${HOME}/.config/autostart/"
  cp "${OMARCHY_DEST}/default/walker/restart.conf" "${HOME}/.config/systemd/user/app-walker@autostart.service.d/"

  ln -snf "${OMARCHY_DEST}/default/elephant/omarchy_themes.lua" "${HOME}/.config/elephant/menus/omarchy_themes.lua"
  ln -snf "${OMARCHY_DEST}/default/elephant/omarchy_background_selector.lua" "${HOME}/.config/elephant/menus/omarchy_background_selector.lua"
  ln -snf "${OMARCHY_DEST}/default/elephant/omarchy_unlocks.lua" "${HOME}/.config/elephant/menus/omarchy_unlocks.lua"

  # Create the pacman hook to restart Walker after upgrades.
  if ((flg_DryRun == 1)); then
    info "[dry-run] Would create /etc/pacman.d/hooks/walker-restart.hook"
  else
    sudo mkdir -p /etc/pacman.d/hooks
    sudo tee /etc/pacman.d/hooks/walker-restart.hook > /dev/null << EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = walker
Target = walker-debug
Target = elephant*

[Action]
Description = Restarting Walker services after system update
When = PostTransaction
Exec = ${OMARCHY_DEST}/bin/omarchy-restart-walker
EOF
  fi

  success "Omarchy integration configured"
}
