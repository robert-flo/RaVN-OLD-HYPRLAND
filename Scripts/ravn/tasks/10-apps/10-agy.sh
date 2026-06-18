#!/usr/bin/env bash
# ─── RaVN Task: AGY CLI ─────────────────────────────────────────────────────
# Migrated from installers/02-tui/agy.sh

PACKAGE="agy"
DESCRIPTION="Google Antigravity CLI"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  command -v agy &>/dev/null
}

install() {
  curl -fsSL https://antigravity.google/cli/install.sh | bash
}
