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

output=""
RAVN_UI_EFFECTIVE=bash
output=$(printf 'q\n' | run_menu 2>&1)

if grep -q 'readonly variable' <<< "$output"; then
  printf 'FAIL: task discovery exposed readonly-variable errors\n' >&2
  exit 1
fi

grep -q "Verify current configuration" <<< "$output"
grep -q "Run full setup" <<< "$output"
grep -q "Run integration test" <<< "$output"
grep -q "Reset selected tasks" <<< "$output"
grep -q "RaVN Task Runner" <<< "$output"
grep -q "Choose an action" <<< "$output"
grep -q "Exit" <<< "$output"
if grep -Eiq 'deshabilitado|instalación|verificación|opción|cancelado|tarea no encontrada' <<< "$output"; then
  printf 'FAIL: interactive menu exposed non-English text\n' >&2
  exit 1
fi

if printf '\033\n' | read_task_runner_main_menu_choice > /dev/null 2>&1; then
  printf 'FAIL: Escape did not return from the main menu\n' >&2
  exit 1
fi
if read_task_runner_main_menu_choice < /dev/null > /dev/null 2>&1; then
  printf 'FAIL: EOF was accepted as a main-menu choice\n' >&2
  exit 1
fi

# shellcheck disable=SC2329 # Invoked indirectly by read_task_runner_main_menu_choice.
gum() {
  printf 'q  %s  Exit\n' "$ICON_UI_CLOSE"
}

gum_output=""
export RAVN_UI_EFFECTIVE=gum
gum_output=$(run_menu)
grep -q "RaVN Task Runner" <<< "$gum_output"
grep -q "Choose an action" <<< "$gum_output"

gum() {
  return 1
}

if read_task_runner_main_menu_choice; then
  printf 'FAIL: gum cancellation was treated as a menu choice\n' >&2
  exit 1
fi

noninteractive_output=$(bash "${RAVN_DIR}/setup.sh" 2>&1 || true)
grep -q "No subcommand in non-interactive mode" <<< "$noninteractive_output"

printf 'PASS: task menu\n'
