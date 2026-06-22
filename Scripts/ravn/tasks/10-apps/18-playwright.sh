#!/usr/bin/env bash
# ─── RaVN Task: Playwright CLI ───────────────────────────────────────────────
# Migrated from installers/02-tui/playwright.sh
# Requires: omarchy-npx-install (provided by tasks/core/01-omarchy.sh)

# shellcheck disable=SC2034
PACKAGE="playwright-cli"
DESCRIPTION="Playwright CLI via omarchy-npx-install"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  command -v playwright-cli &> /dev/null
}

install() {
  local npx_installer="${HOME}/.local/share/omarchy/bin/omarchy-npx-install"
  if [[ -x $npx_installer ]]; then
    "$npx_installer" "playwright" "playwright-cli"
  else
    echo "Error: omarchy-npx-install not found at $npx_installer" >&2
    return 1
  fi
}
