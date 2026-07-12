#!/usr/bin/env bash
# ─── RaVN Framework v1 — Direct Task Runner ─────────────────────────────────
# Resolves and executes explicitly selected tasks without changing the menu or
# the installer pipeline.

TASK_RESULTS=()
TASK_FAILURES=()
RAVN_CURRENT_OPERATION=""
RAVN_CURRENT_TASK_ID=""
RAVN_EVIDENCE_LOG_PATH=""

_runner_reset_task_contract() {
  # shellcheck disable=SC1091
  source "${RAVN_DIR}/framework/package.sh"
}

load_task() {
  local file="$1"

  _runner_reset_task_contract
  # shellcheck disable=SC1090
  source "$file"
}

task_name() {
  local file="$1"
  load_task "$file"
  printf '%s' "${PACKAGE:-$(basename "$file" .sh)}"
}

task_family() {
  local file="$1"
  load_task "$file"
  printf '%s' "${TASK_FAMILY:-}"
}

task_is_disabled() {
  local name="$1"

  [[ -f ${RAVN_DIR}/config/packages.conf ]] &&
    grep -Fxq "${name}=false" "${RAVN_DIR}/config/packages.conf"
}

_runner_match_task() {
  local file="$1"
  local selector="$2"
  local name=""
  name=$(task_name "$file")

  if [[ $selector == "BASELINE" ]]; then
    [[ $(task_family "$file") == "baseline" ]]
    return
  fi

  [[ $selector == "ALL" || $selector == "$name" || $selector == "$(basename "$file" .sh)" || $selector == "$file" ]]
}

resolve_task_files() {
  local selector file
  local -a selected=()

  if (($# == 0)); then
    error_msg "Debe especificar una tarea o ALL."
    return 1
  fi

  for selector in "$@"; do
    local found=0

    for file in "${TASKS[@]}"; do
      if _runner_match_task "$file" "$selector"; then
        selected+=("$file")
        found=1
      fi
    done

    if ((found == 0)) && [[ $selector != "BASELINE" ]]; then
      error_msg "Tarea no encontrada: ${selector}"
      return 1
    fi
  done

  RESOLVED_TASKS=()
  if ((${#selected[@]} > 0)); then
    mapfile -t RESOLVED_TASKS < <(printf '%s\n' "${selected[@]}" | sort -u)
  fi
}

_runner_log_dir() {
  mkdir -p "${RAVN_DIR}/cache/logs"
}

_runner_redact_log() {
  local log="$1"

  if declare -f ravn_redact_log >/dev/null; then
    ravn_redact_log "$log"
  fi
}

_runner_record() {
  local name="$1"
  local result="$2"
  local exit_code="${3:-0}"
  local state=""

  TASK_RESULTS+=("${name}:${result}")
  if [[ $result == "failed" || $result == "unverified" || $result == "dependency-missing" || $result == "unsupported" ]]; then
    TASK_FAILURES+=("$name")
  fi

  case "$result" in
  verified | up-to-date) state="verified" ;;
  update-available) state="stale" ;;
  skipped) state="installed" ;;
  disabled | reset) state="absent" ;;
  unverified | reset-unsupported) state="partial" ;;
  failed | reset-failed) state="broken" ;;
  dependency-missing) state="dependency-missing" ;;
  update-failed) state="update-failed" ;;
  rollback-failed) state="rollback-failed" ;;
  unsupported) state="unsupported" ;;
  *) return 0 ;;
  esac

  if declare -f ravn_record_task_evidence >/dev/null; then
    ravn_record_task_evidence "${RAVN_CURRENT_TASK_ID:-$name}" \
      "${RAVN_CURRENT_OPERATION:-unknown}" "$state" "$exit_code" "$result" \
      "$RAVN_EVIDENCE_LOG_PATH"
  fi
}

verify_selected_task() {
  local file="$1"
  local name=""
  local log=""

  load_task "$file"
  name="${PACKAGE:-$(basename "$file" .sh)}"
  RAVN_CURRENT_TASK_ID="${TASK_ID:-$name}"
  RAVN_CURRENT_OPERATION="verify"
  log="${RAVN_DIR}/cache/logs/${name}.log"
  RAVN_EVIDENCE_LOG_PATH="$log"
  _runner_log_dir

  if task_is_disabled "$name"; then
    info "${name}: Deshabilitado."
    _runner_record "$name" "disabled"
    return 0
  fi

  if ! task_capability verify; then
    warn_msg "${name}: Sin verify(); no se puede confirmar el postestado."
    _runner_record "$name" "unverified"
    return 1
  fi

  if verify >>"$log" 2>&1; then
    _runner_redact_log "$log"
    if ! _runner_record "$name" "verified"; then
      error_msg "${name}: Verificado, pero no se pudo registrar la evidencia."
      return 1
    fi
    success "${name}: Verificado."
    return 0
  fi

  _runner_redact_log "$log"
  error_msg "${name}: Verificación falló. Log: ${log}"
  if [[ ${RAVN_DEPENDENCY_MISSING:-false} == true ]]; then
    _runner_record "$name" "dependency-missing" 1
  else
    _runner_record "$name" "failed" 1
  fi
  return 1
}

run_selected_task() {
  local file="$1"
  local name=""
  local log=""

  load_task "$file"
  name="${PACKAGE:-$(basename "$file" .sh)}"
  RAVN_CURRENT_TASK_ID="${TASK_ID:-$name}"
  RAVN_CURRENT_OPERATION="run"
  log="${RAVN_DIR}/cache/logs/${name}.log"
  RAVN_EVIDENCE_LOG_PATH="$log"
  _runner_log_dir

  if task_is_disabled "$name"; then
    info "${name}: Deshabilitado."
    _runner_record "$name" "disabled"
    return 0
  fi

  if check; then
    info "${name}: Ya satisfecho; omitido."
    _runner_record "$name" "skipped"
    return 0
  fi

  if ! install >>"$log" 2>&1; then
    _runner_redact_log "$log"
    error_msg "${name}: Instalación falló. Log: ${log}"
    if [[ ${RAVN_DEPENDENCY_MISSING:-false} == true ]]; then
      _runner_record "$name" "dependency-missing" 1
    else
      _runner_record "$name" "failed" 1
    fi
    return 1
  fi

  if ! task_capability verify; then
    warn_msg "${name}: Instalado, pero sin verify(); resultado no confirmado."
    _runner_record "$name" "unverified"
    return 1
  fi

  if verify >>"$log" 2>&1; then
    _runner_redact_log "$log"
    if ! _runner_record "$name" "verified"; then
      error_msg "${name}: Instalado, pero no se pudo registrar la evidencia."
      return 1
    fi
    success "${name}: Instalado y verificado."
    return 0
  fi

  _runner_redact_log "$log"
  error_msg "${name}: Instalado, pero la verificación falló. Log: ${log}"
  _runner_record "$name" "failed" 1
  return 1
}

check_updates_selected_task() {
  local file="$1"
  local name=""
  local log=""

  load_task "$file"
  name="${PACKAGE:-$(basename "$file" .sh)}"
  RAVN_CURRENT_TASK_ID="${TASK_ID:-$name}"
  RAVN_CURRENT_OPERATION="check-updates"
  log="${RAVN_DIR}/cache/logs/${name}.log"
  RAVN_EVIDENCE_LOG_PATH="$log"
  _runner_log_dir

  if ! task_capability check_updates; then
    warn_msg "${name}: No soporta check-updates()."
    _runner_record "$name" "unverified" 1
    return 1
  fi

  if ! check_updates >>"$log" 2>&1; then
    _runner_redact_log "$log"
    error_msg "${name}: No se pudo consultar actualizaciones. Log: ${log}"
    if [[ ${RAVN_UPDATE_RESULT:-} == "unsupported" ]]; then
      _runner_record "$name" "unsupported" 1
    else
      _runner_record "$name" "failed" 1
    fi
    return 1
  fi

  _runner_redact_log "$log"
  if [[ ${RAVN_UPDATE_AVAILABLE:-false} == true ]]; then
    info "${name}: Actualización disponible."
    _runner_record "$name" "update-available"
  else
    success "${name}: Ya está actualizado."
    _runner_record "$name" "up-to-date"
  fi
}

update_selected_task() {
  local file="$1"
  local name=""
  local log=""
  local result="update-failed"

  load_task "$file"
  name="${PACKAGE:-$(basename "$file" .sh)}"
  RAVN_CURRENT_TASK_ID="${TASK_ID:-$name}"
  RAVN_CURRENT_OPERATION="update"
  log="${RAVN_DIR}/cache/logs/${name}.log"
  RAVN_EVIDENCE_LOG_PATH="$log"
  _runner_log_dir

  if ! task_capability update; then
    warn_msg "${name}: No soporta update()."
    _runner_record "$name" "unverified" 1
    return 1
  fi

  if update >>"$log" 2>&1; then
    _runner_redact_log "$log"
    if ! task_capability verify || ! verify >>"$log" 2>&1; then
      _runner_redact_log "$log"
      error_msg "${name}: update() terminó, pero verify() falló. Log: ${log}"
      _runner_record "$name" "update-failed" 1
      return 1
    fi
    if ! _runner_record "$name" "verified"; then
      error_msg "${name}: Actualizado, pero no se pudo registrar la evidencia."
      return 1
    fi
    success "${name}: Actualizado y verificado."
    return 0
  fi

  _runner_redact_log "$log"
  if [[ ${RAVN_UPDATE_RESULT:-} == "rollback-failed" ]]; then
    result="rollback-failed"
  elif [[ ${RAVN_UPDATE_RESULT:-} == "unsupported" ]]; then
    result="unsupported"
  fi
  error_msg "${name}: Actualización falló (${result}). Log: ${log}"
  _runner_record "$name" "$result" 1
  return 1
}

run_selected_tasks() {
  local action="$1"
  shift
  local file
  local status=0

  TASK_RESULTS=()
  TASK_FAILURES=()
  resolve_task_files "$@" || return 1

  for file in "${RESOLVED_TASKS[@]}"; do
    case "$action" in
    verify) verify_selected_task "$file" || status=1 ;;
    check-updates) check_updates_selected_task "$file" || status=1 ;;
    update) update_selected_task "$file" || status=1 ;;
    *) run_selected_task "$file" || status=1 ;;
    esac
  done

  print_task_results
  return "$status"
}

test_selected_tasks() {
  local selector
  local -a selectors=()

  if (($# == 0)); then
    error_msg "Debe especificar una tarea o ALL."
    return 1
  fi

  for selector in "$@"; do
    if [[ $selector == "ALL" ]]; then
      bash "${RAVN_DIR}/test-task.sh" --all
      return $?
    fi
    selectors+=("$selector")
  done

  bash "${RAVN_DIR}/test-task.sh" "${selectors[@]}"
}

reset_selected_task() {
  local file="$1"
  local name=""
  local log=""

  load_task "$file"
  name="${PACKAGE:-$(basename "$file" .sh)}"
  RAVN_CURRENT_TASK_ID="${TASK_ID:-$name}"
  RAVN_CURRENT_OPERATION="reset"
  log="${RAVN_DIR}/cache/logs/${name}.log"
  RAVN_EVIDENCE_LOG_PATH="$log"
  _runner_log_dir

  if ! task_capability reset || ! task_capability verify_reset; then
    warn_msg "${name}: Reset no soportado; faltan reset() o verify_reset()."
    _runner_record "$name" "reset-unsupported"
    return 1
  fi

  if reset >>"$log" 2>&1 && verify_reset >>"$log" 2>&1; then
    _runner_redact_log "$log"
    if ! _runner_record "$name" "reset"; then
      error_msg "${name}: Reset verificado, pero no se pudo registrar la evidencia."
      return 1
    fi
    success "${name}: Reset completado y verificado."
    return 0
  fi

  _runner_redact_log "$log"
  error_msg "${name}: Reset o verificación del reset falló. Log: ${log}"
  _runner_record "$name" "reset-failed" 1
  return 1
}

reset_selected_tasks() {
  local argument selector
  local confirm=0
  local file name
  local status=0
  local -a selectors=()
  local -a supported=()

  for argument in "$@"; do
    if [[ $argument == "--yes" ]]; then
      confirm=1
    else
      selectors+=("$argument")
    fi
  done

  TASK_RESULTS=()
  TASK_FAILURES=()
  resolve_task_files "${selectors[@]}" || return 1

  echo ""
  warn_msg "Esta operación eliminará la instalación y configuración de las tareas seleccionadas."
  for file in "${RESOLVED_TASKS[@]}"; do
    load_task "$file"
    name="${PACKAGE:-$(basename "$file" .sh)}"
    RAVN_CURRENT_TASK_ID="${TASK_ID:-$name}"
    RAVN_CURRENT_OPERATION="reset"
    if task_capability reset && task_capability verify_reset; then
      supported+=("$file")
      printf '  reset: %s\n' "$name"
    else
      printf '  no soportado: %s\n' "$name"
      _runner_record "$name" "reset-unsupported"
      status=1
    fi
  done

  if ((${#supported[@]} == 0)); then
    print_task_results
    return "$status"
  fi

  if ((confirm == 0)); then
    if [[ -t 0 ]]; then
      read -r -p "Escribe RESET para confirmar: " selector
    elif ! read -r selector; then
      error_msg "Reset en entorno no interactivo requiere --yes."
      for file in "${supported[@]}"; do
        name=$(task_name "$file")
        _runner_record "$name" "reset-refused"
      done
      print_task_results
      return 1
    fi
    if [[ $selector != "RESET" ]]; then
      warn_msg "Reset cancelado."
      for file in "${supported[@]}"; do
        name=$(task_name "$file")
        _runner_record "$name" "reset-refused"
      done
      print_task_results
      return 1
    fi
  fi

  for file in "${supported[@]}"; do
    reset_selected_task "$file" || status=1
  done

  print_task_results
  return "$status"
}

print_task_results() {
  local result

  echo ""
  step "Resultados de tareas"
  for result in "${TASK_RESULTS[@]}"; do
    printf '  %s\n' "$result"
  done
}

print_task_catalog() {
  local file name family

  echo ""
  step "Tareas disponibles"
  for file in "${TASKS[@]}"; do
    name=$(task_name "$file")
    family=$(task_family "$file")
    [[ -z $family ]] && family="legacy"
    printf '  %-24s [%s]\n' "$name" "$family"
  done
}

read_task_selection() {
  local selection selector
  local -a selectors=()

  read -r -p "Tareas (ALL o separadas por coma, q para cancelar): " selection
  [[ ${selection,,} == "q" ]] && return 1
  [[ -z $selection ]] && return 1

  IFS=',' read -ra selectors <<<"$selection"
  for selector in "${selectors[@]}"; do
    selector="${selector// /}"
    [[ -n $selector ]] && printf '%s\n' "$selector"
  done
}

run_menu_selection() {
  local action="$1"
  local -a selectors=()

  mapfile -t selectors < <(read_task_selection)
  ((${#selectors[@]} > 0)) || return 0
  if [[ $action == "test" ]]; then
    test_selected_tasks "${selectors[@]}"
  elif [[ $action == "reset" ]]; then
    reset_selected_tasks "${selectors[@]}"
  else
    run_selected_tasks "$action" "${selectors[@]}"
  fi
}

run_menu() {
  local choice

  discover_tasks

  while true; do
    echo ""
    step "RaVN Task Runner"
    print_task_catalog
    echo ""
    printf '  1  Verify current configuration\n'
    printf '  2  Run full setup\n'
    printf '  3  Run integration test\n'
    printf '  4  Reset selected tasks\n'
    printf '  q  Exit\n'
    read -r -p "Selecciona una opción: " choice

    case "${choice,,}" in
    1)
      run_selected_tasks verify ALL || true
      ;;
    2)
      run_menu_selection run || true
      ;;
    3)
      run_menu_selection test || true
      ;;
    4)
      run_menu_selection reset || true
      ;;
    q)
      return 0
      ;;
    *)
      warn_msg "Opción no válida: ${choice}"
      ;;
    esac
  done
}
