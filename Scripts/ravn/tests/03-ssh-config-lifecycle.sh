#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TASK="${RAVN_DIR}/tasks/90-system/03-ssh-config.sh"

run_case() {
  local name=$1 initial=${2:-} scenario=${3:-success}
  local root config after original
  root=$(mktemp -d "${TMPDIR:-/tmp}/ravn-ssh-test.XXXXXX")
  cleanup() { rm -rf "$root"; }
  export HOME="$root" RAVN_ADMIN_SCENARIO="$scenario"
  mkdir -p "$HOME/.ssh"
  [[ -z $initial ]] || printf '%s\n' "$initial" > "$HOME/.ssh/config"
  # shellcheck disable=SC1090
  source "$TASK"
  config="$HOME/.ssh/config"
  original=$(cat "$config" 2> /dev/null || true)
  if [[ $name == conflict ]]; then
    if admin_plan; then
      cleanup
      return 1
    fi
    cleanup
    return
  fi
  admin_plan
  admin_apply
  if [[ $name == malformed ]]; then
    if admin_verify; then
      cleanup
      return 1
    fi
    admin_reset
    cleanup
    return
  fi
  if [[ $scenario == verify-failure ]]; then
    if admin_verify; then
      cleanup
      return 1
    fi
    cp "$config" "$config.failed"
    admin_rollback
    [[ $(cat "$config") == "$original" ]]
    admin_reset
    cleanup
    return
  fi
  admin_verify
  admin_apply
  after=$(cat "$config")
  admin_reset
  [[ $name != existing || $after == *'unmanaged content'* ]]
  [[ $name != existing || $(cat "$config") == *'unmanaged content'* ]]
  [[ $(grep -c "$SSH_MARKER_START" "$config" || true) -eq 0 ]]
  admin_apply
  admin_verify
  cleanup
}

run_case missing
run_case empty ''
run_case existing $'Host preserved\n    HostName example.test\n# unmanaged content'
run_case compatible $'Host ravnvm\n    HostName 127.0.0.1\n    Port 2222\n    User arch\n    StrictHostKeyChecking no\n    UserKnownHostsFile /dev/null'
run_case malformed $'Host *\n    BadOption'
run_case conflict $'Host ravnvm\n    HostName conflicting.test' conflict
run_case partial '' verify-failure
printf 'PASS: SSH administrative lifecycle\n'
