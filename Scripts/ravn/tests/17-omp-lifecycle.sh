#!/usr/bin/env bash
# Lifecycle contract for tasks/30-github-apps/17-omp.sh
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

OMP_CMD="${HOME}/.local/bin/omp"
TASK_SELECTOR="omp"

omp_version_id() {
  "$OMP_CMD" --version | awk 'NR == 1 { print $NF }'
}

# shellcheck disable=SC1091
source "${RAVN_DIR}/global_fn.sh"
for fw in "${RAVN_DIR}"/framework/*.sh; do
  # shellcheck disable=SC1090
  source "$fw"
done

discover_tasks
reset_selected_tasks "$TASK_SELECTOR" --yes > /dev/null 2>&1 || true

assert_result() {
  local expected="$1"
  [[ ${TASK_RESULTS[0]:-} == "$expected" ]] || {
    printf 'FAIL: expected %s, got %s\n' "$expected" "${TASK_RESULTS[0]:-}" >&2
    exit 1
  }
}

TASK_RESULTS=()
run_selected_tasks run "$TASK_SELECTOR"
assert_result "omp:verified"

TASK_RESULTS=()
run_selected_tasks run "$TASK_SELECTOR"
assert_result "omp:skipped"

version_before=$(omp_version_id)
[[ -n $version_before ]] || {
  printf 'FAIL: omp --version returned empty output\n' >&2
  exit 1
}
"$OMP_CMD" --version > /dev/null

TASK_RESULTS=()
run_selected_tasks check-updates "$TASK_SELECTOR"
[[ ${TASK_RESULTS[0]} == "omp:up-to-date" || ${TASK_RESULTS[0]} == "omp:update-available" ]] || {
  printf 'FAIL: unexpected omp check-updates result: %s\n' "${TASK_RESULTS[0]:-}" >&2
  exit 1
}

TASK_RESULTS=()
run_selected_tasks update "$TASK_SELECTOR"
assert_result "omp:verified"

version_before=$(omp_version_id)
export RAVN_TEST_UPDATE_VERIFY_FAIL=1
TASK_RESULTS=()
if run_selected_tasks update "$TASK_SELECTOR"; then
  printf 'FAIL: omp update should fail when promotion verification is blocked\n' >&2
  exit 1
fi
unset RAVN_TEST_UPDATE_VERIFY_FAIL
assert_result "omp:update-failed"
version_after=$(omp_version_id)
[[ $version_before == "$version_after" ]] || {
  printf 'FAIL: omp version changed after failed update (%s -> %s)\n' \
    "$version_before" "$version_after" >&2
  exit 1
}

TASK_RESULTS=()
reset_selected_tasks "$TASK_SELECTOR" --yes
assert_result "omp:reset"

TASK_RESULTS=()
if run_selected_tasks verify "$TASK_SELECTOR"; then
  printf 'FAIL: omp verify should fail after reset\n' >&2
  exit 1
fi
assert_result "omp:failed"

TASK_RESULTS=()
run_selected_tasks run "$TASK_SELECTOR"
assert_result "omp:verified"

TASK_RESULTS=()
run_selected_tasks verify "$TASK_SELECTOR"
assert_result "omp:verified"

printf 'PASS: omp lifecycle contract\n'
