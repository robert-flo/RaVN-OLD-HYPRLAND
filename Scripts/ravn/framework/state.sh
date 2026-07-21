#!/usr/bin/env bash
# ─── RaVN Framework v1 — Task State and Evidence ────────────────────────────

readonly RAVN_TASK_STATES=(
  absent partial installed verified stale broken dependency-missing
  update-failed rollback-failed unsupported
)
readonly RAVN_EVIDENCE_MAX_RUNS=30
readonly RAVN_EVIDENCE_MAX_BYTES=$((50 * 1024 * 1024))
readonly RAVN_EVIDENCE_MAX_AGE_DAYS=90

ravn_task_state_root() {
  printf '%s/ravn/tasks' "${XDG_STATE_HOME:-${HOME}/.local/state}"
}

ravn_task_state_dir() {
  printf '%s/%s' "$(ravn_task_state_root)" "$1"
}

_ravn_json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

_ravn_evidence_timestamp() {
  date -u '+%Y-%m-%dT%H-%M-%S-%NZ'
}

ravn_state_is_valid() {
  local state="$1"
  local allowed

  for allowed in "${RAVN_TASK_STATES[@]}"; do
    [[ $state == "$allowed" ]] && return 0
  done
  return 1
}

ravn_redact_log() {
  local log_file="$1"

  [[ -f $log_file ]] || return 0
  sed -E -i \
    -e 's/(Authorization:[[:space:]]*Bearer[[:space:]]+)[^[:space:]]+/\1[REDACTED]/Ig' \
    -e 's/(Bearer[[:space:]]+)[^[:space:]]+/\1[REDACTED]/Ig' \
    -e 's/((TOKEN|SECRET|PASSWORD|API_KEY|COOKIE|PRIVATE_KEY)[[:space:]]*[=:][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig' \
    "$log_file"
}

ravn_record_task_evidence() {
  local task_id="$1"
  local operation="$2"
  local status="$3"
  local exit_code="$4"
  local detail="${5:-}"
  local log_path="${6:-}"
  local task_dir=""
  local runs_dir=""
  local timestamp=""
  local run_file=""
  local escaped_detail=""

  if ! ravn_state_is_valid "$status"; then
    return 1
  fi

  task_dir=$(ravn_task_state_dir "$task_id")
  runs_dir="${task_dir}/runs"
  mkdir -p "$runs_dir" || return 1

  timestamp=$(_ravn_evidence_timestamp)
  run_file="${runs_dir}/${timestamp}.json"
  escaped_detail=$(_ravn_json_escape "$detail")

  cat >"$run_file" <<EOF
{
  "task": "$(_ravn_json_escape "$task_id")",
  "operation": "$(_ravn_json_escape "$operation")",
  "status": "$(_ravn_json_escape "$status")",
  "exit_code": ${exit_code},
  "detail": "${escaped_detail}",
  "requested_version": "$(_ravn_json_escape "${RAVN_EVIDENCE_REQUESTED_VERSION:-}")",
  "resolved_version": "$(_ravn_json_escape "${RAVN_EVIDENCE_RESOLVED_VERSION:-}")",
  "runtime_version": "$(_ravn_json_escape "${RAVN_EVIDENCE_RUNTIME_VERSION:-}")",
  "mise_version": "$(_ravn_json_escape "${RAVN_EVIDENCE_MISE_VERSION:-}")",
  "upstream_sha256": "$(_ravn_json_escape "${RAVN_EVIDENCE_UPSTREAM_SHA256:-}")",
  "log_path": "$(_ravn_json_escape "$log_path")",
  "timestamp": "${timestamp}"
}
EOF
  cp "$run_file" "${task_dir}/last-result.json"
  cat >"${task_dir}/state.toml" <<EOF
task = "$(_ravn_json_escape "$task_id")"
status = "$(_ravn_json_escape "$status")"
operation = "$(_ravn_json_escape "$operation")"
last_exit_code = ${exit_code}
requested_version = "$(_ravn_json_escape "${RAVN_EVIDENCE_REQUESTED_VERSION:-}")"
resolved_version = "$(_ravn_json_escape "${RAVN_EVIDENCE_RESOLVED_VERSION:-}")"
runtime_version = "$(_ravn_json_escape "${RAVN_EVIDENCE_RUNTIME_VERSION:-}")"
mise_version = "$(_ravn_json_escape "${RAVN_EVIDENCE_MISE_VERSION:-}")"
upstream_sha256 = "$(_ravn_json_escape "${RAVN_EVIDENCE_UPSTREAM_SHA256:-}")"
log_path = "$(_ravn_json_escape "$log_path")"
last_recorded_at = "${timestamp}"
EOF

  ravn_prune_task_evidence "$task_id"
}

ravn_prune_task_evidence() {
  local task_id="$1"
  local runs_dir=""
  local file=""
  local total_bytes=0
  local -a run_files=()

  runs_dir="$(ravn_task_state_dir "$task_id")/runs"
  [[ -d $runs_dir ]] || return 0
  find "$runs_dir" -type f -name '*.json' -mtime "+${RAVN_EVIDENCE_MAX_AGE_DAYS}" -delete
  mapfile -t run_files < <(find "$runs_dir" -type f -name '*.json' -printf '%T@ %p\n' | sort -nr | cut -d' ' -f2-)

  for file in "${run_files[@]:RAVN_EVIDENCE_MAX_RUNS}"; do
    rm -f "$file"
  done

  mapfile -t run_files < <(find "$runs_dir" -type f -name '*.json' -printf '%T@ %p\n' | sort -nr | cut -d' ' -f2-)
  for file in "${run_files[@]}"; do
    total_bytes=$((total_bytes + $(stat -c '%s' "$file")))
    if ((total_bytes > RAVN_EVIDENCE_MAX_BYTES)); then
      rm -f "$file"
    fi
  done
}

# Compatibility helpers for existing callers of the original state skeleton.
state_set() {
  local key="$1"
  local value="$2"
  local state_dir="${RAVN_DIR}/cache/state"

  mkdir -p "$state_dir"
  printf '%s' "$value" >"${state_dir}/${key}"
}

state_get() {
  local key="$1"
  local file="${RAVN_DIR}/cache/state/${key}"

  [[ -f $file ]] && cat "$file"
}

state_has() {
  [[ -f "${RAVN_DIR}/cache/state/${1}" ]]
}
