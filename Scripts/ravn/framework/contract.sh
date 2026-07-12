#!/usr/bin/env bash
# ─── RaVN Framework v1 — Task Contract ──────────────────────────────────────
# Validates task metadata and exposes lifecycle capabilities to the runner.

TASK_CONTRACT_ERRORS=()

readonly RAVN_TASK_FAMILIES=(baseline cli-tools desktop-apps system-admin)
readonly RAVN_INSTALLER_STRATEGIES=(pacman mise omarchy-npx flatpak upstream custom)
readonly RAVN_TEST_LEVELS=(static isolated live)

_ravn_value_in_array() {
  local value="$1"
  shift

  local allowed
  for allowed in "$@"; do
    if [[ $value == "$allowed" ]]; then
      return 0
    fi
  done

  return 1
}

_ravn_contract_error() {
  TASK_CONTRACT_ERRORS+=("$1")
}

# validate_task_contract
#   Validates metadata after package.sh defaults and the task module are sourced.
#   Returns 0 when complete, 1 when incomplete or invalid.
validate_task_contract() {
  TASK_CONTRACT_ERRORS=()

  if [[ -z ${TASK_ID:-} ]]; then
    _ravn_contract_error "TASK_ID is required"
  fi

  if [[ -z ${TASK_FAMILY:-} ]]; then
    _ravn_contract_error "TASK_FAMILY is required"
  elif ! _ravn_value_in_array "$TASK_FAMILY" "${RAVN_TASK_FAMILIES[@]}"; then
    _ravn_contract_error "TASK_FAMILY '$TASK_FAMILY' is invalid"
  fi

  if [[ -z ${INSTALLER_STRATEGY:-} ]]; then
    _ravn_contract_error "INSTALLER_STRATEGY is required"
  elif ! _ravn_value_in_array "$INSTALLER_STRATEGY" "${RAVN_INSTALLER_STRATEGIES[@]}"; then
    _ravn_contract_error "INSTALLER_STRATEGY '$INSTALLER_STRATEGY' is invalid"
  fi

  if [[ -z ${TEST_LEVEL:-} ]]; then
    _ravn_contract_error "TEST_LEVEL is required"
  elif ! _ravn_value_in_array "$TEST_LEVEL" "${RAVN_TEST_LEVELS[@]}"; then
    _ravn_contract_error "TEST_LEVEL '$TEST_LEVEL' is invalid"
  fi

  ((${#TASK_CONTRACT_ERRORS[@]} == 0))
}

# task_capability <hook>
#   Returns 0 when a lifecycle hook was implemented by the task module.
task_capability() {
  local hook="$1"

  hook_defined "$hook"
}

# task_contract_summary
#   Prints stable, human-readable metadata and lifecycle capabilities.
task_contract_summary() {
  printf 'id=%s\n' "${TASK_ID:-}"
  printf 'package=%s\n' "${PACKAGE:-}"
  printf 'family=%s\n' "${TASK_FAMILY:-}"
  printf 'installer=%s\n' "${INSTALLER_STRATEGY:-}"
  printf 'test_level=%s\n' "${TEST_LEVEL:-}"
  printf 'interactive=%s\n' "${INTERACTIVE:-false}"
  printf 'has_check=%s\n' "$(task_capability check && echo true || echo false)"
  printf 'has_install=%s\n' "$(task_capability install && echo true || echo false)"
  printf 'has_verify=%s\n' "$(task_capability verify && echo true || echo false)"
  printf 'has_reset=%s\n' "$(task_capability reset && echo true || echo false)"
  printf 'has_verify_reset=%s\n' "$(task_capability verify_reset && echo true || echo false)"
}
