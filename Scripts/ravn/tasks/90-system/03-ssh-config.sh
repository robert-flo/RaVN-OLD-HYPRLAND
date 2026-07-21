#!/usr/bin/env bash
# ─── RaVN Task: SSH Config Reference ───────────────────────────────────────

# shellcheck disable=SC2034
ADMIN_TASK_ID="ssh-config"
# shellcheck disable=SC2034
ADMIN_TASK_FAMILY="system-config"
# shellcheck disable=SC2034
ADMIN_EXECUTION_PROFILE="system-config"
# shellcheck disable=SC2034
ADMIN_REQUIRES_PRIVILEGE=false
# shellcheck disable=SC2034
ADMIN_OWNED_RESOURCES=("${HOME}/.ssh/config managed-section:ravn-ssh-config")
# shellcheck disable=SC2034
ADMIN_RESOURCE_CONFLICTS=("unmanaged Host ravnvm" "unmanaged AddKeysToAgent")
# shellcheck disable=SC2034
ADMIN_REVERSIBILITY="reversible"
# shellcheck disable=SC2034
ADMIN_ACTIVATION_BOUNDARY="new SSH connection"
# shellcheck disable=SC2034
ADMIN_TEST_LEVEL="isolated,docker,host"

SSH_CONFIG="${HOME}/.ssh/config"
SSH_MARKER_START='# >>> ravn managed ssh-config >>>'
SSH_MARKER_END='# <<< ravn managed ssh-config <<<'
SSH_BACKUP="${SSH_CONFIG}.ravn-backup"

_ravnvm_block_compatible() {
  local block=""
  block=$(awk '/^Host[[:space:]]+ravnvm([[:space:]]|$)/ {inside=1} inside {print} inside && NR > 1 && /^Host[[:space:]]/ && $0 !~ /^Host[[:space:]]+ravnvm([[:space:]]|$)/ {exit}' "$SSH_CONFIG")
  [[ $block == *$'\n    HostName 127.0.0.1'* || $block == HostName\ 127.0.0.1* ]] &&
    [[ $block == *$'\n    Port 2222'* ]] &&
    [[ $block == *$'\n    User arch'* ]] &&
    [[ $block == *$'\n    StrictHostKeyChecking no'* ]] &&
    [[ $block == *$'\n    UserKnownHostsFile /dev/null'* ]]
}

admin_plan() {
  ADMIN_PLAN_ACTIONS=("ensure ~/.ssh/config permissions" "replace only the ravn managed section")
  if [[ -f $SSH_CONFIG ]]; then
    grep -q "$SSH_MARKER_START" "$SSH_CONFIG" && grep -q "$SSH_MARKER_END" "$SSH_CONFIG" || true
    if grep -qE '^Host[[:space:]]+ravnvm([[:space:]]|$)' "$SSH_CONFIG" &&
      ! grep -q "$SSH_MARKER_START" "$SSH_CONFIG" &&
      ! _ravnvm_block_compatible; then
      ADMIN_PLAN_CONFLICT="unmanaged Host ravnvm"
      return 1
    fi
  fi
}

admin_apply() {
  local temp content has_ravnvm=false
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  if [[ -f $SSH_CONFIG ]]; then
    cp -p "$SSH_CONFIG" "$SSH_BACKUP"
    content=$(awk -v start="$SSH_MARKER_START" -v end="$SSH_MARKER_END" '
      $0 == start {inside=1; next} $0 == end {inside=0; next} !inside {print}
    ' "$SSH_CONFIG")
  else
    : > "$SSH_BACKUP"
    content=''
  fi
  grep -qE '^Host[[:space:]]+ravnvm([[:space:]]|$)' "$SSH_CONFIG" 2> /dev/null && has_ravnvm=true
  temp=$(mktemp "${SSH_CONFIG}.tmp.XXXXXX")
  {
    [[ -z $content ]] || printf '%s\n' "$content"
    printf '%s\n' "$SSH_MARKER_START"
    cat << 'EOF'
Host *
    AddKeysToAgent yes
EOF
    if [[ $has_ravnvm == false ]]; then
      cat << 'EOF'
Host ravnvm
    HostName 127.0.0.1
    Port 2222
    User arch
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    fi
    printf '%s\n' "$SSH_MARKER_END"
  } > "$temp"
  chmod 600 "$temp"
  mv "$temp" "$SSH_CONFIG"
}

admin_verify() {
  [[ -f $SSH_CONFIG && $(stat -c '%a' "$SSH_CONFIG") == 600 ]] || return 1
  [[ ${RAVN_ADMIN_SCENARIO:-} != verify-failure ]] || return 1
  ssh -G -F "$SSH_CONFIG" ravnvm > /dev/null 2>&1
}

admin_rollback() {
  [[ -f $SSH_BACKUP ]] || return 1
  cp -p "$SSH_BACKUP" "$SSH_CONFIG"
}

admin_reset() {
  local temp content
  [[ -f $SSH_CONFIG ]] || return 0
  content=$(awk -v start="$SSH_MARKER_START" -v end="$SSH_MARKER_END" '
    $0 == start {inside=1; next} $0 == end {inside=0; next} !inside {print}
  ' "$SSH_CONFIG")
  temp=$(mktemp "${SSH_CONFIG}.tmp.XXXXXX")
  printf '%s\n' "$content" > "$temp"
  chmod 600 "$temp"
  mv "$temp" "$SSH_CONFIG"
}

admin_verify_reset() {
  [[ ! -f $SSH_CONFIG ]] || ! grep -q "$SSH_MARKER_START" "$SSH_CONFIG"
}

check() { admin_verify; }
install() { admin_apply; }
verify() { admin_verify; }
reset() { admin_reset; }
verify_reset() { admin_verify_reset; }
