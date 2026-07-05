#!/usr/bin/env bash
# ─── RaVN Task: Omarchy Repository (early) ──────────────────────────────────
# Configures the [omarchy] binary repository before package installation.
# This task is invoked directly by install.sh before install_pkg.sh so that
# Omarchy packages can be resolved during the main package install phase.

# shellcheck disable=SC2034
PACKAGE="omarchy-repo"
DESCRIPTION="Omarchy repository and keyring setup (early phase)"
CATEGORY="core"
DEPENDS=()
INTERACTIVE=false

flg_DryRun=${flg_DryRun:-0}

# shellcheck disable=SC1091
source "${RAVN_DIR}/lib/omarchy.sh"

# check — return 0 if the Omarchy repository is already configured.
check() {
  omarchy_repo_is_configured
}

# install — set up the Omarchy repository and keyring.
install() {
  setup_omarchy_repo
}
