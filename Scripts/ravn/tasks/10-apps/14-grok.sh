#!/usr/bin/env bash
# ─── RaVN Task: Grok CLI ────────────────────────────────────────────────────
# Migrated from installers/02-tui/grok.sh

# shellcheck disable=SC2034
PACKAGE="grok"
DESCRIPTION="xAI Grok CLI"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  command -v grok &> /dev/null
}

install() {
  curl -fsSL https://x.ai/cli/install.sh | bash
}
