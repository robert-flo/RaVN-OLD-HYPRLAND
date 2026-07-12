#!/usr/bin/env bash
set -euo pipefail

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
fake_bin="$root/bin"
state="$root/state"
mkdir -p "$fake_bin"
cat > "$fake_bin/systemctl" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
action="${2:-}"
state_file="${RAVN_SSH_AGENT_STATE:?}"
case "$action" in
  enable) printf 'enabled=1 active=1\n' > "$state_file" ;;
  disable) printf 'enabled=0 active=0\n' > "$state_file" ;;
  is-enabled) grep -q enabled=1 "$state_file" ;;
  is-active) grep -q active=1 "$state_file" ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fake_bin/systemctl"
export PATH="$fake_bin:$PATH" RAVN_SSH_AGENT_STATE="$state"
printf 'enabled=0 active=0\n' > "$state"
# shellcheck disable=SC1090
source "$RAVN_TASK"
admin_plan
admin_reset
admin_verify_reset
admin_apply
admin_verify
admin_reset
admin_verify_reset
printf 'PASS: SSH agent Docker lifecycle\n'
