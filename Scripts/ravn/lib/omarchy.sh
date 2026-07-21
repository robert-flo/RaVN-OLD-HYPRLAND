#!/usr/bin/env bash
# ─── RaVN Framework v1 — Omarchy Helper ───────────────────────────────────────
# Shared helper used by both the early repo setup task (run before install_pkg.sh)
# and the full Omarchy integration task (run after package installation).
# Configures the [omarchy] repository in /etc/pacman.conf without replacing it,
# imports the Omarchy GPG key, and installs the omarchy-keyring.

# shellcheck disable=SC2034
flg_DryRun=${flg_DryRun:-0}

OMARCHY_KEY="40DFB630FF42BCFFB047046CF0134EE680CAC571"
OMARCHY_CHANNEL="edge"
OMARCHY_REPO="basecamp/omarchy"
OMARCHY_REF="master"
OMARCHY_DEST="${HOME}/.local/share/omarchy"

# omarchy_repo_is_configured — return 0 if the [omarchy] block is present.
omarchy_repo_is_configured() {
  grep -q '^\[omarchy\]' /etc/pacman.conf 2>/dev/null &&
    grep -q "https://pkgs.omarchy.org/${OMARCHY_CHANNEL}/" /etc/pacman.conf 2>/dev/null
}

# setup_omarchy_repo — idempotent configuration of the Omarchy repository.
setup_omarchy_repo() {
  step "Configuring Omarchy repository (${OMARCHY_CHANNEL})"

  # 1. Ensure git is available from the current system repositories.
  run_with_status "Ensuring git is installed" \
    sudo pacman -Sy --noconfirm --needed git

  # 2. Clone or update the Omarchy upstream repository.
  clone_or_update_repo "Omarchy" "${OMARCHY_REPO}" "${OMARCHY_DEST}" "${OMARCHY_REF}"

  # 3. Import and locally sign the Omarchy GPG key when missing.
  if ! pacman-key -l 2>/dev/null | grep -q "${OMARCHY_KEY}"; then
    run_with_status "Importing Omarchy GPG key" \
      sudo pacman-key --recv-keys "${OMARCHY_KEY}" --keyserver keys.openpgp.org

    run_with_status "Locally signing Omarchy GPG key" \
      sudo pacman-key --lsign-key "${OMARCHY_KEY}"
  else
    info "Omarchy GPG key already present"
  fi

  # 4. Install the omarchy-keyring package if not already present.
  if ! pkg_installed omarchy-keyring; then
    run_with_status "Installing omarchy-keyring" \
      sudo pacman -S --needed --noconfirm omarchy-keyring
  else
    info "omarchy-keyring already installed"
  fi

  # 5. Remove any existing [omarchy] block to avoid duplicates.
  info "Integrating [omarchy] repository into /etc/pacman.conf"

  if ((flg_DryRun == 1)); then
    info "[dry-run] Would remove any existing [omarchy] block and append the ${OMARCHY_CHANNEL} entry"
  else
    if grep -q '^\[omarchy\]' /etc/pacman.conf 2>/dev/null; then
      sudo sed -i '/^\[omarchy\]/,/^[[:space:]]*$/d' /etc/pacman.conf
    fi
    # Trim trailing blank lines
    sudo sed -i -e :a -e '/^\n*$/{$d;N;ba}' /etc/pacman.conf

    # Append the Omarchy repository block
    sudo tee -a /etc/pacman.conf >/dev/null <<EOF

[omarchy]
SigLevel = Optional TrustAll
Server = https://pkgs.omarchy.org/${OMARCHY_CHANNEL}/\$arch
EOF
  fi

  # 6. Sync package databases so the repo is immediately usable.
  run_with_status "Syncing pacman databases" \
    sudo pacman -Sy
}
