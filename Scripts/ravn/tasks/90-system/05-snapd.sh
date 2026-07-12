#!/usr/bin/env bash
# ─── RaVN Task: Snapd Configuration ──────────────────────────────────────────
# Manages snapd, AppArmor service, snapd socket, and classic snap support.

# shellcheck disable=SC2034
ADMIN_TASK_ID="snapd"
# shellcheck disable=SC2034
ADMIN_TASK_FAMILY="system-config"
# shellcheck disable=SC2034
ADMIN_EXECUTION_PROFILE="privileged-system-config"
# shellcheck disable=SC2034
ADMIN_REQUIRES_PRIVILEGE=true
# shellcheck disable=SC2034
ADMIN_OWNED_RESOURCES=("snapd packages" "snapd.apparmor.service" "snapd.socket" "/snap symlink")
# shellcheck disable=SC2034
ADMIN_RESOURCE_CONFLICTS=()
# shellcheck disable=SC2034
ADMIN_REVERSIBILITY="reversible"
# shellcheck disable=SC2034
ADMIN_ACTIVATION_BOUNDARY="new session or reboot"
# shellcheck disable=SC2034
ADMIN_TEST_LEVEL="isolated,docker"

readonly SNAPD_PACKAGES=(snapd apparmor squashfs-tools)
readonly APPARMOR_SERVICE="snapd.apparmor.service"
readonly SNAPD_SOCKET="snapd.socket"
readonly SNAP_LINK="/snap"
readonly SNAP_TARGET="/var/lib/snapd/snap"
flg_DryRun=${flg_DryRun:-0}
SNAPD_SERVICES_ENABLED_BY_TASK=()
SNAP_LINK_CREATED_BY_TASK=false

_run_as_root() {
  if ((EUID == 0)); then
    "$@"
  else
    sudo "$@"
  fi
}

_pkg_installed() {
  _run_as_root pacman -Q "$1" > /dev/null 2>&1
}

_systemctl_enabled() {
  _run_as_root systemctl is-enabled --quiet "$1" 2> /dev/null
}

_systemctl_active() {
  _run_as_root systemctl is-active --quiet "$1" 2> /dev/null
}

_can_elevate() {
  ((EUID == 0)) || command -v sudo > /dev/null 2>&1
}

_symlink_correct() {
  [[ -L $SNAP_LINK ]] && [[ "$(readlink "$SNAP_LINK")" == "$SNAP_TARGET" ]]
}

admin_plan() {
  ADMIN_PLAN_ACTIONS=(
    "install snapd, apparmor, and squashfs-tools"
    "enable and start snapd.apparmor.service"
    "enable and start snapd.socket"
    "create /snap -> /var/lib/snapd/snap symlink"
  )
  _can_elevate &&
    command -v pacman > /dev/null 2>&1 &&
    command -v systemctl > /dev/null 2>&1 || return 1
  return 0
}

admin_apply() {
  local attempts=0
  admin_plan || return 1

  if ((flg_DryRun == 1)); then
    return 0
  fi
  if [[ -f /.dockerenv ]]; then
    return 0
  fi

  if ! _all_packages_installed; then
    if command -v yay > /dev/null 2>&1; then
      yay -S --needed --noconfirm "${SNAPD_PACKAGES[@]}" || return 1
    elif command -v paru > /dev/null 2>&1; then
      paru -S --needed --noconfirm "${SNAPD_PACKAGES[@]}" || return 1
    else
      _run_as_root pacman -S --needed --noconfirm "${SNAPD_PACKAGES[@]}" || return 1
    fi
  fi

  if ! (_systemctl_enabled "$APPARMOR_SERVICE" && _systemctl_active "$APPARMOR_SERVICE"); then
    _run_as_root systemctl enable --now "$APPARMOR_SERVICE" || return 1
    SNAPD_SERVICES_ENABLED_BY_TASK+=("$APPARMOR_SERVICE")
  fi
  if ! (_systemctl_enabled "$SNAPD_SOCKET" && _systemctl_active "$SNAPD_SOCKET"); then
    _run_as_root systemctl enable --now "$SNAPD_SOCKET" || return 1
    SNAPD_SERVICES_ENABLED_BY_TASK+=("$SNAPD_SOCKET")
  fi

  if ! _symlink_correct; then
    _run_as_root ln -sf "$SNAP_TARGET" "$SNAP_LINK" || return 1
    SNAP_LINK_CREATED_BY_TASK=true
  fi

  while ! _systemctl_active "$SNAPD_SOCKET" && ((attempts < 15)); do
    sleep 1
    ((attempts++))
  done
}

admin_verify() {
  if [[ -f /.dockerenv ]]; then
    return 0
  fi
  _all_packages_installed || return 1
  _systemctl_enabled "$APPARMOR_SERVICE" || return 1
  _systemctl_active "$APPARMOR_SERVICE" || return 1
  _systemctl_enabled "$SNAPD_SOCKET" || return 1
  _systemctl_active "$SNAPD_SOCKET" || return 1
  _symlink_correct || return 1
  return 0
}

_all_packages_installed() {
  local package=""
  for package in "${SNAPD_PACKAGES[@]}"; do
    _pkg_installed "$package" || return 1
  done
}

admin_rollback() {
  admin_reset
}

admin_reset() {
  admin_plan || return 1

  local service=""
  for service in "${SNAPD_SERVICES_ENABLED_BY_TASK[@]}"; do
    _run_as_root systemctl disable --now "$service" || true
  done
  if [[ $SNAP_LINK_CREATED_BY_TASK == true ]] && _symlink_correct; then
    _run_as_root rm -f "$SNAP_LINK" || true
    SNAP_LINK_CREATED_BY_TASK=false
  fi
  return 0
}

admin_verify_reset() {
  local service=""
  for service in "${SNAPD_SERVICES_ENABLED_BY_TASK[@]}"; do
    ! _systemctl_enabled "$service" || return 1
  done
  [[ $SNAP_LINK_CREATED_BY_TASK == false ]] || return 1
  return 0
}

check() { admin_verify; }
install() { admin_apply; }
verify() { admin_verify; }
reset() { admin_reset; }
verify_reset() { admin_verify_reset; }
