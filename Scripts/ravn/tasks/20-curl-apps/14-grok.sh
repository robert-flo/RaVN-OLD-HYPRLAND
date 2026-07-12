#!/usr/bin/env bash
# ─── RaVN Task: Grok CLI ────────────────────────────────────────────────────

# shellcheck disable=SC2034
CLI_COMMAND="grok"
# shellcheck disable=SC2034
CLI_INSTALLER="upstream"
# shellcheck disable=SC2034
CLI_INSTALL_URL="https://x.ai/cli/install.sh"
# shellcheck disable=SC2034
CLI_VERSION_ARGS=(version)
# shellcheck disable=SC2034
CLI_UPDATE_CHECK_ARGS=(update --check)
# shellcheck disable=SC2034
CLI_UPDATE_ARGS=(update)
# The vendor installer writes ~/.grok; isolate that home and direct its binary
# output into the task-owned installation directory.
# shellcheck disable=SC2034
CLI_INSTALL_DIR_ENV="GROK_BIN_DIR"

ravn_cli_task
