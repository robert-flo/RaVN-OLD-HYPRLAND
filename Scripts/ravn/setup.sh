#!/usr/bin/env bash
#|---/ /+-------------------------------+---/ /|#
#|--/ /-| RaVN Framework v1 — Bootstrap |--/ /-|#
#|-/ /--| Roberto Flores                |-/ /--|#
#|/ /---+-------------------------------+/ /---|#

set -e

# ─── Resolve paths ───────────────────────────────────────────────────────────
RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export RAVN_DIR

scrDir="$(dirname "$RAVN_DIR")"
export scrDir

# ─── Source runtime library ──────────────────────────────────────────────────
# shellcheck disable=SC1091
source "${RAVN_DIR}/global_fn.sh"

# ─── Inherit flags from parent installer or load from configuration ──────────
if [[ -z ${flg_DryRun:-} ]]; then
  if [[ -f "${RAVN_DIR}/config/ravn.conf" ]] && grep -q "^dry_run=true" "${RAVN_DIR}/config/ravn.conf"; then
    flg_DryRun=1
  else
    flg_DryRun=0
  fi
fi
export flg_DryRun

# ─── Source framework modules ────────────────────────────────────────────────
for fw in "${RAVN_DIR}"/framework/*.sh; do
  # shellcheck disable=SC1090
  source "$fw"
done

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  local action="${1:-}"

  if [[ -z $action ]]; then
    if ((flg_DryRun == 1)); then
      discover_tasks
      run_pipeline
      return 0
    fi
    if [[ ! -t 0 ]]; then
      error_msg "Sin subcomando en entorno no interactivo. Use: setup.sh run|verify|reset|update|check-updates <tarea>"
      return 2
    fi
    run_menu
    return
  fi

  if [[ $action == "verify" || $action == "run" || $action == "test" || $action == "matrix" || $action == "reset" || $action == "update" || $action == "check-updates" || $action == "baseline" || $action == "--baseline" ]]; then
    if [[ $action == "baseline" || $action == "--baseline" ]]; then
      action="run"
      set -- BASELINE
    elif [[ $action == "test" ]]; then
      shift
      discover_tasks
      test_selected_tasks "$@"
      return
    elif [[ $action == "matrix" ]]; then
      shift
      if [[ ${1:-} == "grok" ]]; then
        shift
        bash "${RAVN_DIR}/tests/grok-matrix.sh" "$@"
      else
        bash "${RAVN_DIR}/tests/opencode-matrix.sh" "$@"
      fi
      return
    elif [[ $action == "reset" ]]; then
      shift
      discover_tasks
      reset_selected_tasks "$@"
      return
    else
      shift
    fi
    discover_tasks
    run_selected_tasks "$action" "$@"
    return
  fi

  step "Configuración Final"
  print_log -g "[FINAL CONFIG] " -b " :: " "Iniciando configuración final..."

  discover_tasks
  run_pipeline
}

main "$@"
