#!/usr/bin/env bash
set -euo pipefail
HOME=$(mktemp -d)
export HOME
# shellcheck disable=SC1090
source "$RAVN_TASK"
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
rm -rf "$HOME"
printf 'PASS: emacs-paths Docker lifecycle\n'
