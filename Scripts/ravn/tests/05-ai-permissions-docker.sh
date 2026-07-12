#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${RAVN_ADMIN_DOCKER_IMAGE:-archlinux:latest}"

if ! command -v docker > /dev/null 2>&1 || ! docker info > /dev/null 2>&1; then
  printf 'SKIP: ai-permissions Docker regression — Docker unavailable\n'
  exit 0
fi

docker run --rm --pull=missing \
  --network none \
  -e RAVN_TASK=/repo/tasks/90-system/05-ai-permissions.sh \
  -v "${RAVN_DIR}/tasks/90-system/05-ai-permissions.sh:/repo/tasks/90-system/05-ai-permissions.sh:ro" \
  -v "${RAVN_DIR}/tests/fixtures/ai-permissions-docker-inner.sh:/repo/tests/fixtures/ai-permissions-docker-inner.sh:ro" \
  "$IMAGE" bash /repo/tests/fixtures/ai-permissions-docker-inner.sh
