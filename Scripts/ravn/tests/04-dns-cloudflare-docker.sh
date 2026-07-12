#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${RAVN_ADMIN_DOCKER_IMAGE:-archlinux:latest}"

if ! command -v docker > /dev/null 2>&1 || ! docker info > /dev/null 2>&1; then
  printf 'SKIP: dns-cloudflare Docker regression — Docker unavailable\n'
  exit 0
fi

docker run --rm --pull=missing \
  --network none \
  -v "${RAVN_DIR}/tasks/90-system/04-dns-cloudflare.sh:/repo/tasks/90-system/04-dns-cloudflare.sh:ro" \
  -v "${RAVN_DIR}/tests/04-dns-cloudflare-lifecycle.sh:/repo/tests/04-dns-cloudflare-lifecycle.sh:ro" \
  "$IMAGE" bash /repo/tests/04-dns-cloudflare-lifecycle.sh
