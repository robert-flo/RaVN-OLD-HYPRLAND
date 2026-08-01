#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

# shellcheck disable=SC1091
source "${RAVN_DIR}/global_fn.sh"
# shellcheck disable=SC1091
source "${RAVN_DIR}/framework/package.sh"
# shellcheck disable=SC1091
source "${RAVN_DIR}/framework/discover.sh"

discover_tasks
[[ ${RAVN_DISCOVERY_RESULT:-} == success ]]
[[ ${#TASKS[@]} -eq 23 ]]
[[ $(printf '%s\n' "${TASKS[@]}" | grep -c '/00-core/' || true) -eq 0 ]]
[[ $(printf '%s\n' "${TASKS[@]}" | grep -c '/30-system/' || true) -eq 0 ]]
[[ $(printf '%s\n' "${TASKS[@]}" | grep -c '/10-npm-apps/' || true) -eq 8 ]]
[[ $(printf '%s\n' "${TASKS[@]}" | grep -c '/80-app-configs/' || true) -eq 1 ]]
[[ $(printf '%s\n' "${TASKS[@]}" | grep -c '/20-curl-apps/' || true) -eq 1 ]]
[[ $(printf '%s\n' "${TASKS[@]}" | grep -c '/30-github-apps/' || true) -eq 4 ]]
[[ $(printf '%s\n' "${TASKS[@]}" | grep -c '/20-shell/' || true) -eq 0 ]]
[[ $(printf '%s\n' "${TASKS[@]}" | grep -c '/90-system/' || true) -eq 9 ]]
if printf '%s\n' "${TASKS[@]}" | grep -q 'tasks_legacy'; then
  printf 'FAIL: legacy tasks were discovered\n' >&2
  exit 1
fi
if ! printf '%s\n' "${TASKS[@]}" | grep -q '/80-app-configs/04-nvim-custom-vims.sh'; then
  printf 'FAIL: canonical nvim-custom-vims task was not discovered\n' >&2
  exit 1
fi
if printf '%s\n' "${TASKS[@]}" | grep -q 'tasks_legacy/10-npm-apps/04-nvim-custom-vims.sh'; then
  printf 'FAIL: legacy nvim-custom-vims task was discovered\n' >&2
  exit 1
fi

printf 'PASS: active task discovery contains only canonical tasks\n'
