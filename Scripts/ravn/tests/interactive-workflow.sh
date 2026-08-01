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

discover_tasks
# shellcheck disable=SC2034 # Consumed by the sourced runner.
RAVN_UI_EFFECTIVE=bash
# shellcheck disable=SC2034 # Consumed by select_tasks_for_family.
SELECTED_TASK_FAMILY=ALL
all_categories_output_file=$(mktemp)
trap 'rm -f "$all_categories_output_file"' EXIT
select_tasks_for_family <<< '1,2' > "$all_categories_output_file"
all_categories_output=$(< "$all_categories_output_file")
grep -q 'CLI Tools' <<< "$all_categories_output"
grep -q 'Legacy' <<< "$all_categories_output"
[[ ${#SELECTED_TASKS[@]} -eq 2 ]]

discovered_tasks=("${TASKS[@]}")
PIPELINE_CALLS=0
discover_tasks() {
  TASKS=("${discovered_tasks[@]}")
}

run_pipeline() {
  PIPELINE_CALLS=$((PIPELINE_CALLS + 1))
}

menu_choices=(2 q)
menu_index=0
read_task_runner_main_menu_choice() {
  # shellcheck disable=SC2034 # Consumed indirectly by run_menu.
  MENU_CHOICE="${menu_choices[menu_index]}"
  menu_index=$((menu_index + 1))
}

# shellcheck disable=SC2329 # Invoked indirectly by run_menu.
confirm_task_action() {
  return 0
}

run_menu > /dev/null
[[ $PIPELINE_CALLS -eq 1 ]]

PIPELINE_CALLS=0
menu_choices=(2 q)
menu_index=0
confirm_task_action() {
  return 1
}

run_menu > /dev/null
[[ $PIPELINE_CALLS -eq 0 ]]

ACTION_CALLS=()
run_menu_selection() {
  ACTION_CALLS+=("$1")
  return 1
}
menu_choices=(1 3 4 q)
menu_index=0
run_menu > /dev/null
[[ ${ACTION_CALLS[*]} == 'verify test reset' ]]

printf 'PASS: complete interactive workflow\n'
