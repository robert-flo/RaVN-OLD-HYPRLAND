#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_FILE="${RAVN_GROK_MATRIX_REPORT:-${RAVN_DIR}/cache/logs/grok-matrix.log}"

record_result() {
  local layer="$1"
  local result="$2"

  mkdir -p "$(dirname "$REPORT_FILE")"
  printf '%s|%s\n' "$layer" "$result" >>"$REPORT_FILE"
  printf '%-12s %s\n' "$layer" "$result"
}

run_contract() {
  if bash "${RAVN_DIR}/tests/upstream.sh"; then
    record_result contract PASS
  else
    record_result contract FAIL
    return 1
  fi
}

run_integration() {
  if bash "${RAVN_DIR}/test-task.sh" grok; then
    record_result integration PASS
  else
    record_result integration FAIL
    return 1
  fi
}

run_manual() {
  if [[ ${RAVN_RUN_MANUAL:-0} != 1 ]]; then
    record_result manual NOT_RUN
    return 1
  fi
  if bash "${RAVN_DIR}/tests/14-grok-lifecycle.sh"; then
    record_result manual PASS
  else
    record_result manual FAIL
    return 1
  fi
}

main() {
  local mode="${1:-contract}"
  local status=0

  mkdir -p "$(dirname "$REPORT_FILE")"
  : >"$REPORT_FILE"
  case "$mode" in
  contract) run_contract || status=1 ;;
  integration) run_integration || status=1 ;;
  manual) run_manual || status=1 ;;
  all)
    run_contract || status=1
    run_integration || status=1
    run_manual || status=1
    ;;
  *)
    printf 'Usage: %s contract|integration|manual|all\n' "$(basename "$0")" >&2
    return 2
    ;;
  esac
  printf 'Report: %s\n' "$REPORT_FILE"
  return "$status"
}

main "$@"
