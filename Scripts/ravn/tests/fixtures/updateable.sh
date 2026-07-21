#!/usr/bin/env bash
# shellcheck disable=SC2034
PACKAGE="updateable"
# shellcheck disable=SC2034
TASK_ID="updateable"

verify() {
  return 0
}

check_updates() {
  RAVN_UPDATE_AVAILABLE=true
}

update() {
  if [[ ${RAVN_TEST_UPDATE_RESULT:-success} != "success" ]]; then
    RAVN_UPDATE_RESULT="$RAVN_TEST_UPDATE_RESULT"
    return 1
  fi
}
