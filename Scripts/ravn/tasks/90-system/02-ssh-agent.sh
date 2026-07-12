#!/usr/bin/env bash
# ─── RaVN Task: User SSH Agent Socket ───────────────────────────────────────

# shellcheck disable=SC2034
ADMIN_TASK_ID="ssh-agent"
# shellcheck disable=SC2034
ADMIN_TASK_FAMILY="system-config"
# shellcheck disable=SC2034
ADMIN_EXECUTION_PROFILE="system-config"
# shellcheck disable=SC2034
ADMIN_REQUIRES_PRIVILEGE=false
# shellcheck disable=SC2034
ADMIN_OWNED_RESOURCES=("user systemd unit: ssh-agent.socket")
# shellcheck disable=SC2034
ADMIN_RESOURCE_CONFLICTS=()
# shellcheck disable=SC2034
ADMIN_REVERSIBILITY="reversible"
# shellcheck disable=SC2034
ADMIN_ACTIVATION_BOUNDARY="user systemd session"
# shellcheck disable=SC2034
ADMIN_TEST_LEVEL="isolated,docker,host"

SSH_AGENT_UNIT="ssh-agent.socket"
SSH_AGENT_ENABLED_BY_TASK=false

admin_plan() {
  ADMIN_PLAN_ACTIONS=("enable and start the user ssh-agent socket")
  command -v systemctl > /dev/null 2>&1
}

admin_apply() {
  if systemctl --user is-enabled "$SSH_AGENT_UNIT" > /dev/null 2>&1 ||
    systemctl --user is-active "$SSH_AGENT_UNIT" > /dev/null 2>&1; then
    return 0
  fi
  systemctl --user enable --now "$SSH_AGENT_UNIT" || return 1
  SSH_AGENT_ENABLED_BY_TASK=true
}

admin_verify() {
  systemctl --user is-enabled "$SSH_AGENT_UNIT" > /dev/null 2>&1 &&
    systemctl --user is-active "$SSH_AGENT_UNIT" > /dev/null 2>&1
}

admin_rollback() {
  admin_reset
}

admin_reset() {
  if [[ $SSH_AGENT_ENABLED_BY_TASK == true ]] &&
    (systemctl --user is-enabled "$SSH_AGENT_UNIT" > /dev/null 2>&1 ||
      systemctl --user is-active "$SSH_AGENT_UNIT" > /dev/null 2>&1); then
    systemctl --user disable --now "$SSH_AGENT_UNIT"
    SSH_AGENT_ENABLED_BY_TASK=false
  fi
}

admin_verify_reset() {
  [[ $SSH_AGENT_ENABLED_BY_TASK == false ]] || return 1
  return 0
}
