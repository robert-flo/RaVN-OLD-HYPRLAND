#!/usr/bin/env bash
set -euo pipefail

pacman -Sy --noconfirm --needed openssh awk coreutils diffutils > /dev/null

run_case() {
  local name=$1 home first second original
  home=$(mktemp -d)
  export HOME=$home RAVN_ADMIN_SCENARIO=success
  mkdir -p "$HOME/.ssh"
  if [[ $name == existing ]]; then
    printf '%s\n' 'Host preserved' '    HostName example.test' '# unmanaged content' > "$HOME/.ssh/config"
  fi
  # shellcheck disable=SC1090
  source "$RAVN_TASK"
  original=""
  [[ ! -f $SSH_CONFIG ]] || original=$(cat "$SSH_CONFIG")
  admin_plan
  admin_apply
  admin_verify
  first=$(sha256sum "$SSH_CONFIG")
  admin_apply
  second=$(sha256sum "$SSH_CONFIG")
  [[ $first == "$second" ]]
  grep -q 'Host ravnvm' "$SSH_CONFIG"
  grep -q 'AddKeysToAgent yes' "$SSH_CONFIG"
  [[ $(stat -c '%a' "$HOME/.ssh") == 700 ]]
  [[ $(stat -c '%a' "$SSH_CONFIG") == 600 ]]
  [[ $name != existing || $(grep -c '# unmanaged content' "$SSH_CONFIG") -eq 1 ]]
  admin_reset
  [[ $(grep -c "$SSH_MARKER_START" "$SSH_CONFIG" || true) -eq 0 ]]
  if [[ $name == existing ]]; then
    printf '%s\n' "$original" | cmp -s - "$SSH_CONFIG"
  fi
  rm -rf "$home"
}

run_rollback_case() {
  local home original
  home=$(mktemp -d)
  export HOME=$home RAVN_ADMIN_SCENARIO=verify-failure
  mkdir -p "$HOME/.ssh"
  printf '%s\n' 'Host preserved' '    HostName example.test' > "$HOME/.ssh/config"
  # shellcheck disable=SC1090
  source "$RAVN_TASK"
  original=$(cat "$SSH_CONFIG")
  admin_plan
  admin_apply
  if admin_verify; then exit 1; fi
  admin_rollback
  [[ $(cat "$SSH_CONFIG") == "$original" ]]
  rm -rf "$home"
}

run_case clean
run_case existing
run_rollback_case
printf 'PASS: SSH administrative Docker lifecycle\n'
