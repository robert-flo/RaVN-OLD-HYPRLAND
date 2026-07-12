#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export XDG_STATE_HOME
XDG_STATE_HOME=$(mktemp -d)
trap 'rm -rf "$XDG_STATE_HOME"' EXIT
TASKS=(
  "${RAVN_DIR}/tests/fixtures/verified.sh"
  "${RAVN_DIR}/tests/fixtures/legacy.sh"
  "${RAVN_DIR}/tests/fixtures/baseline.sh"
  "${RAVN_DIR}/tests/fixtures/resettable.sh"
  "${RAVN_DIR}/tests/fixtures/updateable.sh"
)

# shellcheck disable=SC1091
source "${RAVN_DIR}/framework/package.sh"
# shellcheck disable=SC1091
source "${RAVN_DIR}/framework/hooks.sh"
# shellcheck disable=SC1091
source "${RAVN_DIR}/framework/contract.sh"
# shellcheck disable=SC1091
source "${RAVN_DIR}/framework/state.sh"
# shellcheck disable=SC1091
source "${RAVN_DIR}/framework/runner.sh"

TASKS=("${TASKS[@]}")

info() { :; }
success() { :; }
warn_msg() { :; }
error_msg() { :; }
step() { :; }
print_task_results() { :; }

resolve_task_files verified
[[ ${#RESOLVED_TASKS[@]} -eq 1 && ${RESOLVED_TASKS[0]} == *verified.sh ]]

if run_selected_tasks verify verified; then
  :
else
  exit 1
fi
[[ ${TASK_RESULTS[0]} == "verified:verified" ]]
grep -q 'status = "verified"' "${XDG_STATE_HOME}/ravn/tasks/verified/state.toml"

if run_selected_tasks run legacy; then
  exit 1
else
  :
fi
[[ ${TASK_RESULTS[0]} == "legacy:unverified" ]]

if run_selected_tasks run BASELINE; then
  :
else
  exit 1
fi
[[ ${TASK_RESULTS[0]} == "baseline:verified" ]]

if reset_selected_tasks resettable --yes; then
  :
else
  exit 1
fi
[[ ${TASK_RESULTS[0]} == "resettable:reset" ]]

if reset_selected_tasks resettable </dev/null; then
  printf 'FAIL: non-interactive reset without --yes was accepted\n' >&2
  exit 1
else
  :
fi
[[ ${TASK_RESULTS[0]} == "resettable:reset-refused" ]]

if reset_selected_tasks legacy --yes; then
  exit 1
else
  :
fi
[[ ${TASK_RESULTS[0]} == "legacy:reset-unsupported" ]]

if run_selected_tasks check-updates updateable; then
  :
else
  exit 1
fi
[[ ${TASK_RESULTS[0]} == "updateable:update-available" ]]

if run_selected_tasks update updateable; then
  :
else
  exit 1
fi
[[ ${TASK_RESULTS[0]} == "updateable:verified" ]]

export RAVN_TEST_UPDATE_RESULT="update-failed"
if run_selected_tasks update updateable; then
  printf 'FAIL: update failure was accepted\n' >&2
  exit 1
fi
[[ ${TASK_RESULTS[0]} == "updateable:update-failed" ]]

export RAVN_TEST_UPDATE_RESULT="rollback-failed"
if run_selected_tasks update updateable; then
  printf 'FAIL: rollback failure was accepted\n' >&2
  exit 1
fi
[[ ${TASK_RESULTS[0]} == "updateable:rollback-failed" ]]
unset RAVN_TEST_UPDATE_RESULT

blocked_state_home="${XDG_STATE_HOME}/blocked"
printf '%s' 'not a directory' >"$blocked_state_home"
XDG_STATE_HOME="$blocked_state_home"
if run_selected_tasks verify verified; then
  printf 'FAIL: verification passed without persisted evidence\n' >&2
  exit 1
fi

printf 'PASS: direct task runner\n'
