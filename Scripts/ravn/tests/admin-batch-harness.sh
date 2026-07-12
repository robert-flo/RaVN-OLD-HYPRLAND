#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ravn-admin-batch-tests.XXXXXX")
trap 'rm -rf "$REPORT_DIR"' EXIT

run_case() {
  local scenario=$1 expected=$2 extra=${3:-}
  local -a extra_args=()
  [[ -z $extra ]] || extra_args=("$extra")
  if bash "$RAVN_DIR/test-task-admin-batch.sh" admin-batch --approve --scenario "$scenario" --report-dir "$REPORT_DIR" "${extra_args[@]}"; then
    [[ $expected == verified ]] || {
      printf 'FAIL: %s unexpectedly passed\n' "$scenario"
      exit 1
    }
  else
    [[ $expected != verified ]] || {
      printf 'FAIL: %s unexpectedly failed\n' "$scenario"
      exit 1
    }
  fi
  grep -q '"result": "'"$expected"'"' "$REPORT_DIR/admin-batch-fixture-${scenario}.json" 2> /dev/null || grep -q '"result": "failed"' "$REPORT_DIR/admin-batch-fixture-${scenario}.json"
}

if bash "$RAVN_DIR/test-task-admin-batch.sh" admin-batch --approve --scenario conflict --report-dir "$REPORT_DIR"; then
  printf 'FAIL: conflict was not rejected during Plan\n'
  exit 1
fi

run_case success verified
run_case reversible-failure failed
run_case rollback-failure failed
run_case reversible-failure failed --continue-independent
grep -q '"applied": \["independent"\]' "$REPORT_DIR/admin-batch-fixture-reversible-failure.json"
grep -q '"skipped": \["dependent"\]' "$REPORT_DIR/admin-batch-fixture-reversible-failure.json"

if bash "$RAVN_DIR/test-task-admin-batch.sh" admin-batch --approve --scenario success --report-dir "$REPORT_DIR" > /dev/null; then
  grep -q '"applied": \["prepare","dependent","independent"' "$REPORT_DIR/admin-batch-fixture-success.json"
else
  exit 1
fi
printf 'PASS: administrative batch contract\n'
