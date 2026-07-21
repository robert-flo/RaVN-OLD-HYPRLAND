#!/usr/bin/env bash
# ─── RaVN Framework v1 — Task Discovery ─────────────────────────────────────
# Recursively discovers all .sh modules under tasks/ sorted by path.
# Convention-over-configuration: drop a file, it runs.

# Populated by discover_tasks(); consumed by run_pipeline().
TASKS=()

task_is_reference_only() (
  local file="$1"

  # shellcheck disable=SC1091
  source "${RAVN_DIR}/framework/package.sh"
  # shellcheck disable=SC1090
  source "$file"
  [[ ${REFERENCE_ONLY:-false} != true ]]
)

# discover_tasks [dir]
#   Scans the given directory (default: tasks/) for .sh files, sorted.
#   Populates the global TASKS array.
discover_tasks() {
  local search_dir="${1:-${RAVN_DIR}/tasks}"

  if [[ ! -d $search_dir ]]; then
    error_msg "Task directory not found: ${search_dir}"
    return 1
  fi

  local -a discovered_tasks=()
  mapfile -t discovered_tasks < <(
    find "$search_dir" \
      -type f \
      -name "*.sh" |
      sort
  )

  TASKS=()
  for file in "${discovered_tasks[@]}"; do
    task_is_reference_only "$file" && TASKS+=("$file")
  done

  if ((${#TASKS[@]} == 0)); then
    warn_msg "No task modules found in ${search_dir}"
    return 0
  fi

  info "Discovered ${#TASKS[@]} task modules"
}
