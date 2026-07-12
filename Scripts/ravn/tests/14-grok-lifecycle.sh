#!/usr/bin/env bash
# Lifecycle contract for tasks/20-curl-apps/14-grok.sh
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

GROK_CMD="${HOME}/.local/bin/grok"
TASK_SELECTOR="grok"

grok_version_id() {
  "$GROK_CMD" version | awk 'NR == 1 { print $2 }'
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
assert_result "grok:verified"

TASK_RESULTS=()
run_selected_tasks run "$TASK_SELECTOR"
assert_result "grok:skipped"

version_before=$(grok_version_id)
[[ -n $version_before ]] || {
  printf 'FAIL: grok version returned empty output\n' >&2
  exit 1
}

TASK_RESULTS=()
run_selected_tasks check-updates "$TASK_SELECTOR"
[[ ${TASK_RESULTS[0]} == "grok:up-to-date" || ${TASK_RESULTS[0]} == "grok:update-available" ]] || {
  printf 'FAIL: unexpected grok check-updates result: %s\n' "${TASK_RESULTS[0]:-}" >&2
  exit 1
}

TASK_RESULTS=()
run_selected_tasks update "$TASK_SELECTOR"
assert_result "grok:verified"

version_before=$(grok_version_id)
export RAVN_TEST_UPDATE_VERIFY_FAIL=1
TASK_RESULTS=()
if run_selected_tasks update "$TASK_SELECTOR"; then
  printf 'FAIL: grok update should fail when promotion verification is blocked\n' >&2
  exit 1
fi
unset RAVN_TEST_UPDATE_VERIFY_FAIL
assert_result "grok:update-failed"
version_after=$(grok_version_id)
[[ $version_before == "$version_after" ]] || {
  printf 'FAIL: grok version changed after failed update (%s -> %s)\n' \
    "$version_before" "$version_after" >&2
  exit 1
}

TASK_RESULTS=()
reset_selected_tasks "$TASK_SELECTOR" --yes
assert_result "grok:reset"

TASK_RESULTS=()
if run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: grok verify should fail after reset\n' >&2
  exit 1
fi
assert_result "grok:failed"

TASK_RESULTS=()
run_selected_tasks run "$TASK_SELECTOR"
assert_result "grok:verified"

TASK_RESULTS=()
run_selected_tasks verify "$TASK_SELECTOR"
assert_result "grok:verified"

printf 'PASS: grok lifecycle contract\n'
