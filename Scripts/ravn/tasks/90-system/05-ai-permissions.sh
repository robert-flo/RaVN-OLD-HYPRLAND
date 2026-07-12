#!/usr/bin/env bash
# ─── RaVN Task: AI Permissions ──────────────────────────────────────────────
# Grants system-wide permissions for local development: groups, polkit rules,
# sudoers overrides, systemd limits, and user@.service override.

# shellcheck disable=SC2034
ADMIN_TASK_ID="ai-permissions"
# shellcheck disable=SC2034
ADMIN_TASK_FAMILY="system-config"
# shellcheck disable=SC2034
ADMIN_EXECUTION_PROFILE="privileged-system-config"
# shellcheck disable=SC2034
ADMIN_REQUIRES_PRIVILEGE=true
# shellcheck disable=SC2034
ADMIN_OWNED_RESOURCES=("/etc/polkit-1/rules.d/99-wheel-nopasswd.rules" "/etc/sudoers.d/99-ai-tools" "/etc/sudoers.d/hermes-nopasswd" "/etc/systemd/system.conf.d/99-limits.conf" "/etc/systemd/system/user@.service.d/override.conf")
# shellcheck disable=SC2034
ADMIN_RESOURCE_CONFLICTS=()
# shellcheck disable=SC2034
ADMIN_REVERSIBILITY="partially-reversible"
# shellcheck disable=SC2034
ADMIN_ACTIVATION_BOUNDARY="new session or daemon-reload"
# shellcheck disable=SC2034
ADMIN_TEST_LEVEL="isolated"

readonly POLKIT_RULES="/etc/polkit-1/rules.d/99-wheel-nopasswd.rules"
readonly SUDOERS_AI="/etc/sudoers.d/99-ai-tools"
readonly SUDOERS_HERMES="/etc/sudoers.d/hermes-nopasswd"
readonly SYSTEMLIMITS_CONF="/etc/systemd/system.conf.d/99-limits.conf"
readonly USER_OVERRIDE="/etc/systemd/system/user@.service.d/override.conf"
AI_CREATED_FILES=()

_run_as_root() {
  if ((EUID == 0)); then
    "$@"
  else
    sudo "$@"
  fi
}

_file_exists() {
  [[ -f $1 ]]
}

_file_contains() {
  local file="$1"
  local expected="$2"
  [[ -f $file ]] && grep -qF "$expected" "$file"
}

_polkit_valid() {
  _file_contains "$POLKIT_RULES" 'polkit.addRule' &&
    _file_contains "$POLKIT_RULES" 'org.freedesktop.systemd1.manage-units'
}

_sudoers_ai_valid() {
  _file_contains "$SUDOERS_AI" 'Defaults env_keep += "SSH_AUTH_SOCK"' &&
    _file_contains "$SUDOERS_AI" 'Defaults use_pty'
}

_sudoers_hermes_valid() {
  _file_contains "$SUDOERS_HERMES" 'dominus ALL=(ALL) NOPASSWD: ALL'
}

_system_limits_valid() {
  _file_contains "$SYSTEMLIMITS_CONF" 'DefaultTasksMax=infinity'
}

_user_override_valid() {
  _file_contains "$USER_OVERRIDE" 'Delegate=yes' &&
    _file_contains "$USER_OVERRIDE" 'NoNewPrivileges=no'
}

_user_in_group() {
  id -nG "$USER" | grep -qw "$1"
}

admin_plan() {
  ADMIN_PLAN_ACTIONS=(
    "add user to systemd-journal and input groups"
    "create polkit rules for wheel group"
    "create sudoers overrides"
    "configure systemd limits"
    "create user@.service override"
  )
  command -v systemctl > /dev/null 2>&1 && command -v visudo > /dev/null 2>&1
}

admin_apply() {
  admin_plan || return 1

  if ! _user_in_group "systemd-journal"; then
    _run_as_root usermod -aG systemd-journal "$USER" || return 1
  fi
  if ! _user_in_group "input"; then
    _run_as_root usermod -aG input "$USER" || return 1
  fi

  if ! _polkit_valid; then
    _file_exists "$POLKIT_RULES" || AI_CREATED_FILES+=("$POLKIT_RULES")
    _run_as_root mkdir -p "$(dirname "$POLKIT_RULES")"
    _run_as_root tee "$POLKIT_RULES" > /dev/null << 'EOF'
/* Allow wheel users to execute commands without password */
polkit.addRule(function(action, subject) {
  if (subject.isInGroup("wheel")) {
    // Allow system operations without password
    if (action.id == "org.freedesktop.systemd1.manage-units" ||
        action.id == "org.freedesktop.NetworkManager.network-control" ||
        action.id == "org.freedesktop.login1.power-off" ||
        action.id == "org.freedesktop.login1.reboot") {
      return polkit.Result.YES;
    }
  }
});
EOF
  fi

  if ! _sudoers_ai_valid; then
    _file_exists "$SUDOERS_AI" || AI_CREATED_FILES+=("$SUDOERS_AI")
    _run_as_root mkdir -p "$(dirname "$SUDOERS_AI")"
    _run_as_root tee "$SUDOERS_AI" > /dev/null << 'EOF'
# Keep important environment variables
Defaults env_keep += "SSH_AUTH_SOCK"
Defaults env_keep += "NIX_PATH"
# Avoid warnings: use the target user's (root) HOME when running sudo
Defaults always_set_home

# Remember password for 60 minutes after entering it
Defaults timestamp_timeout=60

# One password applies to all open terminals
Defaults !tty_tickets

# Don't show warning message every time
Defaults !lecture

# Allow use_pty to prevent "no new privileges"
Defaults use_pty
EOF
    _run_as_root chmod 0440 "$SUDOERS_AI"
  fi

  if ! _sudoers_hermes_valid; then
    _file_exists "$SUDOERS_HERMES" || AI_CREATED_FILES+=("$SUDOERS_HERMES")
    _run_as_root tee "$SUDOERS_HERMES" > /dev/null << 'EOF'
dominus ALL=(ALL) NOPASSWD: ALL
EOF
    _run_as_root chmod 0440 "$SUDOERS_HERMES"
    _run_as_root visudo -c -f "$SUDOERS_HERMES" > /dev/null 2>&1 || {
      _run_as_root rm -f "$SUDOERS_HERMES"
      return 1
    }
  fi

  if ! _system_limits_valid; then
    _file_exists "$SYSTEMLIMITS_CONF" || AI_CREATED_FILES+=("$SYSTEMLIMITS_CONF")
    _run_as_root mkdir -p "$(dirname "$SYSTEMLIMITS_CONF")"
    _run_as_root tee "$SYSTEMLIMITS_CONF" > /dev/null << 'EOF'
[Manager]
DefaultTasksMax=infinity
EOF
  fi

  if ! _user_override_valid; then
    _file_exists "$USER_OVERRIDE" || AI_CREATED_FILES+=("$USER_OVERRIDE")
    _run_as_root mkdir -p "$(dirname "$USER_OVERRIDE")"
    _run_as_root tee "$USER_OVERRIDE" > /dev/null << 'EOF'
[Service]
Delegate=yes
PrivateDevices=no
PrivateTmp=no
NoNewPrivileges=no
EOF
  fi

  _run_as_root systemctl daemon-reload || return 1
}

admin_verify() {
  _user_in_group "systemd-journal" || return 1
  _user_in_group "input" || return 1
  _polkit_valid || return 1
  _sudoers_ai_valid || return 1
  _sudoers_hermes_valid || return 1
  _run_as_root visudo -c -f "$SUDOERS_AI" > /dev/null 2>&1 || return 1
  _run_as_root visudo -c -f "$SUDOERS_HERMES" > /dev/null 2>&1 || return 1
  _system_limits_valid || return 1
  _user_override_valid || return 1
  return 0
}

admin_rollback() {
  admin_reset
}

admin_reset() {
  local file=""
  for file in "${AI_CREATED_FILES[@]}"; do
    _run_as_root rm -f "$file"
  done
}

admin_verify_reset() {
  local file=""
  for file in "${AI_CREATED_FILES[@]}"; do
    ! _file_exists "$file" || return 1
  done
  return 0
}

check() { admin_verify; }
install() { admin_apply; }
verify() { admin_verify; }
reset() { admin_reset; }
verify_reset() { admin_verify_reset; }
