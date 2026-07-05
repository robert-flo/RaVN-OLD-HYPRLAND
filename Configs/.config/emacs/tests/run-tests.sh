#!/usr/bin/env bash
# Run regression tests for universal-launcher from the durable tests folder.
# Re-run after any change to lisp/custom/universal-launcher.el.

set -e
emacs -Q --batch -l "${HOME}/.config/emacs/tests/test-universal-launcher.el"
