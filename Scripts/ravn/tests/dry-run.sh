#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

output=""
output=$(flg_DryRun=1 bash "${RAVN_DIR}/setup.sh" 2>&1)

grep -q "Dry-run" <<<"$output"
grep -q "ghui" <<<"$output"

printf 'PASS: dry-run pipeline\n'
