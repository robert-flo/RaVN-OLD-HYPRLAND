#!/usr/bin/env bash
# ─── RaVN Task: Qwen Code CLI ──────────────────────────────────────────────
# Installs Qwen Code CLI via the official installer from Alibaba Cloud.

# shellcheck disable=SC2034
PACKAGE="qwen"
DESCRIPTION="Qwen Code - open-source AI coding agent from Alibaba/Qwen"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  command -v qwen &>/dev/null
}

install() {
  if ! command -v curl &>/dev/null; then
    echo "Error: curl not found" >&2
    return 1
  fi
  bash -c "$(curl -fsSL https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen.sh)" -s --source qwenchat
}

after() {
  local launcher_name="Qwen Code TUI"

  # Skip if launcher already exists
  if [[ -f ${HOME}/.local/share/applications/${launcher_name}.desktop ]]; then
    return 0
  fi

  info "TUI launcher for Qwen Code not found — creating"

  if command -v ravn_tui_install &>/dev/null; then
    ravn_tui_install "$launcher_name" "qwen" "tile"
  else
    local launchers_dir
    launchers_dir="$(cd "$(dirname "$(realpath "$0")")/../../launchers" && pwd)"
    if [[ -x ${launchers_dir}/bin/ravn_tui_install ]]; then
      "${launchers_dir}/bin/ravn_tui_install" \
        "$launcher_name" "qwen" "tile"
    fi
  fi
}
