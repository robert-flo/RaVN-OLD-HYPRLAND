#!/usr/bin/env bash
# ─── RaVN Task: pnpm Package Manager ────────────────────────────────────────

# shellcheck disable=SC2034
CLI_COMMAND="pnpm"
# shellcheck disable=SC2034
CLI_INSTALLER="mise"
# mise's Aqua backend installs the native GitHub release with attestations.
# shellcheck disable=SC2034
CLI_MISE_TOOL="aqua:pnpm/pnpm"
# shellcheck disable=SC2034
CLI_VERIFY_ARGS=(--version)

ravn_cli_task
