#!/usr/bin/env bash
set -euo pipefail

root=$(mktemp -d)
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
exit 0
EOF
cat > "$fake_bin/ufw" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
state_file="${RAVN_UFW_STATE:?}"
case "${1:-}" in
  status) cat "$state_file" ;;
  allow) printf '%s ALLOW # %s\n' "$2" "$4" >> "$state_file" ;;
  delete) grep -vF "$3" "$state_file" > "$state_file.tmp" || true; mv "$state_file.tmp" "$state_file" ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fake_bin"/*
export PATH="$fake_bin:$PATH" RAVN_UFW_STATE="$state"
: > "$state"
# shellcheck disable=SC1090
source "$RAVN_TASK"
admin_plan
admin_apply
admin_verify
admin_reset
admin_verify_reset
printf 'PASS: firewall Docker lifecycle\n'
