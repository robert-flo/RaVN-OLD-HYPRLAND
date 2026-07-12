#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="${RAVN_DIR}/tests/fixtures"
REPORT_DIR="${RAVN_ADMIN_REPORT_DIR:-${RAVN_DIR}/cache/admin-reports}"

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 2
}

fixture=""
approved=false
continue_independent=false
scenario=success
while (($# > 0)); do
  case $1 in
    --approve | --yes)
      approved=true
      shift
      ;;
    --continue-independent)
      continue_independent=true
      shift
      ;;
    --scenario)
      (($# >= 2)) || die "--scenario requires a value"
      scenario=$2
      shift 2
      ;;
    --report-dir)
      (($# >= 2)) || die "--report-dir requires a path"
      REPORT_DIR=$2
      shift 2
      ;;
    -h | --help)
      printf '%s\n' 'Usage: test-task-admin-batch.sh <fixture> --approve [--continue-independent]'
      exit 0
      ;;
    --*) die "unknown option: $1" ;;
    *)
      [[ -z $fixture ]] || die 'only one fixture can be selected'
      fixture=$1
      shift
      ;;
  esac
done

[[ -n $fixture ]] || die 'fixture is required'
[[ $approved == true ]] || {
  printf 'NOT_RUN: approval required before Apply\n'
  exit 3
}
fixture_file="${FIXTURE_DIR}/${fixture}.sh"
[[ -f $fixture_file ]] || die "fixture not found: $fixture"
temp_root=$(mktemp -d "${TMPDIR:-/tmp}/ravn-admin-batch.XXXXXX")
trap 'rm -rf "$temp_root"' EXIT
export HOME="${temp_root}/home" RAVN_ADMIN_SCENARIO="$scenario"
mkdir -p "$HOME" "$REPORT_DIR"
# shellcheck disable=SC1090
source "$fixture_file"
declare -F admin_batch_prepare > /dev/null && admin_batch_prepare

declare -a order=() applied=() skipped=() failed=() audit=()
declare -A remaining=() status=() claims=()

for task in "${ADMIN_BATCH_TASKS[@]}"; do
  remaining[$task]=1
  status[$task]=planned
  [[ -n ${ADMIN_TASK_CAPABILITIES[$task]:-} ]] || die "task $task has no declared capabilities"
  [[ -n ${ADMIN_TASK_RESOURCES[$task]:-} ]] || die "task $task has no owned resources"
  [[ -n ${ADMIN_TASK_REVERSIBILITY[$task]:-} ]] || die "task $task has no reversibility policy"
  [[ ${ADMIN_TASK_APPLY_MODE[$task]:-} != opaque ]] || die "opaque apply rejected for $task"
  for resource in ${ADMIN_TASK_RESOURCES[$task]}; do
    if [[ -n ${claims[$resource]:-} ]]; then
      die "resource conflict: $resource claimed by ${claims[$resource]} and $task"
    fi
    claims[$resource]=$task
  done
done

for task in "${ADMIN_BATCH_TASKS[@]}"; do
  for dependency in ${ADMIN_TASK_DEPENDS[$task]:-}; do
    [[ -n ${status[$dependency]:-} ]] || die "unknown dependency: $task -> $dependency"
  done
done

while ((${#order[@]} < ${#ADMIN_BATCH_TASKS[@]})); do
  progress=false
  for task in "${ADMIN_BATCH_TASKS[@]}"; do
    [[ -n ${remaining[$task]:-} ]] || continue
    ready=true
    for dependency in ${ADMIN_TASK_DEPENDS[$task]:-}; do
      [[ ${status[$dependency]:-} == planned ]] && ready=false
      [[ ${status[$dependency]:-} == queued || ${status[$dependency]:-} == applied || ${status[$dependency]:-} == verified ]] || {
        [[ ${status[$dependency]:-} == planned ]] || {
          status[$task]=skipped
          unset 'remaining[$task]'
          skipped+=("$task")
        }
        ready=false
      }
    done
    $ready || continue
    order+=("$task")
    status[$task]=queued
    unset 'remaining[$task]'
    progress=true
  done
  $progress || die 'dependency cycle or unknown dependency'
done

for task in "${order[@]}"; do
  [[ ${status[$task]} == queued ]] || continue
  if [[ ${status[$task]} == skipped ]]; then continue; fi
  if ! batch_apply_task "$task"; then
    status[$task]=failed
    failed+=("$task")
    audit+=("$task|${ADMIN_TASK_CAPABILITIES[$task]}|${ADMIN_TASK_RESOURCES[$task]}|failed")
    if [[ ${ADMIN_TASK_REVERSIBILITY[$task]} == reversible ]]; then
      if batch_reset_task "$task"; then
        audit+=("$task|rollback|${ADMIN_TASK_RESOURCES[$task]}|verified")
      else
        audit+=("$task|rollback|${ADMIN_TASK_RESOURCES[$task]}|rollback-failed")
      fi
    fi
    for dependent in "${order[@]}"; do
      for dependency in ${ADMIN_TASK_DEPENDS[$dependent]:-}; do
        if [[ $dependency == "$task" ]]; then
          status[$dependent]=skipped
          skipped+=("$dependent")
        fi
      done
    done
    continue
  fi
  status[$task]=applied
  applied+=("$task")
  audit+=("$task|${ADMIN_TASK_CAPABILITIES[$task]}|${ADMIN_TASK_RESOURCES[$task]}|applied")
done

result=verified
for task in "${applied[@]}"; do
  if ! batch_verify_task "$task"; then
    status[$task]=failed
    failed+=("$task")
    result=failed
  fi
done
for task in "${failed[@]}" "${skipped[@]}"; do [[ -n $task ]] && result=failed; done

report_file="${REPORT_DIR}/${ADMIN_BATCH_ID}-${scenario}.json"
json_array() {
  local first=true value
  printf '['
  for value in "$@"; do
    $first || printf ','
    printf '"%s"' "$value"
    first=false
  done
  printf ']'
}
{
  printf '{\n  "batch": "%s",\n  "result": "%s",\n  "independent_continuation": %s,\n  "applied": ' "$ADMIN_BATCH_ID" "$result" "$continue_independent"
  json_array "${applied[@]}"
  printf ',\n  "skipped": '
  json_array "${skipped[@]}"
  printf ',\n  "failed": '
  json_array "${failed[@]}"
  printf ',\n  "audit": ['
  first=true
  for entry in "${audit[@]}"; do
    IFS='|' read -r task capability resource outcome <<< "$entry"
    $first || printf ','
    printf '{"task":"%s","capability":"%s","resource":"%s","result":"%s"}' "$task" "$capability" "$resource" "$outcome"
    first=false
  done
  printf ']\n}\n'
} > "$report_file"
printf 'Batch: %s\nResult: %s\nApplied: %s\nSkipped: %s\nFailed: %s\nReport: %s\n' "$ADMIN_BATCH_ID" "$result" "${applied[*]:-none}" "${skipped[*]:-none}" "${failed[*]:-none}" "$report_file"
[[ $result == verified ]]
