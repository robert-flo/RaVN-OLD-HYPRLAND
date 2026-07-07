#!/usr/bin/env bash
# ─── RaVN Task: Zero CLI ──────────────────────────────────────────────────
# Installs/updates @gitlawb/zero globally via npm and ensures a TUI launcher
# entry exists.

# shellcheck disable=SC2034
PACKAGE="zero"
DESCRIPTION="Zero - terminal coding agent from Gitlawb"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  command -v zero &>/dev/null
}

install() {
  if ! command -v npm &>/dev/null; then
    echo "Error: npm not found" >&2
    return 1
  fi
  npm i -g @gitlawb/zero@latest
}

after() {
  local launcher_name="Zero TUI"

  # Skip if launcher already exists
  if [[ -f ${HOME}/.local/share/applications/${launcher_name}.desktop ]]; then
    return 0
  fi

  info "TUI launcher for Zero not found — creating"

  # Create the launcher using ravn_tui_install (vendored in launchers/bin)
  if command -v ravn_tui_install &>/dev/null; then
    ravn_tui_install "$launcher_name" "zero" "tile"
  else
    local launchers_dir
    launchers_dir="$(cd "$(dirname "$(realpath "$0")")/../../launchers" && pwd)"
    if [[ -x ${launchers_dir}/bin/ravn_tui_install ]]; then
      "${launchers_dir}/bin/ravn_tui_install" \
        "$launcher_name" "zero" "tile"
    fi
  fi
}
