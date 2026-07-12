#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${RAVN_ADMIN_DOCKER_IMAGE:-archlinux:latest}"

if ! command -v docker > /dev/null 2>&1 || ! docker info > /dev/null 2>&1; then
  printf 'SKIP: SSH agent Docker regression — Docker unavailable\n'
  exit 0
fi

docker run --rm --pull=missing \
  --network none \
  -e RAVN_TASK=/repo/tasks/90-system/02-ssh-agent.sh \
  -v "${RAVN_DIR}/tasks/90-system/02-ssh-agent.sh:/repo/tasks/90-system/02-ssh-agent.sh:ro" \
  -v "${RAVN_DIR}/tests/fixtures/ssh-agent-docker-inner.sh:/repo/tests/fixtures/ssh-agent-docker-inner.sh:ro" \
  "$IMAGE" bash /repo/tests/fixtures/ssh-agent-docker-inner.sh
