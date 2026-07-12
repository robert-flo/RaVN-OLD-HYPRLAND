#!/usr/bin/env bash
# ─── RaVN Task: Herdr CLI ───────────────────────────────────────────────────

# shellcheck disable=SC2034
CLI_COMMAND="herdr"
# shellcheck disable=SC2034
CLI_INSTALLER="mise"
# mise's GitHub backend validates release checksums and attestations.
# shellcheck disable=SC2034
CLI_MISE_TOOL="github:ogulcancelik/herdr"
# shellcheck disable=SC2034
CLI_VERIFY_ARGS=(--version)

ravn_cli_task
