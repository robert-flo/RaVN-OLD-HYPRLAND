#!/usr/bin/env bash
# Reference lifecycle contract for tasks/10-npm-apps/13-ghui.sh
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

GHUI_CMD="${HOME}/.local/bin/ghui"
TASK_SELECTOR="ghui"

# shellcheck disable=SC1091
source "${RAVN_DIR}/global_fn.sh"
for fw in "${RAVN_DIR}"/framework/*.sh; do
  # shellcheck disable=SC1090
  source "$fw"
done

if ! command -v mise &>/dev/null || ! ravn_verify_mise &>/dev/null; then
  printf 'SKIP: ghui lifecycle — mise unavailable on host\n'
  exit 0
fi

discover_tasks

# Start from a clean task-owned state when possible.
reset_selected_tasks "$TASK_SELECTOR" --yes >/dev/null 2>&1 || true

assert_result() {
  local expected="$1"
  [[ ${TASK_RESULTS[0]:-} == "$expected" ]] || {
    printf 'FAIL: expected %s, got %s\n' "$expected" "${TASK_RESULTS[0]:-}" >&2
    exit 1
  }
}

# 1. run — verified install
TASK_RESULTS=()
if ! run_selected_tasks run "$TASK_SELECTOR"; then
  printf 'FAIL: ghui run\n' >&2
  exit 1
fi
assert_result "ghui:verified"

# 2. idempotent rerun
TASK_RESULTS=()
if ! run_selected_tasks run "$TASK_SELECTOR"; then
  printf 'FAIL: ghui idempotent run\n' >&2
  exit 1
fi
assert_result "ghui:skipped"

# 3. real command from wrapper
version_before=""
version_before=$("$GHUI_CMD" --version)
[[ -n $version_before ]] || {
  printf 'FAIL: ghui --version returned empty output\n' >&2
  exit 1
}

# 4. check-updates on verified install
TASK_RESULTS=()
if ! run_selected_tasks check-updates "$TASK_SELECTOR"; then
  printf 'FAIL: ghui check-updates\n' >&2
  exit 1
fi
[[ ${TASK_RESULTS[0]} == "ghui:up-to-date" || ${TASK_RESULTS[0]} == "ghui:update-available" ]] || {
  printf 'FAIL: unexpected check-updates result: %s\n' "${TASK_RESULTS[0]:-}" >&2
  exit 1
}

# 5. update happy path
TASK_RESULTS=()
if ! run_selected_tasks update "$TASK_SELECTOR"; then
  printf 'FAIL: ghui update\n' >&2
  exit 1
fi
assert_result "ghui:verified"

# 6. rollback — failed update must not replace verified version
version_before=$("$GHUI_CMD" --version)
export RAVN_TEST_UPDATE_VERIFY_FAIL=1
TASK_RESULTS=()
if run_selected_tasks update "$TASK_SELECTOR"; then
  printf 'FAIL: ghui update should fail when candidate promotion is blocked\n' >&2
  exit 1
fi
unset RAVN_TEST_UPDATE_VERIFY_FAIL
assert_result "ghui:update-failed"

version_after=$("$GHUI_CMD" --version)
if [[ $version_before != "$version_after" ]]; then
  printf 'FAIL: ghui version changed after failed update (%s -> %s)\n' \
    "$version_before" "$version_after" >&2
  exit 1
fi

TASK_RESULTS=()
if ! run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: ghui verify after failed update\n' >&2
  exit 1
fi
assert_result "ghui:verified"

# 7. reset
TASK_RESULTS=()
if ! reset_selected_tasks "$TASK_SELECTOR" --yes; then
  printf 'FAIL: ghui reset\n' >&2
  exit 1
fi
assert_result "ghui:reset"

# 8. post-reset verify must fail
TASK_RESULTS=()
if run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: ghui verify should fail after reset\n' >&2
  exit 1
fi
assert_result "ghui:failed"

# 9. reinstall after reset
TASK_RESULTS=()
if ! run_selected_tasks run "$TASK_SELECTOR"; then
  printf 'FAIL: ghui reinstall after reset\n' >&2
  exit 1
fi
assert_result "ghui:verified"

TASK_RESULTS=()
if ! run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: ghui verify after reinstall\n' >&2
  exit 1
fi
assert_result "ghui:verified"

printf 'PASS: ghui lifecycle contract\n'
