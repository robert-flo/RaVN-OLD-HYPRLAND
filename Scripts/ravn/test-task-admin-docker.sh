#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="${RAVN_DIR}/tests/fixtures"
REPORT_DIR="${RAVN_ADMIN_DOCKER_REPORT_DIR:-${RAVN_DIR}/cache/admin-docker-reports}"
IMAGE="${RAVN_ADMIN_DOCKER_IMAGE:-archlinux:latest}"

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 2
}

fixture=""
approved=false
scenario=success
while (($# > 0)); do
  case $1 in
    --approve | --yes)
      approved=true
      shift
      ;;
    --scenario)
      (($# >= 2)) || die '--scenario requires a value'
      scenario=$2
      shift 2
      ;;
    --report-dir)
      (($# >= 2)) || die '--report-dir requires a path'
      REPORT_DIR=$2
      shift 2
      ;;
    --image)
      (($# >= 2)) || die '--image requires a value'
      IMAGE=$2
      shift 2
      ;;
    -h | --help)
      printf '%s\n' 'Usage: test-task-admin-docker.sh <fixture> --approve [--scenario <name>] [--image <image>]'
      exit 0
      ;;
    --*) die "unknown option: $1" ;;
    *)
      [[ -z $fixture ]] || die 'only one fixture can be selected'
      fixture=$1
      shift
      ;;
  esac
done

[[ -n $fixture ]] || die 'fixture is required'
[[ $approved == true ]] || {
  printf 'NOT_RUN: Docker Apply requires --approve\n'
  exit 3
}
[[ $scenario =~ ^(success|apply-failure|verify-failure|pending|partial|unsupported)$ ]] ||
  die "unsupported scenario: $scenario"
[[ -f "${FIXTURE_DIR}/${fixture}.sh" ]] || die "fixture not found: $fixture"

if ! command -v docker > /dev/null 2>&1 || ! docker info > /dev/null 2>&1; then
  printf 'SKIP: administrative Docker harness — Docker unavailable\n'
  exit 0
fi

mkdir -p "$REPORT_DIR"
docker run --rm --pull=missing \
  --network none \
  --read-only \
  --tmpfs /tmp \
  --tmpfs /run \
  --tmpfs /home/admin \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --user "$(id -u):$(id -g)" \
  -e RAVN_ADMIN_EXECUTION_MODE=docker \
  -e "RAVN_ADMIN_SCENARIO=${scenario}" \
  -v "${RAVN_DIR}/test-task-admin.sh:/opt/ravn/test-task-admin.sh:ro" \
  -v "${FIXTURE_DIR}/${fixture}.sh:/opt/ravn/tests/fixtures/${fixture}.sh:ro" \
  -v "${REPORT_DIR}:/reports" \
  "$IMAGE" \
  bash /opt/ravn/test-task-admin.sh "$fixture" --approve \
    --scenario "$scenario" --report-dir /reports

printf 'Docker mode: completed fixture execution\nReport directory: %s\n' "$REPORT_DIR"
