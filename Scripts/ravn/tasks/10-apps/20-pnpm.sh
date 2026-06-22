#!/usr/bin/env bash
# ─── RaVN Task: pnpm Package Manager ──────────────────────────────────────────
# Requires: mise (provided by system package manager)

# shellcheck disable=SC2034
PACKAGE="pnpm"
DESCRIPTION="pnpm Package Manager via mise"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  local mise_shim_dir="${HOME}/.local/share/mise/shims"
  if [[ -x ${mise_shim_dir}/pnpm ]]; then
    return 0
  fi
  command -v pnpm &> /dev/null
}

install() {
  if ! command -v mise &> /dev/null; then
    echo "Error: mise not found" >&2
    return 1
  fi
  mise use -g pnpm@latest
}
