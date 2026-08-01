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

task_name() (
  local file="$1"
  load_task "$file"
  printf '%s' "${PACKAGE:-$(basename "$file" .sh)}"
)

task_family() (
  local file="$1"
  load_task "$file"
  printf '%s' "${TASK_FAMILY:-}"
)

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
    error_msg "A task or ALL must be specified."
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
      error_msg "Task not found: ${selector}"
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

  if declare -f ravn_redact_log > /dev/null; then
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

  if declare -f count_ok > /dev/null; then
    case "$result" in
      verified | up-to-date | reset) count_ok "$name" ;;
      skipped | disabled | unverified | reset-refused | reset-unsupported) count_skip "$name" ;;
      *) count_fail "$name" ;;
    esac
  fi

  if declare -f ravn_record_task_evidence > /dev/null; then
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
    info "${name}: Disabled."
    _runner_record "$name" "disabled"
    return 0
  fi

  if ! task_capability verify; then
    warn_msg "${name}: verify() is missing; the postcondition cannot be confirmed."
    _runner_record "$name" "unverified"
    return 1
  fi

  if verify >> "$log" 2>&1; then
    _runner_redact_log "$log"
    if ! _runner_record "$name" "verified"; then
      error_msg "${name}: Verified, but evidence could not be recorded."
      return 1
    fi
    success "${name}: Verified."
    return 0
  fi

  _runner_redact_log "$log"
  error_msg "${name}: Verification failed. Log: ${log}"
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
    info "${name}: Disabled."
    _runner_record "$name" "disabled"
    return 0
  fi

  if check; then
    info "${name}: Ya satisfecho; omitido."
    _runner_record "$name" "skipped"
    return 0
  fi

  if ! install >> "$log" 2>&1; then
    _runner_redact_log "$log"
    error_msg "${name}: Installation failed. Log: ${log}"
    if [[ ${RAVN_DEPENDENCY_MISSING:-false} == true ]]; then
      _runner_record "$name" "dependency-missing" 1
    else
      _runner_record "$name" "failed" 1
    fi
    return 1
  fi

  if ! task_capability verify; then
    warn_msg "${name}: Installed, but verify() is missing; result is unconfirmed."
    _runner_record "$name" "unverified"
    return 1
  fi

  if verify >> "$log" 2>&1; then
    _runner_redact_log "$log"
    if ! _runner_record "$name" "verified"; then
      error_msg "${name}: Installed, but evidence could not be recorded."
      return 1
    fi
    success "${name}: Installed and verified."
    return 0
  fi

  _runner_redact_log "$log"
  error_msg "${name}: Installed, but verification failed. Log: ${log}"
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
    warn_msg "${name}: check-updates() is unsupported."
    _runner_record "$name" "unverified" 1
    return 1
  fi

  if ! check_updates >> "$log" 2>&1; then
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
    info "${name}: Update available."
    _runner_record "$name" "update-available"
  else
    success "${name}: Already up to date."
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
    warn_msg "${name}: update() is unsupported."
    _runner_record "$name" "unverified" 1
    return 1
  fi

  if update >> "$log" 2>&1; then
    _runner_redact_log "$log"
    if ! task_capability verify || ! verify >> "$log" 2>&1; then
      _runner_redact_log "$log"
      error_msg "${name}: update() finished, but verify() failed. Log: ${log}"
      _runner_record "$name" "update-failed" 1
      return 1
    fi
    if ! _runner_record "$name" "verified"; then
      error_msg "${name}: Updated, but evidence could not be recorded."
      return 1
    fi
    success "${name}: Updated and verified."
    return 0
  fi

  _runner_redact_log "$log"
  if [[ ${RAVN_UPDATE_RESULT:-} == "rollback-failed" ]]; then
    result="rollback-failed"
  elif [[ ${RAVN_UPDATE_RESULT:-} == "unsupported" ]]; then
    result="unsupported"
  fi
  error_msg "${name}: Update failed (${result}). Log: ${log}"
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
  _install_ok=0
  _install_fail=0
  _install_skip=0
  _install_ok_list=()
  _install_fail_list=()
  _install_skip_list=()
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
    error_msg "A task or ALL must be specified."
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
    warn_msg "${name}: Reset is unsupported; reset() or verify_reset() is missing."
    _runner_record "$name" "reset-unsupported"
    return 1
  fi

  if reset >> "$log" 2>&1 && verify_reset >> "$log" 2>&1; then
    _runner_redact_log "$log"
    if ! _runner_record "$name" "reset"; then
      error_msg "${name}: Reset verified, but evidence could not be recorded."
      return 1
    fi
    success "${name}: Reset completed and verified."
    return 0
  fi

  _runner_redact_log "$log"
  error_msg "${name}: Reset or reset verification failed. Log: ${log}"
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
  _install_ok=0
  _install_fail=0
  _install_skip=0
  _install_ok_list=()
  _install_fail_list=()
  _install_skip_list=()
  resolve_task_files "${selectors[@]}" || return 1

  echo ""
  warn_msg "This operation will remove the installation and configuration of the selected tasks."
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
      read -r -p "Type RESET to confirm: " selector
    elif ! read -r selector; then
      error_msg "Reset in a non-interactive environment requires --yes."
      for file in "${supported[@]}"; do
        name=$(task_name "$file")
        _runner_record "$name" "reset-refused"
      done
      print_task_results
      return 1
    fi
    if [[ $selector != "RESET" ]]; then
      warn_msg "Reset cancelled."
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
  print_summary "Task Results"
}

task_description() (
  local file="$1"

  load_task "$file"
  printf '%s' "${DESCRIPTION:-No description available.}"
)

print_task_preview() {
  local file name description

  clear || true
  print_ravn_banner "RaVN Task Runner"
  print_section "${ICON_UI_DATABASE} Task preview"
  for file in "$@"; do
    name=$(task_name "$file")
    description=$(task_description "$file")
    printf '  %s  %s\n' "$name" "$description"
  done
}

confirm_task_action() {
  local prompt="$1"
  local answer=""

  clear || true
  print_ravn_banner "RaVN Task Runner"
  print_section "${ICON_UI_COMMAND} Confirm selection"
  print_info "$prompt"

  if [[ ${RAVN_UI_EFFECTIVE:-${RAVN_UI:-bash}} == gum ]]; then
    gum confirm "$prompt"
    return
  fi

  read -r -p "${LIGHT_GRAY}Proceed? [y/N]:${NC} " answer
  [[ ${answer,,} == y || ${answer,,} == yes ]]
}

task_family_display_name() {
  case "$1" in
    cli-tools) printf 'CLI Tools' ;;
    legacy) printf 'Legacy' ;;
    *) printf '%s' "${1^}" ;;
  esac
}

task_family_icon() {
  case "$1" in
    cli-tools) printf '%s' "$ICON_UI_TERMINAL" ;;
    legacy) printf '%s' "$ICON_DIAGNOSTIC_WARNING" ;;
    *) printf '%s' "$ICON_UI_PACKAGE" ;;
  esac
}

task_family_keys() {
  local file family
  local -a known=() unknown=()

  while IFS= read -r family; do
    case "$family" in
      cli-tools | legacy) known+=("$family") ;;
      *) unknown+=("$family") ;;
    esac
  done < <(
    for file in "${TASKS[@]}"; do
      family=$(task_family "$file")
      [[ -n $family ]] || family="legacy"
      printf '%s\n' "$family"
    done | sort -u
  )

  printf '%s\n' "${known[@]}" "${unknown[@]}" | sed '/^$/d'
}

task_family_count() {
  local target="$1"
  local file family count=0

  for file in "${TASKS[@]}"; do
    family=$(task_family "$file")
    [[ -n $family ]] || family="legacy"
    [[ $family == "$target" ]] && count=$((count + 1))
  done
  printf '%s\n' "$count"
}

print_task_catalog() {
  local family display count

  print_section "${ICON_UI_DATABASE} Task inventory"
  while IFS= read -r family; do
    display=$(task_family_display_name "$family")
    count=$(task_family_count "$family")
    printf '  %s  %s · %s tasks\n' "$(task_family_icon "$family")" "$display" "$count"
  done < <(task_family_keys)
}

select_task_family() {
  local family display count choice selected
  local -a families=() options=()

  mapfile -t families < <(task_family_keys)
  ((${#families[@]} > 0)) || {
    print_info "No tasks available"
    return 1
  }

  local index=1
  for family in "${families[@]}"; do
    display=$(task_family_display_name "$family")
    count=$(task_family_count "$family")
    options+=("${index}  $(task_family_icon "$family")  ${display} · ${count} tasks")
    index=$((index + 1))
  done
  options+=("${index}  ${ICON_UI_DATABASE}  All categories · $((${#TASKS[@]})) tasks")

  clear || true
  print_ravn_banner "RaVN Task Runner"
  print_section "${ICON_UI_DATABASE} Choose tasks"
  if [[ ${RAVN_UI_EFFECTIVE:-${RAVN_UI:-bash}} == gum ]]; then
    selected=$(gum choose --header "" --cursor "$ICON_UI_ARROW" "${options[@]}") || return 1
    choice="${selected%% *}"
  else
    printf '%s\n' "${options[@]}"
    printf 'q  %s  Back\n' "$ICON_UI_ARROW_LEFT"
    if ! read -r -p "${LIGHT_GRAY}Selection:${NC} " choice; then
      return 1
    fi
    [[ ${choice,,} == q || $choice == $'\e' ]] && return 1
  fi

  if ! [[ $choice =~ ^[1-9][0-9]*$ ]] || ((choice < 1 || choice > ${#options[@]})); then
    print_warn "Invalid task family selection: ${choice}"
    return 1
  fi

  if ((choice == ${#options[@]})); then
    SELECTED_TASK_FAMILY="ALL"
  else
    SELECTED_TASK_FAMILY="${families[choice - 1]}"
  fi
}

select_tasks_for_family() {
  local file name family display selected choice index invalid=0
  local -a files=() names=() options=() selections=()

  while IFS=$'\t' read -r name file; do
    files+=("$file")
    names+=("$name")
  done < <(
    for file in "${TASKS[@]}"; do
      family=$(task_family "$file")
      [[ -n $family ]] || family="legacy"
      [[ $SELECTED_TASK_FAMILY == ALL || $family == "$SELECTED_TASK_FAMILY" ]] || continue
      printf '%s\t%s\n' "$(task_name "$file")" "$file"
    done | sort -f -k1,1
  )

  ((${#files[@]} > 0)) || {
    print_info "No tasks available in the selected category"
    return 1
  }

  for index in "${!files[@]}"; do
    family=$(task_family "${files[index]}")
    [[ -n $family ]] || family="legacy"
    display=$(task_family_display_name "$family")
    options+=("$((index + 1))  $(task_family_icon "$family")  ${names[index]} · ${display}")
  done

  clear || true
  print_ravn_banner "RaVN Task Runner"
  print_section "${ICON_UI_DATABASE} Choose tasks"
  if [[ ${RAVN_UI_EFFECTIVE:-${RAVN_UI:-bash}} == gum ]]; then
    mapfile -t selections < <(gum choose --no-limit --header "" --cursor "$ICON_UI_ARROW" "${options[@]}") || return 1
  else
    printf '%s\n' "${options[@]}"
    printf 'q  %s  Back\n' "$ICON_UI_ARROW_LEFT"
    if ! read -r -p "${LIGHT_GRAY}Selection (comma-separated):${NC} " selected; then
      return 1
    fi
    [[ ${selected,,} == q || $selected == $'\e' || -z $selected ]] && return 1
    IFS=',' read -ra selections <<< "$selected"
  fi

  SELECTED_TASKS=()
  for selected in "${selections[@]}"; do
    if [[ ${RAVN_UI_EFFECTIVE:-${RAVN_UI:-bash}} == gum ]]; then
      choice="${selected%% *}"
    elif [[ $selected =~ ^[[:space:]]*([1-9][0-9]*)[[:space:]]*$ ]]; then
      choice="${BASH_REMATCH[1]}"
    else
      invalid=1
      continue
    fi
    if [[ $choice =~ ^[1-9][0-9]*$ ]] && ((choice <= ${#files[@]})); then
      SELECTED_TASKS+=("$(task_name "${files[choice - 1]}")")
    else
      invalid=1
    fi
  done
  if ((invalid == 1)); then
    SELECTED_TASKS=()
    print_warn "Invalid task selection; no tasks were selected."
    return 1
  fi
  ((${#SELECTED_TASKS[@]} > 0)) || {
    print_info "No tasks selected"
    return 1
  }
}

run_menu_selection() {
  local action="$1"
  local -a selectors=()

  select_task_family || return 0
  select_tasks_for_family || return 0
  selectors=("${SELECTED_TASKS[@]}")
  resolve_task_files "${selectors[@]}" || return 0
  print_task_preview "${RESOLVED_TASKS[@]}"
  if [[ $action == "test" || $action == "reset" || $action == "run" ]]; then
    if ! confirm_task_action "${#selectors[@]} selected task(s) will be processed"; then
      print_info "Action cancelled"
      return 0
    fi
  fi
  if [[ $action == "test" ]]; then
    test_selected_tasks "${selectors[@]}"
  elif [[ $action == "reset" ]]; then
    reset_selected_tasks --yes "${selectors[@]}"
  else
    run_selected_tasks "$action" "${selectors[@]}"
  fi
}

task_runner_main_menu_options() {
  printf '1  %s  Verify current configuration\n' "$ICON_UI_GEAR"
  printf '2  %s  Run full setup\n' "$ICON_UI_ROCKET"
  printf '3  %s  Run integration test\n' "$ICON_UI_TEST"
  printf '4  %s  Reset selected tasks\n' "$ICON_UI_TRASH"
  printf 'q  %s  Exit\n' "$ICON_UI_CLOSE"
}

read_task_runner_main_menu_choice() {
  local -a options=()
  local choice=""
  local gum_choice=""

  mapfile -t options < <(task_runner_main_menu_options)
  if [[ ${RAVN_UI_EFFECTIVE:-${RAVN_UI:-bash}} == gum ]]; then
    gum_choice=$(gum choose --header "" --cursor "$ICON_UI_ARROW" "${options[@]}") || return 1
    MENU_CHOICE="${gum_choice%% *}"
    return 0
  fi

  for choice in "${options[@]}"; do
    printf '  %b%s%b  %s\n' "$GREEN" "${choice%% *}" "$NC" "${choice#*  }"
  done
  if ! read -r -p "${LIGHT_GRAY}Selection:${NC} " choice; then
    return 1
  fi
  [[ $choice == $'\e' ]] && return 1
  MENU_CHOICE="$choice"
}

run_menu() {
  local choice

  if ! discover_tasks; then
    error_msg "Task discovery failed; the interactive menu cannot start."
    return 1
  fi
  if [[ ${RAVN_DISCOVERY_RESULT:-} == empty ]]; then
    info "No tasks are available; the interactive menu cannot start."
    return 0
  fi

  while true; do
    clear || true
    print_ravn_banner "RaVN Task Runner"
    print_section "${ICON_UI_COMMAND} Choose an action"
    print_task_catalog
    echo ""
    if ! read_task_runner_main_menu_choice; then
      return 0
    fi
    choice="$MENU_CHOICE"

    case "${choice,,}" in
      1)
        run_menu_selection verify || true
        ;;
      2)
        print_task_preview "${TASKS[@]}"
        if confirm_task_action "All discovered tasks will be executed"; then
          run_pipeline || true
        else
          print_info "Action cancelled"
        fi
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
        warn_msg "Invalid option: ${choice}"
        ;;
    esac
  done
}
