#!/usr/bin/env bash
# Lifecycle contract for tasks/30-github-apps/19-herdr.sh
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

HERDR_CMD="${HOME}/.local/bin/herdr"
TASK_SELECTOR="herdr"

herdr_version_id() {
  "$HERDR_CMD" --version | awk 'NR == 1 { print $NF }'
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
assert_result "herdr:verified"

TASK_RESULTS=()
run_selected_tasks run "$TASK_SELECTOR"
assert_result "herdr:skipped"

version_before=$(herdr_version_id)
[[ -n $version_before ]] || {
  printf 'FAIL: herdr --version returned empty output\n' >&2
  exit 1
}
"$HERDR_CMD" --version >/dev/null

TASK_RESULTS=()
TASK_RESULTS=()
run_selected_tasks check-updates "$TASK_SELECTOR"
[[ ${TASK_RESULTS[0]} == "herdr:up-to-date" || ${TASK_RESULTS[0]} == "herdr:update-available" ]] || {
  printf 'FAIL: unexpected herdr check-updates result: %s\n' "${TASK_RESULTS[0]:-}" >&2
  exit 1
}

TASK_RESULTS=()
run_selected_tasks update "$TASK_SELECTOR"
assert_result "herdr:verified"

version_before=$(herdr_version_id)
export RAVN_TEST_UPDATE_VERIFY_FAIL=1
TASK_RESULTS=()
if run_selected_tasks update "$TASK_SELECTOR"; then
  printf 'FAIL: herdr update should fail when promotion verification is blocked\n' >&2
  exit 1
fi
unset RAVN_TEST_UPDATE_VERIFY_FAIL
assert_result "herdr:update-failed"
version_after=$(herdr_version_id)
[[ $version_before == "$version_after" ]] || {
  printf 'FAIL: herdr version changed after failed update (%s -> %s)\n' \
    "$version_before" "$version_after" >&2
  exit 1
}

TASK_RESULTS=()
reset_selected_tasks "$TASK_SELECTOR" --yes
assert_result "herdr:reset"

TASK_RESULTS=()
if run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: herdr verify should fail after reset\n' >&2
  exit 1
fi
assert_result "herdr:failed"

TASK_RESULTS=()
run_selected_tasks run "$TASK_SELECTOR"
assert_result "herdr:verified"

TASK_RESULTS=()
run_selected_tasks verify "$TASK_SELECTOR"
assert_result "herdr:verified"

printf 'PASS: herdr lifecycle contract\n'
