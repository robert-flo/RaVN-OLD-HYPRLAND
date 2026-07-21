#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ravn-admin-reports.XXXXXX")
trap 'rm -rf "$REPORT_DIR"' EXIT

run_success() {
  bash "${RAVN_DIR}/test-task-admin.sh" admin-lifecycle --approve \
    --report-dir "$REPORT_DIR"
}

assert_result() {
  local scenario="$1"
  local expected="$2"
  local report="${REPORT_DIR}/admin-fixture-${scenario}.json"

  grep -q '"result": "'"$expected"'"' "$report"
}

run_success
assert_result success verified
run_success
assert_result success verified

if bash "${RAVN_DIR}/test-task-admin.sh" admin-lifecycle --isolated \
  --report-dir "$REPORT_DIR"; then
  printf 'FAIL: approval was not required\n' >&2
  exit 1
fi

for scenario in apply-failure verify-failure pending partial unsupported; do
  if bash "${RAVN_DIR}/test-task-admin.sh" admin-lifecycle --isolated --approve \
    --scenario "$scenario" --report-dir "$REPORT_DIR"; then
    printf 'FAIL: %s scenario unexpectedly passed\n' "$scenario" >&2
    exit 1
  fi
done

assert_result apply-failure failed
assert_result verify-failure failed
assert_result pending applied-pending-activation
assert_result partial partially-verified
assert_result unsupported unsupported

printf 'PASS: administrative harness contract\n'
