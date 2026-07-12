#!/usr/bin/env bash
# ─── RaVN Task: LocalSend UFW Rules ──────────────────────────────────────────

# shellcheck disable=SC2034
ADMIN_TASK_ID="firewall"
# shellcheck disable=SC2034
ADMIN_TASK_FAMILY="system-config"
# shellcheck disable=SC2034
ADMIN_EXECUTION_PROFILE="privileged-system-config"
# shellcheck disable=SC2034
ADMIN_REQUIRES_PRIVILEGE=true
# shellcheck disable=SC2034
ADMIN_OWNED_RESOURCES=("ufw rule 53317/tcp" "ufw rule 53317/udp")
# shellcheck disable=SC2034
ADMIN_RESOURCE_CONFLICTS=("unmanaged ufw rule 53317/tcp" "unmanaged ufw rule 53317/udp")
# shellcheck disable=SC2034
ADMIN_REVERSIBILITY="reversible"
# shellcheck disable=SC2034
ADMIN_ACTIVATION_BOUNDARY="active UFW firewall"
# shellcheck disable=SC2034
ADMIN_TEST_LEVEL="isolated,docker,host"

LOCAL_SEND_PORT="53317"
LOCAL_SEND_RULE_COMMENT="ravn-localsend"

_run_as_root() {
  if ((EUID == 0)); then
    "$@"
  else
    sudo "$@"
  fi
}

_can_elevate() {
  ((EUID == 0)) || command -v sudo > /dev/null 2>&1
}

_ufw_status() {
  _run_as_root ufw status
}

_ufw_active() {
  _run_as_root systemctl is-active --quiet ufw
}

_ufw_rule_present() {
  local protocol="$1"
  _ufw_status | grep -Eq "^${LOCAL_SEND_PORT}/${protocol}[[:space:]]+ALLOW([[:space:]]|$)"
}

_ufw_managed_rule_present() {
  local protocol="$1"
  _ufw_status | grep -Eq "^${LOCAL_SEND_PORT}/${protocol}[[:space:]].*# ${LOCAL_SEND_RULE_COMMENT}$"
}

_ufw_unmanaged_rule_present() {
  local protocol="$1"
  _ufw_status |
    grep -E "^${LOCAL_SEND_PORT}/${protocol}[[:space:]]" |
    grep -qvF "# ${LOCAL_SEND_RULE_COMMENT}"
}

_ufw_conflict() {
  _ufw_status |
    grep -E "^${LOCAL_SEND_PORT}/(tcp|udp)[[:space:]]+" |
    grep -qvE '[[:space:]]ALLOW([[:space:]]|$)'
}

admin_plan() {
  ADMIN_PLAN_ACTIONS=("allow LocalSend TCP/UDP port ${LOCAL_SEND_PORT}" "preserve unrelated UFW rules")
  _can_elevate &&
    command -v ufw > /dev/null 2>&1 &&
    command -v systemctl > /dev/null 2>&1 || return 1
  _ufw_active || return 1
  if _ufw_conflict; then
    return 1
  fi
  return 0
}

admin_apply() {
  admin_plan || return 1
  _ufw_rule_present tcp ||
    _run_as_root ufw allow "${LOCAL_SEND_PORT}/tcp" comment "$LOCAL_SEND_RULE_COMMENT" || return 1
  _ufw_rule_present udp ||
    _run_as_root ufw allow "${LOCAL_SEND_PORT}/udp" comment "$LOCAL_SEND_RULE_COMMENT"
}

admin_verify() {
  _ufw_active && _ufw_rule_present tcp && _ufw_rule_present udp
}

admin_rollback() {
  admin_reset
}

admin_reset() {
  admin_plan || return 1
  _ufw_managed_rule_present tcp && _run_as_root ufw delete allow "${LOCAL_SEND_PORT}/tcp" || true
  _ufw_managed_rule_present udp && _run_as_root ufw delete allow "${LOCAL_SEND_PORT}/udp" || true
  ! _ufw_managed_rule_present tcp && ! _ufw_managed_rule_present udp
}

admin_verify_reset() {
  ! _ufw_managed_rule_present tcp && ! _ufw_managed_rule_present udp
}

check() { admin_verify; }
install() { admin_apply; }
verify() { admin_verify; }
reset() { admin_reset; }
verify_reset() { admin_verify_reset; }
