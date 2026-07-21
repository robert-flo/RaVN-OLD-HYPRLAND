#!/usr/bin/env bash
# ─── RaVN Task: Intel HD 530 (Skylake) Graphics Setup ───────────────────────
# Configures Intel HD 530 integrated graphics on Skylake systems:
# - Removes conflicting Intel Neo/Compute Runtime packages
# - Installs Mesa OpenCL (Rusticl), VA-API driver, and diagnostic tools

# shellcheck disable=SC2034
ADMIN_TASK_ID="intel-hd-530"
# shellcheck disable=SC2034
ADMIN_TASK_FAMILY="system-config"
# shellcheck disable=SC2034
ADMIN_EXECUTION_PROFILE="privileged-system-config"
# shellcheck disable=SC2034
ADMIN_REQUIRES_PRIVILEGE=true
# shellcheck disable=SC2034
ADMIN_OWNED_RESOURCES=("mesa OpenCL (opencl-mesa)" "Intel VA-API driver (libva-intel-driver)" "clinfo" "intel-gpu-tools")
# shellcheck disable=SC2034
ADMIN_RESOURCE_CONFLICTS=("intel-compute-runtime" "intel-graphics-compiler")
# shellcheck disable=SC2034
ADMIN_REVERSIBILITY="reversible"
# shellcheck disable=SC2034
ADMIN_ACTIVATION_BOUNDARY="new user session or display manager restart"
# shellcheck disable=SC2034
ADMIN_TEST_LEVEL="isolated,docker"

readonly CONFLICT_PKGS=(intel-compute-runtime intel-graphics-compiler)
readonly TARGET_PKGS=(opencl-mesa libva-intel-driver clinfo intel-gpu-tools)
INTEL_INSTALLED_BY_TASK=()

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

_pkg_installed() {
  _run_as_root pacman -Q "$1" > /dev/null 2>&1
}

_admin_targets_missing() {
  for pkg in "${TARGET_PKGS[@]}"; do
    if ! _pkg_installed "$pkg"; then
      return 0
    fi
  done
  return 1
}

admin_plan() {
  ADMIN_PLAN_ACTIONS=(
    "install mesa OpenCL, VA-API driver, and Intel diagnostics"
    "remove conflicting Intel Neo/Compute Runtime packages"
  )
  _can_elevate &&
    command -v pacman > /dev/null 2>&1 || return 1
  return 0
}

admin_apply() {
  admin_plan || return 1

  for pkg in "${CONFLICT_PKGS[@]}"; do
    if _pkg_installed "$pkg"; then
      _run_as_root pacman -Rns --noconfirm "$pkg" || return 1
    fi
  done

  INTEL_INSTALLED_BY_TASK=()
  for pkg in "${TARGET_PKGS[@]}"; do
    _pkg_installed "$pkg" || INTEL_INSTALLED_BY_TASK+=("$pkg")
  done
  ((${#INTEL_INSTALLED_BY_TASK[@]} > 0)) || return 0
  _run_as_root pacman -S --needed --noconfirm "${TARGET_PKGS[@]}" || return 1
  INTEL_INSTALLED_BY_TASK=("${TARGET_PKGS[@]}")
}

admin_verify() {
  for pkg in "${INTEL_INSTALLED_BY_TASK[@]}"; do
    _pkg_installed "$pkg" || return 1
  done
  for pkg in "${CONFLICT_PKGS[@]}"; do
    _pkg_installed "$pkg" && return 1
  done
  return 0
}

admin_rollback() {
  admin_reset
}

admin_reset() {
  admin_plan || return 1
  for pkg in "${TARGET_PKGS[@]}"; do
    if _pkg_installed "$pkg"; then
      _run_as_root pacman -Rns --noconfirm "$pkg" || true
    fi
  done
  return 0
}

admin_verify_reset() {
  for pkg in "${INTEL_INSTALLED_BY_TASK[@]}"; do
    _pkg_installed "$pkg" && return 1
  done
  return 0
}

check() { admin_verify; }
install() { admin_apply; }
verify() { admin_verify; }
reset() { admin_reset; }
verify_reset() { admin_verify_reset; }
