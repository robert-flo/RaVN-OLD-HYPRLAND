#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_FILE="${RAVN_MATRIX_REPORT:-${RAVN_DIR}/cache/logs/opencode-matrix.log}"
TASKS_DIR="${RAVN_DIR}/tasks"
LEGACY_DIR="${RAVN_DIR}/tasks_legacy"

usage() {
  printf '%s\n' \
    "Uso: $(basename "$0") contract|integration|manual|all" \
    "  coverage    Reporta cobertura activa y legacy por categoría." \
    "  contract    Ejecuta pruebas contractuales con dobles controlados." \
    "  integration Ejecuta los pilotos reales en Docker." \
    "  manual      Ejecuta la validación explícita del host Arch." \
    "  all         Ejecuta las tres capas; manual requiere RAVN_RUN_MANUAL=1."
}

run_coverage() {
  local core_count=0
  local system_count=0
  local active_npm_count=0
  local reference_npm_count=0
  local legacy_npm_count=0
  local task_file=""

  core_count=$(find "${LEGACY_DIR}/00-core" -type f -name '*.sh' 2>/dev/null | wc -l)
  system_count=$(find "${LEGACY_DIR}/30-system" -type f -name '*.sh' 2>/dev/null | wc -l)
  while IFS= read -r task_file; do
    if (
      # shellcheck disable=SC1091
      source "${RAVN_DIR}/framework/package.sh"
      # shellcheck disable=SC1090
      source "$task_file"
      [[ ${REFERENCE_ONLY:-false} == true ]]
    ); then
      reference_npm_count=$((reference_npm_count + 1))
    else
      active_npm_count=$((active_npm_count + 1))
    fi
  done < <(find "${TASKS_DIR}/10-npm-apps" -type f -name '*.sh' 2>/dev/null | sort)
  legacy_npm_count=$(find "${LEGACY_DIR}/10-npm-apps" -type f -name '*.sh' 2>/dev/null | wc -l)

  record_result "coverage-core" "LEGACY:${core_count}"
  record_result "coverage-system" "LEGACY:${system_count}"
  record_result "coverage-active-npm" "ACTIVE:${active_npm_count}"
  record_result "coverage-reference-npm" "REFERENCE:${reference_npm_count}"
  record_result "coverage-legacy-npm" "LEGACY:${legacy_npm_count}"
}

record_result() {
  local layer="$1"
  local result="$2"

  mkdir -p "$(dirname "$REPORT_FILE")"
  printf '%s|%s\n' "$layer" "$result" >>"$REPORT_FILE"
  printf '%-12s %s\n' "$layer" "$result"
}

run_contract() {
  if bash "${RAVN_DIR}/tests/opencode-contract.sh"; then
    record_result contract PASS
  else
    record_result contract FAIL
    return 1
  fi
}

run_integration() {
  if bash "${RAVN_DIR}/test-task.sh" opencode; then
    record_result integration PASS
  else
    record_result integration FAIL
    return 1
  fi
}

run_manual() {
  if [[ ${RAVN_RUN_MANUAL:-0} != "1" ]]; then
    record_result manual NOT_RUN
    return 1
  fi

  if bash "${RAVN_DIR}/setup.sh" verify opencode; then
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
  coverage) run_coverage ;;
  contract) run_contract || status=1 ;;
  integration) run_integration || status=1 ;;
  manual) run_manual || status=1 ;;
  all)
    run_coverage
    run_contract || status=1
    run_integration || status=1
    run_manual || status=1
    ;;
  *)
    usage >&2
    return 2
    ;;
  esac

  printf 'Reporte: %s\n' "$REPORT_FILE"
  return "$status"
}

main "$@"
