#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${RAVN_ADMIN_DOCKER_IMAGE:-archlinux:latest}"

if ! command -v docker > /dev/null 2>&1 || ! docker info > /dev/null 2>&1; then
  printf 'SKIP: Intel HD 530 Docker regression — Docker unavailable\n'
  exit 0
fi

docker run --rm --pull=missing \
  --network none \
  -e RAVN_TASK=/repo/tasks/90-system/04-intel-hd-530.sh \
  -v "${RAVN_DIR}/tasks/90-system/04-intel-hd-530.sh:/repo/tasks/90-system/04-intel-hd-530.sh:ro" \
  -v "${RAVN_DIR}/tests/fixtures/intel-hd-530-docker-inner.sh:/repo/tests/fixtures/intel-hd-530-docker-inner.sh:ro" \
  "$IMAGE" bash /repo/tests/fixtures/intel-hd-530-docker-inner.sh
