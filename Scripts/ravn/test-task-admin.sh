#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="${RAVN_DIR}/tests/fixtures"
REPORT_DIR="${RAVN_ADMIN_REPORT_DIR:-${RAVN_DIR}/cache/admin-reports}"

usage() {
  cat << 'EOF'
test-task-admin.sh — isolated administrative task harness
Usage: test-task-admin.sh <fixture> --approve [--scenario <name>]
Scenarios: success, apply-failure, verify-failure, pending, partial, unsupported
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 2
}

fixture=""
isolated=true
approved=false
scenario="success"
while (($# > 0)); do
  case $1 in
    --isolated)
      isolated=true
      shift
      ;;
    --approve | --yes)
      approved=true
      shift
      ;;
    --scenario)
      (($# >= 2)) || die "--scenario requires a value"
      scenario=$2
      shift 2
      ;;
    --report-dir)
      (($# >= 2)) || die "--report-dir requires a path"
      REPORT_DIR=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --*) die "unknown option: $1" ;;
    *)
      [[ -z $fixture ]] || die "only one fixture can be selected"
      fixture=$1
      shift
      ;;
  esac
done

[[ -n $fixture ]] || die "fixture is required"
[[ $isolated == true ]] || die "only --isolated mode is available in this increment"
[[ $approved == true ]] || {
  printf 'NOT_RUN: approval required before Apply\n'
  exit 3
}
[[ $scenario =~ ^(success|apply-failure|verify-failure|pending|partial|unsupported)$ ]] || die "unsupported scenario: $scenario"
fixture_file="${FIXTURE_DIR}/${fixture}.sh"
[[ -f $fixture_file ]] || die "fixture not found: $fixture"

temp_root=$(mktemp -d "${TMPDIR:-/tmp}/ravn-admin.XXXXXX")
trap 'rm -rf "$temp_root"' EXIT
export HOME="${temp_root}/home" RAVN_ADMIN_SCENARIO="$scenario"
mkdir -p "$HOME" "$REPORT_DIR"
# shellcheck disable=SC1090
source "$fixture_file"

snapshot() { find "$HOME" -mindepth 1 -printf '%P\n' | sort | sha256sum; }

plan_before=$(snapshot)
admin_fixture_plan
plan_after=$(snapshot)
[[ $plan_before == "$plan_after" ]] || die "plan mutated isolated resources"

apply_status="applied"
if ! admin_fixture_apply; then
  apply_status="failed"
  verify_status="failed"
elif admin_fixture_verify; then
  verify_status="verified"
else
  case $? in
    2) verify_status="applied-pending-activation" ;;
    3) verify_status="unsupported" ;;
    4) verify_status="partially-verified" ;;
    *) verify_status="failed" ;;
  esac
fi

detail=""
case $verify_status in
  applied-pending-activation) detail=${ADMIN_VERIFY_PENDING:-activation pending} ;;
  partially-verified) detail=${ADMIN_VERIFY_PARTIAL:-partial verification} ;;
  unsupported) detail=${ADMIN_VERIFY_UNSUPPORTED:-verification unsupported} ;;
  failed) detail="apply or verification failed" ;;
esac

report_file="${REPORT_DIR}/${ADMIN_TASK_ID}-${scenario}.json"
cat > "$report_file" << EOF
{
  "task": "${ADMIN_TASK_ID}",
  "family": "${ADMIN_TASK_FAMILY}",
  "profile": "${ADMIN_EXECUTION_PROFILE}",
  "mode": "${RAVN_ADMIN_EXECUTION_MODE:-isolated}",
  "approved": true,
  "scenario": "${scenario}",
  "apply": "${apply_status}",
  "result": "${verify_status}",
  "reversibility": "${ADMIN_REVERSIBILITY}",
  "activation_boundary": "${ADMIN_ACTIVATION_BOUNDARY}",
  "owned_resources": ["${ADMIN_OWNED_RESOURCES[0]}"],
  "detail": "${detail}",
  "report": "${report_file}"
}
EOF

printf 'Task: %s\nMode: isolated\nPlan: read-only\nApply: %s\nVerify: %s\n' \
  "$ADMIN_TASK_ID" "$apply_status" "$verify_status"
[[ -n $detail ]] && printf 'Pending/action: %s\n' "$detail"
printf 'Report: %s\n' "$report_file"

if [[ $verify_status == verified ]]; then
  admin_fixture_reset
  [[ ! -e ${ADMIN_OWNED_RESOURCES[0]} ]] || die "reset did not remove owned resource"
  printf 'Reset: verified\n'
  admin_fixture_apply
  admin_fixture_verify || die 'reinstall verification failed'
  printf 'Reinstall: verified\n'
  exit 0
fi
exit 1
