#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
root=$(mktemp -d "${TMPDIR:-/tmp}/ravn-ssh-agent-test.XXXXXX")
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
  enable)
    [[ ${RAVN_SSH_AGENT_SCENARIO:-success} != apply-failure ]]
    printf 'enabled=1 active=1\n' > "$state_file"
    ;;
  disable)
    printf 'enabled=0 active=0\n' > "$state_file"
    ;;
  is-enabled)
    grep -q 'enabled=1' "$state_file"
    ;;
  is-active)
    grep -q 'active=1' "$state_file"
    ;;
  *)
    printf 'unsupported systemctl action: %s\n' "$action" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$fake_bin/systemctl"

export PATH="$fake_bin:$PATH" RAVN_SSH_AGENT_STATE="$state"
printf 'enabled=0 active=0\n' > "$state"
# shellcheck disable=SC1090,SC1091
source "$RAVN_DIR/tasks/90-system/02-ssh-agent.sh"

admin_plan
admin_reset
admin_verify_reset
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

printf 'enabled=0 active=0\n' > "$state"
export RAVN_SSH_AGENT_SCENARIO=apply-failure
if admin_apply; then
  printf 'FAIL: apply failure unexpectedly passed\n' >&2
  exit 1
fi

printf 'PASS: SSH agent administrative lifecycle\n'
