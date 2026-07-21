#!/usr/bin/env bash
# ─── RaVN Task: Oh My Pi Coding Agent ───────────────────────────────────────

# shellcheck disable=SC2034
CLI_COMMAND="omp"
# shellcheck disable=SC2034
CLI_INSTALLER="mise"
# mise's GitHub backend validates release checksums and attestations.
# shellcheck disable=SC2034
CLI_MISE_TOOL="github:can1357/oh-my-pi"
# shellcheck disable=SC2034
CLI_VERIFY_ARGS=(--version)

ravn_cli_task
