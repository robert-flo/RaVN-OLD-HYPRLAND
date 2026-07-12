#!/usr/bin/env bash
# ─── RaVN Task: Custom Neovim Configurations ─────────────────────────────────

# shellcheck disable=SC2034
PACKAGE="nvim-custom-vims"
# shellcheck disable=SC2034
DESCRIPTION="Custom Neovim configurations (adivim & 2kvim) with launchers"
# shellcheck disable=SC2034
CATEGORY="app-configs"
# shellcheck disable=SC2034
DEPENDS=()
# shellcheck disable=SC2034
INTERACTIVE=false

NVIM_VIMS_DIR="${HOME}/.config/vims"
NVIM_BIN_DIR="${HOME}/.local/bin"

check() {
  [[ -f "${NVIM_VIMS_DIR}/adivim/init.lua" ]] &&
    [[ -f "${NVIM_VIMS_DIR}/2kvim/init.lua" ]] &&
    [[ -x "${NVIM_BIN_DIR}/adivim" ]] &&
    [[ -x "${NVIM_BIN_DIR}/2kvim" ]]
}

install() {
  mkdir -p "$NVIM_VIMS_DIR" "$NVIM_BIN_DIR" || return 1

  clone_or_update_repo "adivim" "adibhanna/nvim" \
    "${NVIM_VIMS_DIR}/adivim" "main" || return 1
  clone_or_update_repo "2kvim" "2KAbhishek/nvim2k" \
    "${NVIM_VIMS_DIR}/2kvim" "main" || return 1

  cat > "${NVIM_BIN_DIR}/adivim" << 'EOF'
#!/usr/bin/env bash

export NVIM_APPNAME="vims/adivim"
exec -a "$NVIM_APPNAME" nvim -u "$HOME/.config/vims/adivim/init.lua" "$@"
EOF
  chmod +x "${NVIM_BIN_DIR}/adivim" || return 1

  cat > "${NVIM_BIN_DIR}/2kvim" << 'EOF'
#!/usr/bin/env bash

export NVIM_APPNAME="vims/2kvim"
exec -a "$NVIM_APPNAME" nvim -u "$HOME/.config/vims/2kvim/init.lua" "$@"
EOF
  chmod +x "${NVIM_BIN_DIR}/2kvim" || return 1
}

verify() {
  local launcher

  check || return 1

  for launcher in adivim 2kvim; do
    [[ -x "${NVIM_BIN_DIR}/${launcher}" ]] || return 1
    grep -Fq 'export NVIM_APPNAME=' "${NVIM_BIN_DIR}/${launcher}" || return 1
    grep -Fq "exec -a \"\$NVIM_APPNAME\" nvim" "${NVIM_BIN_DIR}/${launcher}" || return 1
  done
}

check_updates() {
  # These upstream repositories are configuration trees, not versioned CLI
  # artifacts managed by the RaVN update contract.
  RAVN_UPDATE_RESULT="unsupported"
  return 1
}

update() {
  RAVN_UPDATE_RESULT="unsupported"
  return 1
}

reset() {
  rm -rf "${NVIM_VIMS_DIR}/adivim" "${NVIM_VIMS_DIR}/2kvim" \
    "${NVIM_BIN_DIR}/adivim" "${NVIM_BIN_DIR}/2kvim"
}

verify_reset() {
  [[ ! -e "${NVIM_VIMS_DIR}/adivim" ]] &&
    [[ ! -e "${NVIM_VIMS_DIR}/2kvim" ]] &&
    [[ ! -e "${NVIM_BIN_DIR}/adivim" ]] &&
    [[ ! -e "${NVIM_BIN_DIR}/2kvim" ]]
}
