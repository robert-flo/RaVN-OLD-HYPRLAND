#!/usr/bin/env bash
# ─── RaVN Framework v1 — Default Package Contract ───────────────────────────
# Sourced before each task module to reset all lifecycle variables and provide
# safe no-op defaults for optional hooks. Task modules override only what they
# need.

# ─── Module metadata ────────────────────────────────────────────────────────
# shellcheck disable=SC2034
PACKAGE=""
DESCRIPTION=""
CATEGORY=""
DEPENDS=()

# Task runner metadata. Empty defaults preserve compatibility with legacy tasks;
# the contract validator reports these fields as incomplete until migrated.
TASK_ID=""
TASK_FAMILY=""
INSTALLER_STRATEGY=""
TEST_LEVEL=""

# Optional evidence context. Tasks populate resolved versions when known; the
# framework records them without coupling the runner to a package backend.
RAVN_EVIDENCE_REQUESTED_VERSION=""
RAVN_EVIDENCE_RESOLVED_VERSION=""
RAVN_EVIDENCE_RUNTIME_VERSION=""
RAVN_EVIDENCE_MISE_VERSION=""
RAVN_EVIDENCE_UPSTREAM_SHA256=""
RAVN_DEPENDENCY_MISSING=false

# Set to true for packages requiring user confirmation before install
INTERACTIVE=false
REFERENCE_ONLY=false

ravn_source_mise_cli() {
  local framework_path="${RAVN_DIR}/framework/mise-cli.sh"

  if [[ -f $framework_path ]]; then
    # shellcheck disable=SC1090
    source "$framework_path"
  else
    # shellcheck disable=SC1091
    source /mise-cli.sh
  fi
}

ravn_mise_cli_task() {
  ravn_source_mise_cli
  mise_cli_task
}

ravn_source_upstream() {
  local framework_path="${RAVN_DIR}/framework/upstream.sh"

  if [[ -f $framework_path ]]; then
    # shellcheck disable=SC1090
    source "$framework_path"
  else
    # shellcheck disable=SC1091
    source /upstream.sh
  fi
}

ravn_upstream_task() {
  ravn_source_upstream
  upstream_task
}

ravn_cli_task() {
  case ${CLI_INSTALLER:-mise} in
  mise)
    ravn_mise_cli_task
    ;;
  upstream)
    UPSTREAM_COMMAND="$CLI_COMMAND"
    UPSTREAM_INSTALL_URL="$CLI_INSTALL_URL"
    if declare -p CLI_VERSION_ARGS &>/dev/null; then
      UPSTREAM_VERSION_ARGS=("${CLI_VERSION_ARGS[@]}")
    fi
    if declare -p CLI_UPDATE_CHECK_ARGS &>/dev/null; then
      UPSTREAM_UPDATE_CHECK_ARGS=("${CLI_UPDATE_CHECK_ARGS[@]}")
    fi
    if declare -p CLI_UPDATE_ARGS &>/dev/null; then
      UPSTREAM_UPDATE_ARGS=("${CLI_UPDATE_ARGS[@]}")
    fi
    if declare -p CLI_INSTALL_ARGS &>/dev/null; then
      UPSTREAM_INSTALL_ARGS=("${CLI_INSTALL_ARGS[@]}")
    fi
    UPSTREAM_INSTALL_DIR_ENV="${CLI_INSTALL_DIR_ENV:-}"
    ravn_upstream_task
    ;;
  *)
    printf 'Error: unsupported CLI installer: %s\n' "${CLI_INSTALLER}" >&2
    return 1
    ;;
  esac
}

# ─── Lifecycle hooks (no-op defaults) ────────────────────────────────────────
# before  — Pre-install preparation (create dirs, fetch keys, etc.)
# check   — Return 0 if the package is already installed/configured (skip).
#            Return 1 to proceed with install.
# install — Main installation logic.
# after   — Post-install configuration.
# cleanup — Cleanup temporary resources (always runs, even on failure).

before() { :; }
check() { return 1; }
install() { :; }
verify() { :; }
check_updates() { :; }
update() { :; }
after() { :; }
cleanup() { :; }
reset() { :; }
verify_reset() { :; }
