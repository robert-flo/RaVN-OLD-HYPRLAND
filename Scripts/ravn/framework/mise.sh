#!/usr/bin/env bash
# ─── RaVN Framework v1 — Controlled mise Bootstrap ──────────────────────────

readonly RAVN_MISE_FIXTURE_VERSION_DEFAULT="2026.6.11"

ravn_mise_fixture_version() {
  printf '%s' "${RAVN_MISE_FIXTURE_VERSION:-$RAVN_MISE_FIXTURE_VERSION_DEFAULT}"
}

ravn_mise_binary() {
  local configured_bin="${RAVN_MISE_BIN:-}"

  if [[ -n $configured_bin ]]; then
    [[ -x $configured_bin ]] || return 1
    printf '%s' "$configured_bin"
    return 0
  fi

  command -v mise
}

ravn_mise_version() {
  local mise_bin="$1"
  local output=""

  output=$("$mise_bin" --version) || return 1
  printf '%s\n' "${output%% *}"
}

ravn_verify_mise() {
  local mise_bin=""
  local version=""

  mise_bin=$(ravn_mise_binary) || return 1
  version=$(ravn_mise_version "$mise_bin") || return 1
  [[ -n $version ]] || return 1

  RAVN_EVIDENCE_MISE_VERSION="$version"
  printf '%s' "$mise_bin"
}

ravn_bootstrap_mise() {
  local requested_version=""
  local bootstrap_dir=""
  local mise_bin=""
  local machine=""
  local architecture=""
  local url=""

  if mise_bin=$(ravn_mise_binary); then
    if ravn_verify_mise >/dev/null; then
      printf '%s' "$mise_bin"
      return 0
    fi
  fi

  if [[ ${RAVN_ALLOW_MISE_BOOTSTRAP:-0} != "1" ]]; then
    printf '%s\n' "Error: mise no está disponible; use RAVN_ALLOW_MISE_BOOTSTRAP=1 para permitir bootstrap." >&2
    return 1
  fi

  requested_version=$(ravn_mise_fixture_version)
  bootstrap_dir="${RAVN_MISE_BOOTSTRAP_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/ravn/mise}/${requested_version}"
  mise_bin="${bootstrap_dir}/mise"
  machine=$(uname -m)
  case "$machine" in
  x86_64) architecture="x64" ;;
  aarch64) architecture="arm64" ;;
  *)
    printf '%s\n' "Error: arquitectura no soportada para mise fixture: ${machine}" >&2
    return 1
    ;;
  esac

  mkdir -p "$bootstrap_dir"
  url="https://github.com/jdx/mise/releases/download/v${requested_version}/mise-v${requested_version}-linux-${architecture}"
  curl --fail --location --retry 3 --silent --show-error "$url" -o "$mise_bin" || return 1
  chmod +x "$mise_bin"

  RAVN_MISE_BIN="$mise_bin"
  export RAVN_MISE_BIN
  if ! ravn_verify_mise >/dev/null; then
    printf '%s\n' "Error: mise fixture descargado no pudo verificarse." >&2
    return 1
  fi
  if [[ $RAVN_EVIDENCE_MISE_VERSION != "$requested_version" ]]; then
    printf '%s\n' "Error: mise fixture resolvió ${RAVN_EVIDENCE_MISE_VERSION}, se esperaba ${requested_version}." >&2
    return 1
  fi

  printf '%s' "$mise_bin"
}
