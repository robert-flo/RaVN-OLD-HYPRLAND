#!/usr/bin/env bash
# ─── RaVN Task: OpenCode CLI (mise reference lifecycle) ─────────────────────

# shellcheck disable=SC2034
PACKAGE="opencode-mise"
# shellcheck disable=SC2034
TASK_ID="opencode-mise"
DESCRIPTION="OpenCode CLI managed by mise"
# shellcheck disable=SC2034
TASK_FAMILY="cli-tools"
# shellcheck disable=SC2034
INSTALLER_STRATEGY="mise"
# shellcheck disable=SC2034
TEST_LEVEL="isolated"
DEPENDS=("mise" "node")
INTERACTIVE=false
REFERENCE_ONLY=true

OPENCODE_PACKAGE="opencode-ai"
OPENCODE_VERSION_REQUEST="latest"
OPENCODE_NODE_REQUEST="latest"
OPENCODE_COMMAND="opencode-mise"
OPENCODE_ROOT="${XDG_DATA_HOME:-${HOME}/.local/share}/ravn/tasks/opencode-mise"
OPENCODE_CONFIG_DIR="${OPENCODE_ROOT}/mise"
OPENCODE_CONFIG_FILE="${OPENCODE_CONFIG_DIR}/mise.toml"
OPENCODE_CANDIDATE_DIR="${OPENCODE_ROOT}/candidate"
OPENCODE_PREVIOUS_DIR="${OPENCODE_ROOT}/previous"
OPENCODE_WRAPPER="${HOME}/.local/bin/${OPENCODE_COMMAND}"
RAVN_UPDATE_AVAILABLE=false
RAVN_UPDATE_RESULT=""

opencode_mise_bin() {
  if ! ravn_verify_mise >/dev/null; then
    RAVN_DEPENDENCY_MISSING=true
    return 1
  fi
  ravn_mise_binary
}

opencode_record_config_versions() {
  local mise_bin="$1"
  local config_dir="$2"
  local command_version=""
  local node_version=""

  command_version=$("$mise_bin" exec --cd "$config_dir" -- opencode --version) || return 1
  node_version=$("$mise_bin" exec --cd "$config_dir" -- node --version) || return 1

  RAVN_EVIDENCE_REQUESTED_VERSION="$OPENCODE_VERSION_REQUEST"
  RAVN_EVIDENCE_RESOLVED_VERSION="${command_version%%$'\n'*}"
  RAVN_EVIDENCE_RUNTIME_VERSION="${node_version#v}"
}

opencode_write_wrapper() {
  local mise_bin="$1"

  cat >"$OPENCODE_WRAPPER" <<EOF
#!/usr/bin/env bash
exec "$mise_bin" exec --cd "$OPENCODE_CONFIG_DIR" -- opencode "\$@"
EOF
  [[ -s $OPENCODE_WRAPPER ]] || return 1
  chmod +x "$OPENCODE_WRAPPER"
}

opencode_write_config() {
  local config_dir="$1"

  mkdir -p "$config_dir" || return 1
  cat >"${config_dir}/mise.toml" <<EOF
[tools]
node = "${OPENCODE_NODE_REQUEST}"
"npm:${OPENCODE_PACKAGE}" = {
  version = "${OPENCODE_VERSION_REQUEST}",
  allow_builds = true,
  npm_args = "--ignore-scripts=false",
}
EOF
}

opencode_install_config() {
  local mise_bin="$1"
  local config_dir="$2"
  local config_file="${config_dir}/mise.toml"
  local install_root=""
  local package_version=""
  local postinstall=""

  opencode_write_config "$config_dir" || return 1
  "$mise_bin" --cd "$config_dir" install --yes || return 1

  install_root=$("$mise_bin" where "npm:${OPENCODE_PACKAGE}@${OPENCODE_VERSION_REQUEST}")
  package_version=$("$mise_bin" exec --cd "$config_dir" -- node -p \
    "require('${install_root}/lib/node_modules/${OPENCODE_PACKAGE}/package.json').version")
  [[ -n $package_version ]] || return 1
  postinstall="${install_root}/lib/node_modules/${OPENCODE_PACKAGE}/postinstall.mjs"
  if [[ -f $postinstall ]]; then
    "$mise_bin" exec --cd "$config_dir" -- node "$postinstall" || return 1
  fi

  opencode_record_config_versions "$mise_bin" "$config_dir"
}

check() {
  verify
}

install() {
  local mise_bin=""

  mise_bin=$(opencode_mise_bin) || {
    echo "Error: mise no está instalado o no es funcional" >&2
    return 1
  }

  mkdir -p "${HOME}/.local/bin" || return 1
  opencode_install_config "$mise_bin" "$OPENCODE_CONFIG_DIR" || return 1
  opencode_write_wrapper "$mise_bin" || return 1
  opencode_record_config_versions "$mise_bin" "$OPENCODE_CONFIG_DIR" || return 1
}

verify() {
  local mise_bin=""

  [[ -x $OPENCODE_WRAPPER && -f $OPENCODE_CONFIG_FILE ]] || return 1
  mise_bin=$(opencode_mise_bin) || return 1
  opencode_record_config_versions "$mise_bin" "$OPENCODE_CONFIG_DIR"
}

check_updates() {
  local mise_bin=""
  local current_version=""
  local latest_version=""

  verify || return 1
  mise_bin=$(opencode_mise_bin) || return 1
  current_version="$RAVN_EVIDENCE_RESOLVED_VERSION"
  latest_version=$("$mise_bin" exec --cd "$OPENCODE_CONFIG_DIR" -- npm view "$OPENCODE_PACKAGE" version) || return 1
  RAVN_UPDATE_AVAILABLE=false
  if [[ $latest_version != "$current_version" ]]; then
    RAVN_UPDATE_AVAILABLE=true
    printf 'OpenCode update available: %s -> %s\n' "$current_version" "$latest_version"
  else
    printf 'OpenCode is up to date: %s\n' "$current_version"
  fi
}

update() {
  local mise_bin=""

  RAVN_UPDATE_RESULT=""
  verify || return 1
  mise_bin=$(opencode_mise_bin) || return 1

  rm -rf "$OPENCODE_CANDIDATE_DIR"
  if ! opencode_install_config "$mise_bin" "$OPENCODE_CANDIDATE_DIR"; then
    RAVN_UPDATE_RESULT="update-failed"
    return 1
  fi

  if ! opencode_record_config_versions "$mise_bin" "$OPENCODE_CANDIDATE_DIR"; then
    RAVN_UPDATE_RESULT="update-failed"
    return 1
  fi

  rm -rf "$OPENCODE_PREVIOUS_DIR"
  mkdir -p "$OPENCODE_PREVIOUS_DIR" || {
    RAVN_UPDATE_RESULT="update-failed"
    return 1
  }
  cp "$OPENCODE_CONFIG_FILE" "${OPENCODE_PREVIOUS_DIR}/mise.toml" || {
    RAVN_UPDATE_RESULT="update-failed"
    return 1
  }

  if cp "${OPENCODE_CANDIDATE_DIR}/mise.toml" "$OPENCODE_CONFIG_FILE" &&
    opencode_write_wrapper "$mise_bin" && verify; then
    rm -rf "$OPENCODE_CANDIDATE_DIR"
    return 0
  fi

  if cp "${OPENCODE_PREVIOUS_DIR}/mise.toml" "$OPENCODE_CONFIG_FILE" &&
    opencode_write_wrapper "$mise_bin" && verify; then
    RAVN_UPDATE_RESULT="update-failed"
    return 1
  fi

  RAVN_UPDATE_RESULT="rollback-failed"
  return 1
}

reset() {
  rm -f "$OPENCODE_WRAPPER"
  rm -rf "$OPENCODE_ROOT"
}

verify_reset() {
  [[ ! -e $OPENCODE_WRAPPER && ! -e $OPENCODE_ROOT ]]
}
