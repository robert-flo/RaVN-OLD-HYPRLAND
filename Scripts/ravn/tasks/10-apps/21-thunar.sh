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
  command -v thunar &> /dev/null
}

install() {
   sudo pacman -Rns thunar thunar-archive-plugin  thunar-volman thunar-media-tags-plugin
}
