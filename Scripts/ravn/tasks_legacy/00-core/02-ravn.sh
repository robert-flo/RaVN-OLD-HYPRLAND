#!/usr/bin/env bash
# ─── RaVN Task: RaVN Repository ─────────────────────────────────────────────
# Extracted from install_fnl.sh::setup_ravn()
# Clones/updates the RaVN configuration repository with SSH auto-detection.

# shellcheck disable=SC2034
PACKAGE="ravn"
DESCRIPTION="RaVN configuration repository clone/update"
CATEGORY="core"
DEPENDS=()
INTERACTIVE=false

check() {
  # Skip if the RaVN repo already exists and is up to date
  # Always run to ensure latest sync — return 1 to proceed
  return 1
}

install() {
  # Usar rama personalizada si se indica, de lo contrario por defecto la actual o 'master'
  local default_branch
  default_branch=$(git -C "${scrDir:-$(dirname "$(realpath "$0")")}" branch --show-current 2>/dev/null || echo "master")
  local ravn_ref="${RAVN_REF:-$default_branch}"
  # Usar repositorio personalizado si se especifica, de lo contrario por defecto 'robert-flo/RaVN'
  local ravn_repo="${RAVN_REPO:-robert-flo/RaVN}"

  step "Configurando RaVN (${ravn_repo}@${ravn_ref})"

  # 1. Asegurar la instalación de git usando los repositorios actuales del sistema
  sudo pacman -Sy --noconfirm --needed git

  # 2. Clonar/Actualizar e inicializar el repositorio
  #    El quinto argumento "ssh" habilita la detección automática de llaves SSH
  clone_or_update_repo "RaVN" "$ravn_repo" "$HOME/.local/share/ravn" "$ravn_ref" "ssh"
}
