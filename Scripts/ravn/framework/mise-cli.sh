#!/usr/bin/env bash
# ─── RaVN Framework — Generic mise-managed CLI backend ─────────────────────

mise_cli_task() {
  local task_name="${CLI_COMMAND//[^a-zA-Z0-9_-]/-}"
  local task_root="${XDG_DATA_HOME:-${HOME}/.local/share}/ravn/tasks/${task_name}"

  # shellcheck disable=SC2034
  PACKAGE="${CLI_COMMAND}"
  # shellcheck disable=SC2034
  TASK_ID="${CLI_COMMAND}"
  # shellcheck disable=SC2034
  DESCRIPTION="${CLI_DESCRIPTION:-${CLI_COMMAND} managed by mise}"
  # shellcheck disable=SC2034
  TASK_FAMILY="cli-tools"
  # shellcheck disable=SC2034
  INSTALLER_STRATEGY="mise"
  # shellcheck disable=SC2034
  TEST_LEVEL="isolated"
  # shellcheck disable=SC2034
  if [[ ${CLI_MISE_TOOL:-npm:} == npm:* ]]; then
    DEPENDS=("mise" "node")
  else
    DEPENDS=("mise")
  fi
  # shellcheck disable=SC2034
  INTERACTIVE=false

  MISE_CLI_PACKAGE="${CLI_PACKAGE:-}"
  MISE_CLI_COMMAND="$CLI_COMMAND"
  MISE_CLI_TOOL="${CLI_MISE_TOOL:-npm:${CLI_PACKAGE:-}}"
  MISE_CLI_VERSION="${CLI_VERSION:-latest}"
  MISE_CLI_NODE_VERSION="${CLI_NODE_VERSION:-latest}"
  MISE_CLI_VERIFY_ARGS=("${CLI_VERIFY_ARGS:---version}")
  MISE_CLI_ROOT="$task_root"
  MISE_CLI_CONFIG_DIR="${task_root}/mise"
  MISE_CLI_CONFIG_FILE="${MISE_CLI_CONFIG_DIR}/mise.toml"
  MISE_CLI_CANDIDATE_DIR="${task_root}/candidate"
  MISE_CLI_PREVIOUS_DIR="${task_root}/previous"
  MISE_CLI_WRAPPER="${HOME}/.local/bin/${MISE_CLI_COMMAND}"
  RAVN_UPDATE_AVAILABLE=false
  RAVN_UPDATE_RESULT=""
}

mise_cli_bin() {
  if ! ravn_verify_mise >/dev/null; then
    # shellcheck disable=SC2034
    RAVN_DEPENDENCY_MISSING=true
    return 1
  fi
  ravn_mise_binary
}

mise_cli_write_config() {
  local config_dir="$1"

  mkdir -p "$config_dir" || return 1
  if [[ $MISE_CLI_TOOL != npm:* ]]; then
    cat >"${config_dir}/mise.toml" <<EOF
[tools]
"${MISE_CLI_TOOL}" = "${MISE_CLI_VERSION}"
EOF
    return 0
  fi
  cat >"${config_dir}/mise.toml" <<EOF
[tools]
node = "${MISE_CLI_NODE_VERSION}"
"npm:${MISE_CLI_PACKAGE}" = "${MISE_CLI_VERSION}"
EOF
  cat >"${config_dir}/.npmrc" <<'EOF'
allow-scripts=true
EOF
}

mise_cli_record_versions() {
  local mise_bin="$1"
  local config_dir="$2"
  local command_version=""
  local node_version=""

  command_version=$("$mise_bin" exec --cd "$config_dir" -- "$MISE_CLI_COMMAND" "${MISE_CLI_VERIFY_ARGS[@]}") || return 1
  if [[ $MISE_CLI_TOOL == npm:* ]]; then
    node_version=$("$mise_bin" exec --cd "$config_dir" -- node --version) || return 1
  fi
  [[ -n $command_version ]] || return 1

  # shellcheck disable=SC2034
  RAVN_EVIDENCE_REQUESTED_VERSION="$MISE_CLI_VERSION"
  RAVN_EVIDENCE_RESOLVED_VERSION="${command_version%%$'\n'*}"
  # shellcheck disable=SC2034
  RAVN_EVIDENCE_RUNTIME_VERSION="${node_version#v}"
}

mise_cli_write_wrapper() {
  local mise_bin="$1"

  cat >"$MISE_CLI_WRAPPER" <<EOF
#!/usr/bin/env bash
exec "$mise_bin" exec --cd "$MISE_CLI_CONFIG_DIR" -- "$MISE_CLI_COMMAND" "\$@"
EOF
  [[ -s $MISE_CLI_WRAPPER ]] || return 1
  chmod +x "$MISE_CLI_WRAPPER"
}

mise_cli_install_config() {
  local mise_bin="$1"
  local config_dir="$2"
  local install_root=""
  local package_version=""
  local postinstall=""

  mise_cli_write_config "$config_dir" || return 1
  "$mise_bin" --cd "$config_dir" install --yes || return 1

  if [[ $MISE_CLI_TOOL != npm:* ]]; then
    mise_cli_record_versions "$mise_bin" "$config_dir"
    return $?
  fi
  install_root=$("$mise_bin" where "${MISE_CLI_TOOL}@${MISE_CLI_VERSION}") || return 1
  package_version=$("$mise_bin" exec --cd "$config_dir" -- node -p \
    "require('${install_root}/lib/node_modules/${MISE_CLI_PACKAGE}/package.json').version") || return 1
  [[ -n $package_version ]] || return 1
  postinstall="${install_root}/lib/node_modules/${MISE_CLI_PACKAGE}/postinstall.mjs"
  if [[ -f $postinstall ]]; then
    "$mise_bin" exec --cd "$config_dir" -- node "$postinstall" || return 1
  fi

  mise_cli_record_versions "$mise_bin" "$config_dir"
}

check() {
  verify
}

install() {
  local mise_bin=""

  mise_bin=$(mise_cli_bin) || return 1
  mkdir -p "${HOME}/.local/bin" || return 1
  mise_cli_install_config "$mise_bin" "$MISE_CLI_CONFIG_DIR" || return 1
  mise_cli_write_wrapper "$mise_bin" || return 1
  mise_cli_record_versions "$mise_bin" "$MISE_CLI_CONFIG_DIR"
}

verify() {
  local mise_bin=""
  local wrapper_output=""

  [[ -x $MISE_CLI_WRAPPER && -f $MISE_CLI_CONFIG_FILE ]] || return 1
  mise_bin=$(mise_cli_bin) || return 1
  mise_cli_record_versions "$mise_bin" "$MISE_CLI_CONFIG_DIR" || return 1
  wrapper_output=$("$MISE_CLI_WRAPPER" "${MISE_CLI_VERIFY_ARGS[@]}" 2>/dev/null) || return 1
  [[ -n $wrapper_output ]]
}

check_updates() {
  local mise_bin=""
  local current_version=""
  local latest_version=""

  verify || return 1
  mise_bin=$(mise_cli_bin) || return 1
  current_version="$RAVN_EVIDENCE_RESOLVED_VERSION"
  if [[ $MISE_CLI_TOOL != npm:* ]]; then
    latest_version=$("$mise_bin" outdated --cd "$MISE_CLI_CONFIG_DIR" --local --no-header 2>&1) || return 1
    RAVN_UPDATE_AVAILABLE=false
    if [[ -n $latest_version && $latest_version != *"up to date"* ]]; then
      RAVN_UPDATE_AVAILABLE=true
      printf '%s\n' "$latest_version"
    else
      printf '%s is up to date: %s\n' "$MISE_CLI_COMMAND" "$current_version"
    fi
    return 0
  fi
  latest_version=$("$mise_bin" exec --cd "$MISE_CLI_CONFIG_DIR" -- npm view "$MISE_CLI_PACKAGE" version) || return 1
  # shellcheck disable=SC2034
  RAVN_UPDATE_AVAILABLE=false
  if [[ $latest_version != "$current_version" ]]; then
    # shellcheck disable=SC2034
    RAVN_UPDATE_AVAILABLE=true
    printf '%s update available: %s -> %s\n' "$MISE_CLI_COMMAND" "$current_version" "$latest_version"
  else
    printf '%s is up to date: %s\n' "$MISE_CLI_COMMAND" "$current_version"
  fi
}

update() {
  local mise_bin=""

  RAVN_UPDATE_RESULT=""
  verify || return 1
  mise_bin=$(mise_cli_bin) || return 1
  rm -rf "$MISE_CLI_CANDIDATE_DIR"
  if ! mise_cli_install_config "$mise_bin" "$MISE_CLI_CANDIDATE_DIR"; then
    # shellcheck disable=SC2034
    RAVN_UPDATE_RESULT="update-failed"
    return 1
  fi

  rm -rf "$MISE_CLI_PREVIOUS_DIR"
  mkdir -p "$MISE_CLI_PREVIOUS_DIR" || return 1
  cp "$MISE_CLI_CONFIG_FILE" "${MISE_CLI_PREVIOUS_DIR}/mise.toml" || return 1

  local promote_ok=false

  if cp "${MISE_CLI_CANDIDATE_DIR}/mise.toml" "$MISE_CLI_CONFIG_FILE" &&
    mise_cli_write_wrapper "$mise_bin"; then
    if [[ ${RAVN_TEST_UPDATE_VERIFY_FAIL:-0} == 1 ]]; then
      promote_ok=false
    elif verify; then
      promote_ok=true
    fi
  fi

  if [[ $promote_ok == true ]]; then
    rm -rf "$MISE_CLI_CANDIDATE_DIR"
    return 0
  fi

  if cp "${MISE_CLI_PREVIOUS_DIR}/mise.toml" "$MISE_CLI_CONFIG_FILE" &&
    mise_cli_write_wrapper "$mise_bin" && verify; then
    # shellcheck disable=SC2034
    RAVN_UPDATE_RESULT="update-failed"
    return 1
  fi

  # shellcheck disable=SC2034
  RAVN_UPDATE_RESULT="rollback-failed"
  return 1
}

reset() {
  rm -f "$MISE_CLI_WRAPPER"
  rm -rf "$MISE_CLI_ROOT"
}

verify_reset() {
  [[ ! -e $MISE_CLI_WRAPPER && ! -e $MISE_CLI_ROOT ]]
}
