#!/usr/bin/env bash

set -Eeuo pipefail

scrDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${scrDir}/global_fn.sh"

CACHE_DIR="${HOME}/.cache/bootstrap"
LOG_DIR="${CACHE_DIR}/logs"

mkdir -p "$LOG_DIR"

TASKS=()

discover_tasks() {
  mapfile -t TASKS < <(
    find "${scrDir}/installers" \
      -type f \
      -name "*.sh" |
      sort
  )
}

run_task() {
  local file="$1"

  unset PACKAGE
  unset CHECK

  source "$file"

  local name="$PACKAGE"

  if command -v "$CHECK" &>/dev/null; then
    success "$name: skipped"
    count_skip
    return
  fi

  local log="${LOG_DIR}/${name}.log"

  local start
  start=$(date +%s)

  (
    install
  ) >"$log" 2>&1 &

  local pid=$!

  local status=0
  spin "$pid" "Installing $name" || status=$?

  local end
  end=$(date +%s)
  local elapsed=$((end-start))

  if ((status == 0)); then
    info "Installed $name in ${elapsed}s"
    count_ok
  else
    info "Log: ${log}"
    count_fail
  fi
}

run_pipeline() {
  local start
  start=$(date +%s)

  echo
  info "Bootstrap started"
  echo

  for file in "${TASKS[@]}"; do
    run_task "$file"
  done

  local end
  end=$(date +%s)

  print_summary "Bootstrap"

  info "Completed in $((end-start))s"
}

main() {
    discover_tasks
    run_pipeline
}

main "$@"
