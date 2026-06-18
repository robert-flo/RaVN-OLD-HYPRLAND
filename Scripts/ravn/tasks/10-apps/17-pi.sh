#!/usr/bin/env bash
# ─── RaVN Task: Pi Coding Agent ──────────────────────────────────────────────
# Migrated from installers/02-tui/pi.sh
# Requires: omarchy-npx-install (provided by tasks/core/01-omarchy.sh)

PACKAGE="pi"
DESCRIPTION="Earendil Pi Coding Agent via omarchy-npx-install"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  command -v pi &>/dev/null
}

install() {
  local npx_installer="${HOME}/.local/share/omarchy/bin/omarchy-npx-install"
  if [[ -x $npx_installer ]]; then
    "$npx_installer" "@earendil-works/pi-coding-agent" "pi"
  else
    echo "Error: omarchy-npx-install not found at $npx_installer" >&2
    return 1
  fi
}
