#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TASKS_DIR="${RAVN_DIR}/tasks/10-npm-apps"

active_count=0
reference_count=0
task_file=""

for task_file in "${TASKS_DIR}"/*.sh; do
  # shellcheck disable=SC1091
  source "${RAVN_DIR}/framework/package.sh"
  # shellcheck disable=SC1090
  source "$task_file"
  if [[ ${REFERENCE_ONLY:-false} == true ]]; then
    reference_count=$((reference_count + 1))
  else
    active_count=$((active_count + 1))
  fi
done

[[ $active_count -eq 8 ]]
[[ $reference_count -eq 1 ]]

printf 'PASS: active npm task selection excludes reference-only modules\n'
