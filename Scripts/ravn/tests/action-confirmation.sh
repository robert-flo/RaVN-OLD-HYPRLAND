#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

# shellcheck disable=SC1091
source "${RAVN_DIR}/global_fn.sh"
for fw in "${RAVN_DIR}"/framework/*.sh; do
  # shellcheck disable=SC1090
  source "$fw"
done

RAVN_UI_EFFECTIVE=bash
if ! printf 'y\n' | confirm_task_action "Run selected tasks"; then
  printf 'FAIL: Bash confirmation rejected yes\n' >&2
  exit 1
fi
if printf 'n\n' | confirm_task_action "Run selected tasks"; then
  printf 'FAIL: Bash confirmation accepted no\n' >&2
  exit 1
fi

gum() { return 0; }
export RAVN_UI_EFFECTIVE=gum
confirm_task_action "Run selected tasks"

_install_ok=1
_install_fail=1
_install_skip=1
_install_ok_list=(codex)
_install_fail_list=(firewall)
_install_skip_list=(copilot)
summary=$(print_task_results)
grep -q "Task Results Summary" <<< "$summary"
grep -q "Total" <<< "$summary"

printf 'PASS: action confirmation and summary\n'
