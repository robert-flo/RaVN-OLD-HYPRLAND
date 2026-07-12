#!/usr/bin/env bash
# Lifecycle contract for tasks/10-npm-apps/22-command-code.sh
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

CMD_BIN="${HOME}/.local/bin/cmd"
TASK_SELECTOR="cmd"

# shellcheck disable=SC1091
source "${RAVN_DIR}/global_fn.sh"
for fw in "${RAVN_DIR}"/framework/*.sh; do
  # shellcheck disable=SC1090
  source "$fw"
done

if ! command -v mise &>/dev/null || ! ravn_verify_mise &>/dev/null; then
  printf 'SKIP: cmd lifecycle — mise unavailable on host\n'
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
  printf 'FAIL: cmd run\n' >&2
  exit 1
fi
assert_result "cmd:verified"

TASK_RESULTS=()
if ! run_selected_tasks run "$TASK_SELECTOR"; then
  printf 'FAIL: cmd idempotent run\n' >&2
  exit 1
fi
assert_result "cmd:skipped"

version_before=""
version_before=$("$CMD_BIN" --version)
[[ -n $version_before ]] || {
  printf 'FAIL: cmd --version returned empty output\n' >&2
  exit 1
}

TASK_RESULTS=()
if ! run_selected_tasks check-updates "$TASK_SELECTOR"; then
  printf 'FAIL: cmd check-updates\n' >&2
  exit 1
fi
[[ ${TASK_RESULTS[0]} == "cmd:up-to-date" || ${TASK_RESULTS[0]} == "cmd:update-available" ]] || {
  printf 'FAIL: unexpected check-updates result: %s\n' "${TASK_RESULTS[0]:-}" >&2
  exit 1
}

TASK_RESULTS=()
if ! run_selected_tasks update "$TASK_SELECTOR"; then
  printf 'FAIL: cmd update\n' >&2
  exit 1
fi
assert_result "cmd:verified"

version_before=$("$CMD_BIN" --version)
export RAVN_TEST_UPDATE_VERIFY_FAIL=1
TASK_RESULTS=()
if run_selected_tasks update "$TASK_SELECTOR"; then
  printf 'FAIL: cmd update should fail when candidate promotion is blocked\n' >&2
  exit 1
fi
unset RAVN_TEST_UPDATE_VERIFY_FAIL
assert_result "cmd:update-failed"

version_after=$("$CMD_BIN" --version)
if [[ $version_before != "$version_after" ]]; then
  printf 'FAIL: cmd version changed after failed update (%s -> %s)\n' \
    "$version_before" "$version_after" >&2
  exit 1
fi

TASK_RESULTS=()
if ! run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: cmd verify after failed update\n' >&2
  exit 1
fi
assert_result "cmd:verified"

TASK_RESULTS=()
if ! reset_selected_tasks "$TASK_SELECTOR" --yes; then
  printf 'FAIL: cmd reset\n' >&2
  exit 1
fi
assert_result "cmd:reset"

TASK_RESULTS=()
if run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: cmd verify should fail after reset\n' >&2
  exit 1
fi
assert_result "cmd:failed"

TASK_RESULTS=()
if ! run_selected_tasks run "$TASK_SELECTOR"; then
  printf 'FAIL: cmd reinstall after reset\n' >&2
  exit 1
fi
assert_result "cmd:verified"

TASK_RESULTS=()
if ! run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: cmd verify after reinstall\n' >&2
  exit 1
fi
assert_result "cmd:verified"

printf 'PASS: cmd lifecycle contract\n'
