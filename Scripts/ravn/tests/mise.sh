#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR
export XDG_CACHE_HOME
XDG_CACHE_HOME=$(mktemp -d)
trap 'rm -rf "$XDG_CACHE_HOME"' EXIT

# shellcheck disable=SC1091
source "${RAVN_DIR}/framework/mise.sh"

fixture_bin="${XDG_CACHE_HOME}/mise"
cat >"$fixture_bin" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '2026.6.11 linux-x64'
EOF
chmod +x "$fixture_bin"

export RAVN_MISE_BIN="$fixture_bin"
ravn_verify_mise >/dev/null
[[ $RAVN_EVIDENCE_MISE_VERSION == "2026.6.11" ]]
ravn_bootstrap_mise >/dev/null
[[ $RAVN_EVIDENCE_MISE_VERSION == "2026.6.11" ]]

export RAVN_MISE_BIN="${XDG_CACHE_HOME}/missing-mise"
export RAVN_ALLOW_MISE_BOOTSTRAP=0
if ravn_bootstrap_mise; then
  printf 'FAIL: host bootstrap was enabled without opt-in\n' >&2
  exit 1
fi

printf 'PASS: controlled mise bootstrap\n'
