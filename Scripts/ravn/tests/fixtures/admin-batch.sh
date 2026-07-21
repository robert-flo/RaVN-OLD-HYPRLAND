#!/usr/bin/env bash
# shellcheck disable=SC2034

ADMIN_BATCH_ID="admin-batch-fixture"
ADMIN_BATCH_TASKS=(prepare dependent independent)
declare -A ADMIN_TASK_DEPENDS=(
  [prepare]=''
  [dependent]='prepare'
  [independent]=''
)
declare -A ADMIN_TASK_RESOURCES=(
  [prepare]='prepare.conf'
  [dependent]='dependent.conf'
  [independent]='independent.conf'
)
declare -A ADMIN_TASK_CAPABILITIES=(
  [prepare]='write-file'
  [dependent]='write-file'
  [independent]='write-file'
)
declare -A ADMIN_TASK_REVERSIBILITY=(
  [prepare]='reversible'
  [dependent]='reversible'
  [independent]='reversible'
)
declare -A ADMIN_TASK_APPLY_MODE=(
  [prepare]='declared'
  [dependent]='declared'
  [independent]='declared'
)

admin_batch_prepare() {
  if [[ ${RAVN_ADMIN_SCENARIO:-} == conflict ]]; then
    ADMIN_TASK_RESOURCES[dependent]=prepare.conf
  fi
}

batch_apply_task() {
  local task=$1
  case ${RAVN_ADMIN_SCENARIO:-success}:$task in
    reversible-failure:prepare) return 1 ;;
    rollback-failure:prepare)
      printf '%s\n' fail > "$HOME/prepare.conf"
      return 1
      ;;
    *) printf '%s\n' applied > "$HOME/$task.conf" ;;
  esac
}

batch_verify_task() { [[ -f "$HOME/$1.conf" ]] && grep -qx applied "$HOME/$1.conf"; }

batch_reset_task() {
  [[ ${RAVN_ADMIN_SCENARIO:-} != rollback-failure ]] || return 1
  rm -f "$HOME/$1.conf"
}
