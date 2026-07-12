#!/usr/bin/env bash
# ─── RaVN Framework v1 — Retry Helpers ──────────────────────────────────────
# The retry() function with exponential backoff is defined in global_fn.sh.
# This file exists for self-documentation and to verify availability.
#
# Usage:
#   retry <max_tries> <command> [args...]
#
# Example:
#   retry 3 git clone https://github.com/user/repo /tmp/repo
#
# Behavior:
#   Attempts the command up to max_tries times with exponential backoff
#   (2s, 4s, 8s, ...). Returns 0 on first success, 1 after exhausting retries.

# Verify that retry() is available from global_fn.sh
if ! declare -f retry &>/dev/null; then
  echo "Error: retry() not found. Ensure global_fn.sh is sourced first." >&2
  # shellcheck disable=SC2317
  return 1 2>/dev/null || exit 1
fi
