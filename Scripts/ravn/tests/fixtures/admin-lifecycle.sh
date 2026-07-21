#!/usr/bin/env bash

# shellcheck disable=SC2034
ADMIN_TASK_ID="admin-fixture"
ADMIN_TASK_FAMILY="system-config"
ADMIN_EXECUTION_PROFILE="system-config"
ADMIN_REQUIRES_PRIVILEGE=false
ADMIN_OWNED_RESOURCES=("$HOME/.config/ravn/admin-fixture.conf")
ADMIN_RESOURCE_CONFLICTS=()
ADMIN_REVERSIBILITY="reversible"
ADMIN_ACTIVATION_BOUNDARY="none"
ADMIN_TEST_LEVEL="isolated"

admin_fixture_plan() {
  ADMIN_PLAN_ACTIONS=("write managed fixture configuration")
}

admin_fixture_apply() {
  case ${RAVN_ADMIN_SCENARIO:-success} in
    apply-failure) return 1 ;;
  esac
  mkdir -p "$(dirname "${ADMIN_OWNED_RESOURCES[0]}")"
  printf '%s\n' 'managed=true' > "${ADMIN_OWNED_RESOURCES[0]}"
}

admin_fixture_verify() {
  case ${RAVN_ADMIN_SCENARIO:-success} in
    verify-failure) return 1 ;;
    pending)
      ADMIN_VERIFY_PENDING="relogin required"
      return 2
      ;;
    unsupported)
      ADMIN_VERIFY_UNSUPPORTED="activation cannot be verified"
      return 3
      ;;
    partial)
      ADMIN_VERIFY_PARTIAL="file verified; activation unknown"
      return 4
      ;;
  esac
  [[ -f ${ADMIN_OWNED_RESOURCES[0]} ]] && grep -qx 'managed=true' "${ADMIN_OWNED_RESOURCES[0]}"
}

admin_fixture_reset() {
  rm -f "${ADMIN_OWNED_RESOURCES[0]}"
}
