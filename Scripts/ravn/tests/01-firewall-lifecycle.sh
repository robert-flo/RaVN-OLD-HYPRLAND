#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
root=$(mktemp -d "${TMPDIR:-/tmp}/ravn-firewall-test.XXXXXX")
trap 'rm -rf "$root"' EXIT

fake_bin="$root/bin"
state="$root/ufw-state"
mkdir -p "$fake_bin"

cat > "$fake_bin/sudo" << 'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
cat > "$fake_bin/systemctl" << 'EOF'
#!/usr/bin/env bash
if [[ ${RAVN_FIREWALL_SCENARIO:-active} == inactive ]]; then exit 1; fi
exit 0
EOF
cat > "$fake_bin/ufw" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
state_file="${RAVN_UFW_STATE:?}"
case "${1:-}" in
  status)
    cat "$state_file"
    ;;
  allow)
    [[ ${RAVN_FIREWALL_SCENARIO:-active} != apply-failure ]]
    printf '%s ALLOW # %s\n' "$2" "$4" >> "$state_file"
    ;;
  delete)
    pattern="$3"
    tmp=$(mktemp)
    grep -vF "$pattern" "$state_file" > "$tmp" || true
    mv "$tmp" "$state_file"
    ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fake_bin"/*

export PATH="$fake_bin:$PATH" RAVN_UFW_STATE="$state"
: > "$state"
# shellcheck disable=SC1090,SC1091
source "$RAVN_DIR/tasks/90-system/01-firewall.sh"

admin_plan
admin_apply
admin_verify
admin_apply
admin_verify
admin_rollback
admin_verify_reset
admin_reset
admin_verify_reset
admin_apply
admin_verify

printf '53317/tcp ALLOW from existing-service\n' > "$state"
admin_plan
admin_apply
admin_verify
admin_reset
grep -qF 'existing-service' "$state" || {
  printf 'FAIL: equivalent existing firewall rule was removed\n' >&2
  exit 1
}

printf '53317/tcp DENY from conflicting-service\n' > "$state"
if admin_plan; then
  printf 'FAIL: conflicting firewall rule was not detected\n' >&2
  exit 1
fi

: > "$state"
export RAVN_FIREWALL_SCENARIO=inactive
if admin_plan; then
  printf 'FAIL: inactive UFW was reported as ready\n' >&2
  exit 1
fi

export RAVN_FIREWALL_SCENARIO=active
: > "$state"
export RAVN_FIREWALL_SCENARIO=apply-failure
if admin_apply; then
  printf 'FAIL: UFW apply failure unexpectedly passed\n' >&2
  exit 1
fi

printf 'PASS: firewall administrative lifecycle\n'
