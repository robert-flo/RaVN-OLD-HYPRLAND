#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

ZERO_CMD="${HOME}/.local/bin/zero"
TASK_SELECTOR="zero"

# shellcheck disable=SC1091
source "${RAVN_DIR}/global_fn.sh"
for fw in "${RAVN_DIR}"/framework/*.sh; do
  # shellcheck disable=SC1090
  source "$fw"
done

if ! command -v mise &>/dev/null || ! ravn_verify_mise &>/dev/null; then
  printf 'SKIP: zero lifecycle — mise unavailable on host\n'
  exit 0
fi

discover_tasks
reset_selected_tasks "$TASK_SELECTOR" --yes >/dev/null 2>&1 || true

assert_result() {
  local expected="$1"
  [[ ${TASK_RESULTS[0]:-} == "$expected" ]] || {
    printf 'FAIL: expected %s, got %s\n' "$expected" "${TASK_RESULTS[0]:-}" >&2
    exit 1
  }
}

TASK_RESULTS=()
run_selected_tasks run "$TASK_SELECTOR"
assert_result "zero:verified"

TASK_RESULTS=()
run_selected_tasks run "$TASK_SELECTOR"
assert_result "zero:skipped"

version_before=$("$ZERO_CMD" --version)
[[ -n $version_before ]] || {
  printf 'FAIL: zero --version returned empty output\n' >&2
  exit 1
}

TASK_RESULTS=()
run_selected_tasks check-updates "$TASK_SELECTOR"
[[ ${TASK_RESULTS[0]} == "zero:up-to-date" || ${TASK_RESULTS[0]} == "zero:update-available" ]] || {
  printf 'FAIL: unexpected check-updates result: %s\n' "${TASK_RESULTS[0]:-}" >&2
  exit 1
}

TASK_RESULTS=()
run_selected_tasks update "$TASK_SELECTOR"
assert_result "zero:verified"

version_before=$("$ZERO_CMD" --version)
export RAVN_TEST_UPDATE_VERIFY_FAIL=1
TASK_RESULTS=()
if run_selected_tasks update "$TASK_SELECTOR"; then
  printf 'FAIL: zero update should fail when candidate promotion is blocked\n' >&2
  exit 1
fi
unset RAVN_TEST_UPDATE_VERIFY_FAIL
assert_result "zero:update-failed"

version_after=$("$ZERO_CMD" --version)
[[ $version_before == "$version_after" ]] || {
  printf 'FAIL: zero version changed after failed update (%s -> %s)\n' \
    "$version_before" "$version_after" >&2
  exit 1
}

TASK_RESULTS=()
run_selected_tasks verify "$TASK_SELECTOR"
assert_result "zero:verified"

TASK_RESULTS=()
reset_selected_tasks "$TASK_SELECTOR" --yes
assert_result "zero:reset"

TASK_RESULTS=()
if run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: zero verify should fail after reset\n' >&2
  exit 1
fi
assert_result "zero:failed"

TASK_RESULTS=()
run_selected_tasks run "$TASK_SELECTOR"
assert_result "zero:verified"

TASK_RESULTS=()
run_selected_tasks verify "$TASK_SELECTOR"
assert_result "zero:verified"

printf 'PASS: zero lifecycle contract\n'
