#!/usr/bin/env bash
# Lifecycle contract for tasks/10-npm-apps/18-playwright.sh
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

PLAYWRIGHT_CMD="${HOME}/.local/bin/playwright"
TASK_SELECTOR="playwright"

# shellcheck disable=SC1091
source "${RAVN_DIR}/global_fn.sh"
for fw in "${RAVN_DIR}"/framework/*.sh; do
  # shellcheck disable=SC1090
  source "$fw"
done

if ! command -v mise &>/dev/null || ! ravn_verify_mise &>/dev/null; then
  printf 'SKIP: playwright lifecycle — mise unavailable on host\n'
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
if ! run_selected_tasks run "$TASK_SELECTOR"; then
  printf 'FAIL: playwright run\n' >&2
  exit 1
fi
assert_result "playwright:verified"

TASK_RESULTS=()
if ! run_selected_tasks run "$TASK_SELECTOR"; then
  printf 'FAIL: playwright idempotent run\n' >&2
  exit 1
fi
assert_result "playwright:skipped"

version_before=""
version_before=$("$PLAYWRIGHT_CMD" --version)
[[ -n $version_before ]] || {
  printf 'FAIL: playwright --version returned empty output\n' >&2
  exit 1
}

TASK_RESULTS=()
if ! run_selected_tasks check-updates "$TASK_SELECTOR"; then
  printf 'FAIL: playwright check-updates\n' >&2
  exit 1
fi
[[ ${TASK_RESULTS[0]} == "playwright:up-to-date" || ${TASK_RESULTS[0]} == "playwright:update-available" ]] || {
  printf 'FAIL: unexpected check-updates result: %s\n' "${TASK_RESULTS[0]:-}" >&2
  exit 1
}

TASK_RESULTS=()
if ! run_selected_tasks update "$TASK_SELECTOR"; then
  printf 'FAIL: playwright update\n' >&2
  exit 1
fi
assert_result "playwright:verified"

version_before=$("$PLAYWRIGHT_CMD" --version)
export RAVN_TEST_UPDATE_VERIFY_FAIL=1
TASK_RESULTS=()
if run_selected_tasks update "$TASK_SELECTOR"; then
  printf 'FAIL: playwright update should fail when candidate promotion is blocked\n' >&2
  exit 1
fi
unset RAVN_TEST_UPDATE_VERIFY_FAIL
assert_result "playwright:update-failed"

version_after=$("$PLAYWRIGHT_CMD" --version)
if [[ $version_before != "$version_after" ]]; then
  printf 'FAIL: playwright version changed after failed update (%s -> %s)\n' \
    "$version_before" "$version_after" >&2
  exit 1
fi

TASK_RESULTS=()
if ! run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: playwright verify after failed update\n' >&2
  exit 1
fi
assert_result "playwright:verified"

TASK_RESULTS=()
if ! reset_selected_tasks "$TASK_SELECTOR" --yes; then
  printf 'FAIL: playwright reset\n' >&2
  exit 1
fi
assert_result "playwright:reset"

TASK_RESULTS=()
if run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: playwright verify should fail after reset\n' >&2
  exit 1
fi
assert_result "playwright:failed"

TASK_RESULTS=()
if ! run_selected_tasks run "$TASK_SELECTOR"; then
  printf 'FAIL: playwright reinstall after reset\n' >&2
  exit 1
fi
assert_result "playwright:verified"

TASK_RESULTS=()
if ! run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: playwright verify after reinstall\n' >&2
  exit 1
fi
assert_result "playwright:verified"

printf 'PASS: playwright lifecycle contract\n'
