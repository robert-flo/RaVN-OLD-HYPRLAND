#!/usr/bin/env bash
# ─── RaVN Task: SSH Config ──────────────────────────────────────────────────
# Extracted from install_fnl.sh (lines 270-288)
# Ensures AddKeysToAgent is configured in ~/.ssh/config.

# shellcheck disable=SC2034
PACKAGE="ssh-config"
DESCRIPTION="Configure AddKeysToAgent in ~/.ssh/config"
CATEGORY="system"
DEPENDS=()
INTERACTIVE=false

check() {
  # Skip if both AddKeysToAgent and Host ravnvm are configured
  [[ -f "$HOME/.ssh/config" ]] && grep -q "AddKeysToAgent" "$HOME/.ssh/config" && grep -q "Host ravnvm" "$HOME/.ssh/config"
}

install() {
  info "Configurando ~/.ssh/config..."

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  # Create config file if it doesn't exist
  if [ ! -f "$HOME/.ssh/config" ]; then
    touch "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
  fi

  # 1. Configure AddKeysToAgent
  if ! grep -q "AddKeysToAgent" "$HOME/.ssh/config"; then
    # If the file is not empty, ensure newline
    [ -s "$HOME/.ssh/config" ] && echo "" >> "$HOME/.ssh/config"
    echo -e "Host *\n    AddKeysToAgent yes" >> "$HOME/.ssh/config"
    success "AddKeysToAgent configurado en ~/.ssh/config."
  fi

  # 2. Configure Host ravnvm
  if ! grep -q "Host ravnvm" "$HOME/.ssh/config"; then
    # If the file is not empty, ensure newline
    [ -s "$HOME/.ssh/config" ] && echo "" >> "$HOME/.ssh/config"
    cat << 'EOF' >> "$HOME/.ssh/config"
Host ravnvm
    HostName 127.0.0.1
    Port 2222
    User arch
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    success "Perfil de host 'ravnvm' configurado en ~/.ssh/config."
  fi
}
