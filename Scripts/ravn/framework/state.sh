#!/usr/bin/env bash
# ─── RaVN Framework v1 — State Management (Skeleton) ────────────────────────
# Minimal persistent state using key-value files.
# Reserved for future use (e.g., tracking which tasks have run).

_STATE_DIR="${RAVN_DIR}/cache/state"

# Ensure the state directory exists
mkdir -p "$_STATE_DIR" 2>/dev/null || true

# state_set <key> <value>
#   Persist a key-value pair.
state_set() {
  local key="$1" value="$2"
  printf '%s' "$value" > "${_STATE_DIR}/${key}"
}

# state_get <key>
#   Print the stored value for a key. Returns 1 if not found.
state_get() {
  local key="$1"
  local file="${_STATE_DIR}/${key}"

  if [[ -f $file ]]; then
    cat "$file"
  else
    return 1
  fi
}

# state_has <key>
#   Returns 0 if the key exists in state, 1 otherwise.
state_has() {
  [[ -f "${_STATE_DIR}/${1}" ]]
}
