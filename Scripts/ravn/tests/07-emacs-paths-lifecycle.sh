#!/usr/bin/env bash
set -uo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
root=$(mktemp -d "${TMPDIR:-/tmp}/ravn-emacs-paths-test.XXXXXX")
trap 'rm -rf "$root"' EXIT

export HOME="$root"

# shellcheck disable=SC1090,SC1091
source "$RAVN_DIR/tasks/90-system/07-emacs-paths.sh"

# ─── Happy path ──────────────────────────────────────────────────────────────
admin_plan
admin_apply
admin_verify
admin_apply
admin_verify
admin_rollback
admin_verify_reset
admin_reset
admin_verify_reset
admin_apply
admin_verify

# ─── Already-satisfied state ────────────────────────────────────────────────
if ! admin_apply; then
  printf 'FAIL: apply returned non-zero on already-satisfied state\n' >&2
  exit 1
fi
admin_verify

# ─── Reset preserves unrelated content ──────────────────────────────────────
touch "$HOME/org/keep-me.org"
admin_reset
if [[ ! -f $HOME/org/keep-me.org ]]; then
  printf 'FAIL: reset removed unrelated file in org/\n' >&2
  exit 1
fi
admin_apply
admin_verify

printf 'PASS: emacs-paths administrative lifecycle\n'
