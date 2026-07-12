#!/usr/bin/env bash
# ─── RaVN Task: Antigravity CLI ────────────────────────────────────────────

# shellcheck disable=SC2034
CLI_COMMAND="agy"
# shellcheck disable=SC2034
CLI_INSTALLER="mise"
# shellcheck disable=SC2034
CLI_MISE_TOOL="aqua:google-antigravity/antigravity-cli"
# shellcheck disable=SC2034
CLI_VERIFY_ARGS=(--version)

ravn_cli_task
