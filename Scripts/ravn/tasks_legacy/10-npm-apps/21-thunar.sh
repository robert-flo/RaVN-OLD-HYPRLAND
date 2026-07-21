#!/usr/bin/env bash
# ─── RaVN Task: Uninstall Thunar ────────────────────────────────────────────

# shellcheck disable=SC2034
PACKAGE="thunar"
DESCRIPTION="Uninstall Thunar file manager and plugins"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  ! command -v thunar &>/dev/null
}

install() {
  local pkgs=()
  for pkg in thunar thunar-archive-plugin thunar-volman thunar-media-tags-plugin; do
    if pacman -Qi "$pkg" &>/dev/null; then
      pkgs+=("$pkg")
    fi
  done

  if ((${#pkgs[@]} > 0)); then
    sudo pacman -Rns --noconfirm "${pkgs[@]}"
  fi
}
