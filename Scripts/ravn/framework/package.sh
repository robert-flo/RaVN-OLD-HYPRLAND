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

# Set to true for packages requiring user confirmation before install
INTERACTIVE=false

# ─── Lifecycle hooks (no-op defaults) ────────────────────────────────────────
# before  — Pre-install preparation (create dirs, fetch keys, etc.)
# check   — Return 0 if the package is already installed/configured (skip).
#            Return 1 to proceed with install.
# install — Main installation logic.
# after   — Post-install configuration.
# cleanup — Cleanup temporary resources (always runs, even on failure).

before()  { :; }
check()   { return 1; }
install() { :; }
after()   { :; }
cleanup() { :; }
