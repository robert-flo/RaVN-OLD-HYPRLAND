#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${RAVN_ADMIN_DOCKER_IMAGE:-archlinux:latest}"

if ! command -v docker > /dev/null 2>&1 || ! docker info > /dev/null 2>&1; then
  printf 'SKIP: docker Docker regression — Docker unavailable\n'
  exit 0
fi

docker run --rm --pull=missing \
  --network none \
  -e RAVN_TASK=/repo/tasks/90-system/06-docker.sh \
  -v "${RAVN_DIR}/tasks/90-system/06-docker.sh:/repo/tasks/90-system/06-docker.sh:ro" \
  -v "${RAVN_DIR}/tests/fixtures/docker-docker-inner.sh:/repo/tests/fixtures/docker-docker-inner.sh:ro" \
  "$IMAGE" bash /repo/tests/fixtures/docker-docker-inner.sh
