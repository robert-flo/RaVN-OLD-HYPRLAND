#!/usr/bin/env bash
# ─── RaVN Task: Herdr Dev Workspace Bootstrap ────────────────────────────────
# Installs a bootstrap script that creates a Herdr dev workspace with agents,
# tools, and editor panes on demand.
# Config template lives in Configs/.config/herdr/config.toml (restore_cfg.psv).

# shellcheck disable=SC2034
PACKAGE="herdr-bootstrap"
DESCRIPTION="Herdr dev workspace bootstrap script"
CATEGORY="apps"
DEPENDS=("herdr")
INTERACTIVE=false

BOOTSTRAP_BIN="${HOME}/.local/bin/herdr-dev-session"

check() {
  [[ -x $BOOTSTRAP_BIN ]]
}

install() {
  cat >"$BOOTSTRAP_BIN" <<'SCRIPT'
#!/usr/bin/env bash
# herdr-dev-session — Bootstrap a dev workspace in Herdr
# Usage: herdr-dev-session [workspace-label] [--cwd PATH]
set -Eeuo pipefail

LABEL="${1:-dev}"
CWD="${2:-$PWD}"

if ! command -v herdr &>/dev/null; then
  echo "Error: herdr not running or not in PATH" >&2
  exit 1
fi

echo "Creating workspace '$LABEL' in $CWD..."

ws=$(herdr workspace create --cwd "$CWD" --label "$LABEL" --no-focus | jq -r '.workspace.workspace_id')
if [[ -z "$ws" || "$ws" == "null" ]]; then
  echo "Error: could not create workspace" >&2
  exit 1
fi

agents_tab=$(herdr tab create --workspace "$ws" --label "agents" --cwd "$CWD" --no-focus | jq -r '.tab.tab_id')
tools_tab=$(herdr tab create --workspace "$ws" --label "tools"   --cwd "$CWD" --no-focus | jq -r '.tab.tab_id')
editor_tab=$(herdr tab create --workspace "$ws" --label "editor"  --cwd "$CWD" --no-focus | jq -r '.tab.tab_id')

# Tab: agents — opencode + cmd side-by-side
herdr tab focus "$agents_tab"
current_id=$(herdr pane current | jq -r '.pane_id')
herdr pane split "$current_id" --direction right --cwd "$CWD" 2>/dev/null
herdr pane run "$current_id" "opencode" 2>/dev/null &
right_id=$(herdr tab get "$agents_tab" | jq -r '.panes[] | select(.pane_id != "'"$current_id"'") | .pane_id')
herdr pane run "$right_id" "cmd" 2>/dev/null &

# Tab: tools — lazygit
herdr tab focus "$tools_tab"
herdr pane run "$(herdr pane current | jq -r '.pane_id')" "lazygit" 2>/dev/null &

# Tab: editor — nvim
herdr tab focus "$editor_tab"
herdr pane run "$(herdr pane current | jq -r '.pane_id')" "nvim" 2>/dev/null &

herdr workspace focus "$ws" 2>/dev/null
echo "Workspace '$LABEL' ready — agents, tools, editor tabs created"
SCRIPT
  chmod +x "$BOOTSTRAP_BIN"
}

after() {
  # Reload herdr config if running so keybinding is active immediately
  if command -v herdr &>/dev/null; then
    herdr server reload-config 2>/dev/null || true
  fi
}
