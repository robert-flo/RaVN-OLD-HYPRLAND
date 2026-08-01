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

assert_contains() {
  grep -Fq "$2" <<< "$1" || {
    printf 'FAIL: expected output to contain: %s\n' "$2" >&2
    exit 1
  }
}

discover_tasks > /dev/null
RAVN_UI_EFFECTIVE=bash
bash_selection_output=$(printf '1\n3,4\n' | {
  select_task_family
  select_tasks_for_family
  printf 'SELECTED:%s\n' "$(
                            IFS=,
                                   printf '%s' "${SELECTED_TASKS[*]}"
  )"
})
assert_contains "$bash_selection_output" "CLI Tools"
assert_contains "$bash_selection_output" "3     codex · CLI Tools"
assert_contains "$bash_selection_output" "SELECTED:codex,copilot"

gum() {
  if [[ $* == *--no-limit* ]]; then
    printf '3  %s  codex · CLI Tools\n4  %s  copilot · CLI Tools\n' "$ICON_UI_TERMINAL" "$ICON_UI_TERMINAL"
  else
    printf '1  %s  CLI Tools · 13 tasks\n' "$ICON_UI_TERMINAL"
  fi
}

export RAVN_UI_EFFECTIVE=gum
gum_selection_output=$(
  select_task_family
  select_tasks_for_family
  printf 'SELECTED:%s\n' "$(
                            IFS=,
                                   printf '%s' "${SELECTED_TASKS[*]}"
  )"
)
assert_contains "$gum_selection_output" "SELECTED:codex,copilot"

export RAVN_UI_EFFECTIVE=bash
if printf '\033\n' | select_task_family > /dev/null 2>&1; then
  printf 'FAIL: Escape did not return from task-family selection\n' >&2
  exit 1
fi

# shellcheck disable=SC2034 # Consumed by select_tasks_for_family from the sourced runner.
SELECTED_TASK_FAMILY=cli-tools
if printf '\033\n' | select_tasks_for_family > /dev/null 2>&1; then
  printf 'FAIL: Escape did not return from task selection\n' >&2
  exit 1
fi

if printf '1,999\n' | select_tasks_for_family > /dev/null 2>&1; then
  printf 'FAIL: invalid task selection was partially accepted\n' >&2
  exit 1
fi

# shellcheck disable=SC2034 # Consumed by select_task_family through the sourced runner.
TASKS=()
if select_task_family > /tmp/category-empty-output 2>&1; then
  printf 'FAIL: empty task inventory opened a selector\n' >&2
  exit 1
fi
assert_contains "$(< /tmp/category-empty-output)" "No tasks available"

printf 'PASS: category and task selection\n'
