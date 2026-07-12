#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "${RAVN_DIR}/framework/package.sh"
# shellcheck disable=SC1091
source "${RAVN_DIR}/framework/hooks.sh"
# shellcheck disable=SC1091
source "${RAVN_DIR}/framework/contract.sh"

assert_success() {
  local description="$1"
  shift

  if ! "$@"; then
    printf 'FAIL: %s\n' "$description" >&2
    exit 1
  fi
}

assert_failure() {
  local description="$1"
  shift

  if "$@"; then
    printf 'FAIL: %s\n' "$description" >&2
    exit 1
  fi
}

TASK_ID="example"
TASK_FAMILY="cli-tools"
# shellcheck disable=SC2034
INSTALLER_STRATEGY="mise"
# shellcheck disable=SC2034
TEST_LEVEL="isolated"
check() { return 0; }
install() { return 0; }
verify() { return 0; }

assert_success "complete metadata validates" validate_task_contract
assert_success "implemented check is detected" task_capability check
assert_success "implemented install is detected" task_capability install
assert_success "implemented verify is detected" task_capability verify
assert_failure "default reset is not a capability" task_capability reset
assert_failure "default verify_reset is not a capability" task_capability verify_reset

TASK_FAMILY="invalid"
assert_failure "invalid family is rejected" validate_task_contract

# shellcheck disable=SC2034
TASK_FAMILY="cli-tools"
# shellcheck disable=SC2034
TASK_ID=""
assert_failure "missing task id is rejected" validate_task_contract

printf 'PASS: task contract\n'
