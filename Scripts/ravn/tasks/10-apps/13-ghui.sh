#!/usr/bin/env bash
# ─── RaVN Task: GHUI ────────────────────────────────────────────────────────
# Migrated from installers/02-tui/ghui.sh
# Requires: omarchy-npx-install (provided by tasks/core/01-omarchy.sh)

# shellcheck disable=SC2034
PACKAGE="ghui"
DESCRIPTION="GHUI TUI via omarchy-npx-install"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  command -v ghui &> /dev/null
}

install() {
  local npx_installer="${HOME}/.local/share/omarchy/bin/omarchy-npx-install"
  if [[ -x $npx_installer ]]; then
    "$npx_installer" "@kitlangton/ghui" "ghui"
  else
    echo "Error: omarchy-npx-install not found at $npx_installer" >&2
    return 1
  fi
}
