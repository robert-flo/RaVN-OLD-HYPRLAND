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

fixture=$(mktemp)
trap 'rm -f "$fixture"' EXIT
printf 'PACKAGE="description-preview-fixture"\n' > "$fixture"

discover_tasks
preview=$(print_task_preview "${TASKS[0]}" "$fixture")
grep -q 'Task preview' <<< "$preview"
grep -q 'No description available.' <<< "$preview"

# shellcheck disable=SC2034 # Consumed by the sourced runner.
RAVN_UI_EFFECTIVE=bash
# shellcheck disable=SC2034 # Consumed by select_tasks_for_family.
SELECTED_TASK_FAMILY=ALL
selection_output_file=$(mktemp)
trap 'rm -f "$fixture" "$selection_output_file"' EXIT
select_tasks_for_family <<< '1' > "$selection_output_file"
selected_task="${SELECTED_TASKS[0]}"
resolve_task_files "$selected_task"
preview=$(print_task_preview "${RESOLVED_TASKS[@]}")
grep -q 'Task preview' <<< "$preview"
[[ -n $selected_task ]]

printf 'PASS: task description preview\n'
