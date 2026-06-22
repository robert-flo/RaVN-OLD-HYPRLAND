#!/usr/bin/env bash
# ─── RaVN Task: GitHub Copilot CLI ──────────────────────────────────────────
# Migrated from installers/02-tui/copilot.sh
# Requires: omarchy-npx-install (provided by tasks/core/01-omarchy.sh)

# shellcheck disable=SC2034
PACKAGE="copilot"
DESCRIPTION="GitHub Copilot CLI via omarchy-npx-install"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  command -v copilot &> /dev/null
}

install() {
  local npx_installer="${HOME}/.local/share/omarchy/bin/omarchy-npx-install"
  if [[ -x $npx_installer ]]; then
    "$npx_installer" "@github/copilot" "copilot"
  else
    echo "Error: omarchy-npx-install not found at $npx_installer" >&2
    return 1
  fi
}
