#!/usr/bin/env bash

# shellcheck disable=SC2034
PACKAGE="opencode-contract"
# shellcheck disable=SC2034
TASK_ID="opencode-contract"
# shellcheck disable=SC2034
TASK_FAMILY="cli-tools"
# shellcheck disable=SC2034
INSTALLER_STRATEGY="mise"
# shellcheck disable=SC2034
TEST_LEVEL="isolated"

check() {
  [[ ${RAVN_TEST_CHECK_RESULT:-proceed} == "satisfied" ]]
}

install() {
  if [[ ${RAVN_TEST_DEPENDENCY_RESULT:-success} != "success" ]]; then
    RAVN_DEPENDENCY_MISSING=true
    return 1
  fi
  [[ ${RAVN_TEST_INSTALL_RESULT:-success} == "success" ]]
}

verify() {
  [[ ${RAVN_TEST_VERIFY_RESULT:-success} == "success" ]]
}

reset() {
  [[ ${RAVN_TEST_RESET_RESULT:-success} == "success" ]]
}

verify_reset() {
  [[ ${RAVN_TEST_VERIFY_RESET_RESULT:-success} == "success" ]]
}

check_updates() {
  RAVN_UPDATE_AVAILABLE=false
}

update() {
  if [[ ${RAVN_TEST_UPDATE_RESULT:-success} != "success" ]]; then
    RAVN_UPDATE_RESULT="$RAVN_TEST_UPDATE_RESULT"
    return 1
  fi
}
