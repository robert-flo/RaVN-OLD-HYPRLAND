#!/usr/bin/env bash
# ─── RaVN Task: Hermes Agent CLI ─────────────────────────────────────────────
# Requires: curl

# shellcheck disable=SC2034,SC2154
PACKAGE="hermes"
DESCRIPTION="Nous Research Hermes Agent CLI"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  command -v hermes &> /dev/null
}

install() {
  if ((flg_DryRun == 1)); then
    info "Simulación: Saltando instalación de Hermes."
    return 0
  fi

  if ! command -v curl &> /dev/null; then
    echo "Error: curl not found" >&2
    return 1
  fi
#  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
}
