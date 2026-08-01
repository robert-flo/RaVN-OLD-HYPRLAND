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

empty_dir=$(mktemp -d)
failure_output="$empty_dir/discovery-failure-output"
menu_failure_output="$empty_dir/discovery-menu-failure"
menu_empty_output="$empty_dir/discovery-menu-empty"
trap 'rm -rf "$empty_dir"' EXIT

discover_tasks "$empty_dir"
[[ ${RAVN_DISCOVERY_RESULT:-} == empty ]]
[[ ${#TASKS[@]} -eq 0 ]]

missing_dir="$empty_dir/missing"
if discover_tasks "$missing_dir" > "$failure_output" 2>&1; then
  printf 'FAIL: missing task directory was accepted\n' >&2
  exit 1
fi
[[ ${RAVN_DISCOVERY_RESULT:-} == failed ]]
grep -q 'Task directory not found' "$failure_output"

# shellcheck disable=SC2329 # Invoked indirectly by run_menu.
discover_tasks() {
  RAVN_DISCOVERY_RESULT=failed
  return 1
}
if run_menu > "$menu_failure_output" 2>&1; then
  printf 'FAIL: menu accepted discovery failure\n' >&2
  exit 1
fi
grep -q 'interactive menu cannot start' "$menu_failure_output"

discover_tasks() {
  RAVN_DISCOVERY_RESULT=empty
  return 0
}
read_task_runner_main_menu_choice() {
  printf 'FAIL: empty inventory opened a selector\n' >&2
  return 1
}
run_menu > "$menu_empty_output" 2>&1
grep -q 'No tasks are available' "$menu_empty_output"

printf 'PASS: discovery states\n'
