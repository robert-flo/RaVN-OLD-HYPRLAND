#!/usr/bin/env bash
# ─── RaVN Framework v1 — Hook Execution ─────────────────────────────────────
# Helpers to detect and run optional lifecycle hooks.
# Hooks are automatically detected — no manual registration needed.

# _RAVN_NOOP_BODY stores the normalized body of a no-op function for comparison.
# Used to detect if a task actually redefined a hook or left the default.
readonly _RAVN_NOOP_BODY=$'{ \n    :;\n}'

# hook_defined <function_name>
#   Returns 0 if the function exists and its body differs from the default no-op.
hook_defined() {
  local fn="$1"

  # Function must exist
  if ! declare -f "$fn" &>/dev/null; then
    return 1
  fi

  # Extract the body (everything after the first line of declare -f output)
  local body
  body=$(declare -f "$fn" | tail -n +2)

  # Compare against the no-op body
  [[ "$body" != "$_RAVN_NOOP_BODY" ]]
}

# run_hook <function_name> [label]
#   Executes the hook if it was redefined by the task module.
#   Returns 0 if the hook was not defined (skip is success).
run_hook() {
  local fn="$1"
  local label="${2:-$fn}"

  if hook_defined "$fn"; then
    "$fn"
  fi
}
