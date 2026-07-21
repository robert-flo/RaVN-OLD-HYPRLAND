#!/usr/bin/env bash
# ─── RaVN Framework v1 — Pipeline ───────────────────────────────────────────
# Orchestrates task execution with lifecycle management, logging, counters,
# spinners, and interactive prompts. Contains no installer logic.

flg_DryRun=${flg_DryRun:-0}

# run_task <file>
#   Sources a task module and runs its full lifecycle:
#   package.sh defaults → source task → check → before → install → after → cleanup
run_task() {
  local file="$1"
  local log_dir="${RAVN_DIR}/cache/logs"
  mkdir -p "$log_dir"

  # ── Reset defaults by re-sourcing the package contract ──
  # shellcheck disable=SC1091
  source "${RAVN_DIR}/framework/package.sh"

  # ── Source the task module (overrides defaults) ──
  # shellcheck disable=SC1090
  source "$file"

  local name="${PACKAGE:-$(basename "$file" .sh)}"
  local log="${log_dir}/${name}.log"

  if ((flg_DryRun == 1)); then
    info "${name}: Dry-run — omitiendo."
    count_skip "$name"
    return 0
  fi

  # ── Configuration registry gate: skip if disabled in packages.conf ──
  if [[ -f "${RAVN_DIR}/config/packages.conf" ]]; then
    if grep -q "^${name}=false" "${RAVN_DIR}/config/packages.conf"; then
      info "${name}: Deshabilitado en la configuración. Omitiendo."
      count_skip "$name"
      return 0
    fi
  fi

  # ── Interactive gate ──
  if [[ $INTERACTIVE == true ]]; then
    prompt_timer 10 "¿Instalar ${name}? (${DESCRIPTION:-sin descripción}) [y/N]"
    if [[ "${PROMPT_INPUT,,}" != "y" ]]; then
      info "${name}: Omitido por el usuario."
      count_skip "$name"
      return 0
    fi
  fi

  # ── Check: skip if already installed ──
  if check; then
    info "${name}: Ya instalado. Omitiendo."
    count_skip "$name"
    return 0
  fi

  # ── Execute lifecycle with logging ──
  local start
  start=$(date +%s)

  (
    # Run in subshell to isolate failures
    run_hook before "before"
    install
    run_hook after "after"
  ) >"$log" 2>&1 &

  local pid=$!
  local status=0
  spin "$pid" "Instalando ${name}..." || status=$?

  # ── Always run cleanup ──
  if hook_defined cleanup; then
    cleanup >>"$log" 2>&1 || true
  fi

  local end
  end=$(date +%s)
  local elapsed=$((end - start))

  # ── Report result ──
  if ((status == 0)); then
    success "${name} instalado en ${elapsed}s"
    count_ok "$name"
  else
    error_msg "${name} falló (${elapsed}s). Log: ${log}"
    count_fail "$name"
  fi

  return $status
}

# run_pipeline
#   Iterates over all discovered TASKS and runs each through the lifecycle.
run_pipeline() {
  local pipeline_start
  pipeline_start=$(date +%s)

  echo ""
  step "RaVN Framework v1 — Bootstrap"
  info "Ejecutando ${#TASKS[@]} módulos..."
  echo ""

  for file in "${TASKS[@]}"; do
    run_task "$file" || true # Don't abort pipeline on individual failures
  done

  local pipeline_end
  pipeline_end=$(date +%s)

  print_summary "Bootstrap"
  info "Completado en $((pipeline_end - pipeline_start))s"
}
