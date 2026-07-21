#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR
export XDG_STATE_HOME
XDG_STATE_HOME=$(mktemp -d)
trap 'rm -rf "$XDG_STATE_HOME"' EXIT

# shellcheck disable=SC1091
source "${RAVN_DIR}/framework/state.sh"

ravn_state_is_valid verified
ravn_state_is_valid rollback-failed
ravn_state_is_valid unsupported
if ravn_state_is_valid invalid; then
  printf 'FAIL: invalid state accepted\n' >&2
  exit 1
fi
if ravn_record_task_evidence opencode verify invalid 1; then
  printf 'FAIL: invalid evidence state accepted\n' >&2
  exit 1
fi

log_file="${XDG_STATE_HOME}/test.log"
printf '%s\n' 'API_KEY=super-secret' 'Authorization: Bearer token-value' >"$log_file"
ravn_redact_log "$log_file"
grep -Fq 'API_KEY=[REDACTED]' "$log_file"
grep -Fq 'Bearer [REDACTED]' "$log_file"
if grep -q 'super-secret\|token-value' "$log_file"; then
  printf 'FAIL: secret remained in log\n' >&2
  exit 1
fi

ravn_record_task_evidence opencode verify verified 0 'command succeeded'
task_dir="${XDG_STATE_HOME}/ravn/tasks/opencode"
grep -q 'status = "verified"' "${task_dir}/state.toml"
grep -q '"operation": "verify"' "${task_dir}/last-result.json"
grep -q '"exit_code": 0' "${task_dir}/last-result.json"
grep -q '"requested_version": ""' "${task_dir}/last-result.json"

printf 'PASS: task state and evidence\n'
