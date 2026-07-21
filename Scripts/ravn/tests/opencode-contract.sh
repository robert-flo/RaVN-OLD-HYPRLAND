#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR
export XDG_STATE_HOME
XDG_STATE_HOME=$(mktemp -d)
trap 'rm -rf "$XDG_STATE_HOME"' EXIT

# shellcheck disable=SC2034
TASKS=("${RAVN_DIR}/tests/fixtures/failure-injection.sh")

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

info() { :; }
success() { :; }
warn_msg() { :; }
error_msg() { :; }
step() { :; }
print_task_results() { :; }

assert_result() {
  local expected="$1"

  [[ ${TASK_RESULTS[0]} == "$expected" ]]
}

if run_selected_tasks run opencode-contract; then
  :
else
  exit 1
fi
assert_result "opencode-contract:verified"
grep -q 'status = "verified"' \
  "${XDG_STATE_HOME}/ravn/tasks/opencode-contract/state.toml"

export RAVN_TEST_INSTALL_RESULT="failure"
if run_selected_tasks run opencode-contract; then
  printf 'FAIL: install failure was accepted\n' >&2
  exit 1
fi
assert_result "opencode-contract:failed"
grep -q 'status = "broken"' \
  "${XDG_STATE_HOME}/ravn/tasks/opencode-contract/state.toml"
unset RAVN_TEST_INSTALL_RESULT

export RAVN_TEST_DEPENDENCY_RESULT="missing"
if run_selected_tasks run opencode-contract; then
  printf 'FAIL: missing dependency was accepted\n' >&2
  exit 1
fi
assert_result "opencode-contract:dependency-missing"
grep -q 'status = "dependency-missing"' \
  "${XDG_STATE_HOME}/ravn/tasks/opencode-contract/state.toml"
unset RAVN_TEST_DEPENDENCY_RESULT

export RAVN_TEST_VERIFY_RESULT="failure"
if run_selected_tasks run opencode-contract; then
  printf 'FAIL: verify failure was accepted\n' >&2
  exit 1
fi
assert_result "opencode-contract:failed"
unset RAVN_TEST_VERIFY_RESULT

export RAVN_TEST_CHECK_RESULT="satisfied"
if run_selected_tasks run opencode-contract; then
  :
else
  exit 1
fi
assert_result "opencode-contract:skipped"
grep -q 'status = "installed"' \
  "${XDG_STATE_HOME}/ravn/tasks/opencode-contract/state.toml"
unset RAVN_TEST_CHECK_RESULT

reset_input=$(mktemp)
printf '%s\n' 'NO' >"$reset_input"
if reset_selected_tasks opencode-contract <"$reset_input"; then
  printf 'FAIL: reset refusal was accepted\n' >&2
  exit 1
fi
rm -f "$reset_input"
assert_result "opencode-contract:reset-refused"

export RAVN_TEST_UPDATE_RESULT="rollback-failed"
if run_selected_tasks update opencode-contract; then
  printf 'FAIL: rollback failure was accepted\n' >&2
  exit 1
fi
assert_result "opencode-contract:rollback-failed"
grep -q 'status = "rollback-failed"' \
  "${XDG_STATE_HOME}/ravn/tasks/opencode-contract/state.toml"
unset RAVN_TEST_UPDATE_RESULT

printf 'PASS: OpenCode contract failure injection\n'
