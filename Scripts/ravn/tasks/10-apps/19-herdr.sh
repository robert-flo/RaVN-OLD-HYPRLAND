#!/usr/bin/env bash
# ─── RaVN Task: Herdr CLI ────────────────────────────────────────────────────
# Requires: curl

# shellcheck disable=SC2034
PACKAGE="herdr"
DESCRIPTION="Herdr CLI installer"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  command -v herdr &> /dev/null
}

install() {
  if ! command -v curl &> /dev/null; then
    echo "Error: curl not found" >&2
    return 1
  fi
  curl -fsSL https://herdr.dev/install.sh | sh
}
