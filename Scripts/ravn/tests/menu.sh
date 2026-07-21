#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

# shellcheck disable=SC1091
source "${RAVN_DIR}/global_fn.sh"
for fw in "${RAVN_DIR}"/framework/*.sh; do
  # shellcheck disable=SC1090
  source "$fw"
done

output=""
output=$(printf 'q\n' | run_menu)

grep -q "Verify current configuration" <<<"$output"
grep -q "Run full setup" <<<"$output"
grep -q "Run integration test" <<<"$output"
grep -q "Reset selected tasks" <<<"$output"
grep -q "Exit" <<<"$output"

printf 'PASS: task menu\n'
