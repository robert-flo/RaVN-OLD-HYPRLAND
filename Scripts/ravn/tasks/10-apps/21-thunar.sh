#!/usr/bin/env bash
# ─── RaVN Task: Uninstall Thunar ────────────────────────────────────────────

# shellcheck disable=SC2034
PACKAGE="thunar"
DESCRIPTION="Uninstall Thunar file manager and plugins"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  ! command -v thunar &> /dev/null
}

install() {
  sudo pacman -Rns --noconfirm thunar thunar-archive-plugin thunar-volman thunar-media-tags-plugin
}
