#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

TEST_HOME="$(mktemp -d)"
cleanup() {
  rm -rf "$TEST_HOME"
}
trap cleanup EXIT
export HOME="$TEST_HOME"

TASK_SELECTOR="nvim-custom-vims"
ADIVIM_CMD="${HOME}/.local/bin/adivim"
TWOKVIM_CMD="${HOME}/.local/bin/2kvim"

# shellcheck disable=SC1091
source "${RAVN_DIR}/global_fn.sh"
for fw in "${RAVN_DIR}"/framework/*.sh; do
  # shellcheck disable=SC1090
  source "$fw"
done

if ! command -v nvim &> /dev/null; then
  printf 'SKIP: nvim-custom-vims lifecycle — neovim unavailable on host\n'
  exit 0
fi

discover_tasks

# Start from a clean task-owned state when possible.
reset_selected_tasks "$TASK_SELECTOR" --yes > /dev/null 2>&1 || true

assert_result() {
  local expected="$1"
  [[ ${TASK_RESULTS[0]:-} == "$expected" ]] || {
    printf 'FAIL: expected %s, got %s\n' "$expected" "${TASK_RESULTS[0]:-}" >&2
    exit 1
  }
}

TASK_RESULTS=()
if ! run_selected_tasks run "$TASK_SELECTOR"; then
  printf 'FAIL: nvim-custom-vims run\n' >&2
  exit 1
fi
assert_result "nvim-custom-vims:verified"

TASK_RESULTS=()
if ! run_selected_tasks run "$TASK_SELECTOR"; then
  printf 'FAIL: nvim-custom-vims idempotent run\n' >&2
  exit 1
fi
assert_result "nvim-custom-vims:skipped"

if ! "$ADIVIM_CMD" --headless +'qa' > /dev/null 2>&1; then
  printf 'FAIL: adivim launcher did not exit cleanly\n' >&2
  exit 1
fi
if ! "$TWOKVIM_CMD" --headless +'qa' > /dev/null 2>&1; then
  printf 'FAIL: 2kvim launcher did not exit cleanly\n' >&2
  exit 1
fi

for launcher in "$ADIVIM_CMD" "$TWOKVIM_CMD"; do
  config_probe="${TEST_HOME}/$(basename "$launcher")-config"
  argument_probe="${TEST_HOME}/$(basename "$launcher")-argument"
  argument_file="${TEST_HOME}/forwarded.txt"
  if ! "$launcher" --headless \
    --cmd "call writefile([stdpath('config')], '${config_probe}')" \
    +"qa" > /dev/null 2>&1; then
    printf 'FAIL: %s did not expose a Neovim config path\n' "$launcher" >&2
    exit 1
  fi
  grep -Fq "/vims/$(basename "$launcher")" "$config_probe" || {
    printf 'FAIL: %s did not use an isolated config path\n' "$launcher" >&2
    exit 1
  }
  if ! "$launcher" --headless "$argument_file" \
    +"call writefile([expand('%:t')], '${argument_probe}')" \
    +"qa" > /dev/null 2>&1; then
    printf 'FAIL: %s did not forward user arguments\n' "$launcher" >&2
    exit 1
  fi
  grep -Fq "forwarded.txt" "$argument_probe" || {
    printf 'FAIL: %s opened the wrong forwarded argument\n' "$launcher" >&2
    exit 1
  }
done

TASK_RESULTS=()
if run_selected_tasks check-updates "$TASK_SELECTOR"; then
  printf 'FAIL: nvim-custom-vims check-updates should be unsupported\n' >&2
  exit 1
fi
assert_result "nvim-custom-vims:unsupported"

TASK_RESULTS=()
if run_selected_tasks update "$TASK_SELECTOR"; then
  printf 'FAIL: nvim-custom-vims update should be unsupported\n' >&2
  exit 1
fi
assert_result "nvim-custom-vims:unsupported"

TASK_RESULTS=()
if ! reset_selected_tasks "$TASK_SELECTOR" --yes; then
  printf 'FAIL: nvim-custom-vims reset\n' >&2
  exit 1
fi
assert_result "nvim-custom-vims:reset"

TASK_RESULTS=()
if run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: nvim-custom-vims verify should fail after reset\n' >&2
  exit 1
fi
assert_result "nvim-custom-vims:failed"

TASK_RESULTS=()
if ! run_selected_tasks run "$TASK_SELECTOR"; then
  printf 'FAIL: nvim-custom-vims reinstall\n' >&2
  exit 1
fi
assert_result "nvim-custom-vims:verified"

TASK_RESULTS=()
if ! run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: nvim-custom-vims verify after reinstall\n' >&2
  exit 1
fi
assert_result "nvim-custom-vims:verified"

printf 'PASS: nvim-custom-vims lifecycle contract\n'
