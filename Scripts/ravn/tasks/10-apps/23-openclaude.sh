#!/usr/bin/env bash
# ─── RaVN Task: OpenClaude CLI ─────────────────────────────────────────────
# Installs/updates the openclaude npm package globally and ensures a TUI
# launcher entry exists.

# shellcheck disable=SC2034
PACKAGE="openclaude"
DESCRIPTION="OpenClaude - open-source coding agent CLI for any model"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  command -v openclaude &>/dev/null
}

install() {
  if ! command -v npm &>/dev/null; then
    echo "Error: npm not found" >&2
    return 1
  fi
  npm i -g @gitlawb/openclaude@latest
}

after() {
  local launcher_name="OpenClaude TUI"

  # Skip if launcher already exists
  if [[ -f ${HOME}/.local/share/applications/${launcher_name}.desktop ]]; then
    return 0
  fi

  info "TUI launcher for OpenClaude not found — creating"

  local icon_dir="${HOME}/.local/share/applications/icons"
  mkdir -p "$icon_dir"

  # Reuse Claude AI icon as fallback
  if [[ ! -f ${icon_dir}/OpenClaude.png && -f ${icon_dir}/Claude\ AI.png ]]; then
    cp "${icon_dir}/Claude AI.png" "${icon_dir}/OpenClaude.png"
  fi

  # Create the launcher using ravn_tui_install (vendored in launchers/bin)
  if command -v ravn_tui_install &>/dev/null; then
    ravn_tui_install "$launcher_name" "openclaude" "tile" "${icon_dir}/OpenClaude.png"
  else
    # Fallback: find the launchers dir relative to script location
    local launchers_dir
    launchers_dir="$(cd "$(dirname "$(realpath "$0")")/../../launchers" && pwd)"
    if [[ -x ${launchers_dir}/bin/ravn_tui_install ]]; then
      "${launchers_dir}/bin/ravn_tui_install" \
        "$launcher_name" "openclaude" "tile" "${icon_dir}/OpenClaude.png"
    fi
  fi
}
