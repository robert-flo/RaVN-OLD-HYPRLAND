#!/usr/bin/env bash
# ─── RaVN Task: Command Code ──────────────────────────────────────────────────
# Installs/updates the command-code npm package globally.

# shellcheck disable=SC2034
PACKAGE="command-code"
DESCRIPTION="Command Code - Coding agent that learns your taste"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  command -v command-code &>/dev/null
}

install() {
  if ! command -v npm &>/dev/null; then
    echo "Error: npm not found" >&2
    return 1
  fi
  npm i -g command-code@latest
}
