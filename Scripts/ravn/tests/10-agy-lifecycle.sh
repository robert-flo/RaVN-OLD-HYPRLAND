#!/usr/bin/env bash
# Lifecycle contract for tasks/30-github-apps/10-agy.sh
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

AGY_CMD="${HOME}/.local/bin/agy"
TASK_SELECTOR="agy"

agy_version_id() {
  "$AGY_CMD" --version | awk 'NR == 1 { print $NF }'
}

# shellcheck disable=SC1091
source "${RAVN_DIR}/global_fn.sh"
for fw in "${RAVN_DIR}"/framework/*.sh; do
  # shellcheck disable=SC1090
  source "$fw"
done

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
assert_result "agy:verified"

TASK_RESULTS=()
run_selected_tasks run "$TASK_SELECTOR"
assert_result "agy:skipped"

version_before=$(agy_version_id)
[[ -n $version_before ]] || {
  printf 'FAIL: agy --version returned empty output\n' >&2
  exit 1
}
"$AGY_CMD" --help >/dev/null

TASK_RESULTS=()
run_selected_tasks check-updates "$TASK_SELECTOR"
[[ ${TASK_RESULTS[0]} == "agy:up-to-date" || ${TASK_RESULTS[0]} == "agy:update-available" ]] || {
  printf 'FAIL: unexpected agy check-updates result: %s\n' "${TASK_RESULTS[0]:-}" >&2
  exit 1
}

TASK_RESULTS=()
run_selected_tasks update "$TASK_SELECTOR"
assert_result "agy:verified"

version_before=$(agy_version_id)
export RAVN_TEST_UPDATE_VERIFY_FAIL=1
TASK_RESULTS=()
if run_selected_tasks update "$TASK_SELECTOR"; then
  printf 'FAIL: agy update should fail when promotion verification is blocked\n' >&2
  exit 1
fi
unset RAVN_TEST_UPDATE_VERIFY_FAIL
assert_result "agy:update-failed"
version_after=$(agy_version_id)
[[ $version_before == "$version_after" ]] || {
  printf 'FAIL: agy version changed after failed update (%s -> %s)\n' \
    "$version_before" "$version_after" >&2
  exit 1
}

TASK_RESULTS=()
reset_selected_tasks "$TASK_SELECTOR" --yes
assert_result "agy:reset"

TASK_RESULTS=()
if run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: agy verify should fail after reset\n' >&2
  exit 1
fi
assert_result "agy:failed"

TASK_RESULTS=()
run_selected_tasks run "$TASK_SELECTOR"
assert_result "agy:verified"

TASK_RESULTS=()
run_selected_tasks verify "$TASK_SELECTOR"
assert_result "agy:verified"

printf 'PASS: agy lifecycle contract\n'
