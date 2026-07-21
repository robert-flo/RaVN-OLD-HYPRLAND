#!/usr/bin/env bash
# shellcheck disable=SC2034
# ─── RaVN Task: Oh My Pi Coding Agent ─────────────────────────────────────────
# Requires: mise (provided by system package manager)

PACKAGE="pi"
DESCRIPTION="Oh My Pi Coding Agent via mise"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  local mise_shim_dir="${HOME}/.local/share/mise/shims"
  if [[ -x ${mise_shim_dir}/omp || -x ${mise_shim_dir}/pi ]]; then
    return 0
  fi
  command -v omp &>/dev/null || command -v pi &>/dev/null
}

install() {
  if ! command -v mise &>/dev/null; then
    echo "Error: mise not found" >&2
    return 1
  fi
  mise use -g github:can1357/oh-my-pi
}
