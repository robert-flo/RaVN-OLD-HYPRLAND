#!/usr/bin/env bash
# ─── RaVN Task: Intel HD 530 (Skylake) Graphics Setup ───────────────────────
# Configures Intel HD 530 integrated graphics on Skylake systems:
# - Removes conflicting Intel Neo/Compute runtime packages
# - Installs Mesa OpenCL (Rusticl), VA-API driver, and diagnostic tools

# shellcheck disable=SC2034,SC2154
PACKAGE="intel-hd-530"
DESCRIPTION="Intel HD 530 (Skylake) graphics driver and diagnostics"
CATEGORY="system"
DEPENDS=()
INTERACTIVE=false

# Packages to remove and install
readonly CONFLICT_PKGS=(intel-compute-runtime intel-graphics-compiler)
readonly TARGET_PKGS=(opencl-mesa libva-intel-driver clinfo intel-gpu-tools)

# Run a command with sudo only when the current user is not root
_run_as_root() {
  if ((EUID == 0)); then
    "$@"
  else
    sudo "$@"
  fi
}

check() {
  # Proceed if any target package is missing
  for pkg in "${TARGET_PKGS[@]}"; do
    if ! pkg_installed "$pkg"; then
      return 1
    fi
  done

  # Proceed if any conflicting package is still present
  for pkg in "${CONFLICT_PKGS[@]}"; do
    if pkg_installed "$pkg"; then
      return 1
    fi
  done

  return 0
}

install() {
  if ((flg_DryRun == 1)); then
    info "Simulación: Saltando configuración de Intel HD 530."
    return 0
  fi

  step "Configurando driver gráfico Intel HD 530 (Skylake)"

  info "Limpiando posibles conflictos (Intel Neo / Compute Runtime)..."
  for pkg in "${CONFLICT_PKGS[@]}"; do
    if pkg_installed "$pkg"; then
      _run_as_root pacman -Rns --noconfirm "$pkg" || true
    fi
  done

  info "Instalando paquetes gráficos y herramientas de diagnóstico..."
  _run_as_root pacman -S --needed --noconfirm "${TARGET_PKGS[@]}"

  success "Configuración de Intel HD 530 completada."
}
