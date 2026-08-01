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

RAVN_UI="${RAVN_UI:-auto}"
export RAVN_UI
RAVN_OS_RELEASE_FILE="${RAVN_OS_RELEASE_FILE:-/etc/os-release}"
export RAVN_OS_RELEASE_FILE

ravn_validate_interactive_dependencies() {
  local os_id=""
  local command_name=""
  local -a missing=()

  [[ -r $RAVN_OS_RELEASE_FILE ]] || {
    print_error "Unsupported operating system; Ravn Task Runner supports Arch Linux and Arch-based systems only"
    return 1
  }
  # shellcheck disable=SC1091
  # shellcheck disable=SC1090
  source "$RAVN_OS_RELEASE_FILE"
  os_id="${ID:-}"
  if [[ $os_id != "arch" && ${ID_LIKE:-} != *arch* ]]; then
    print_error "Unsupported operating system; Ravn Task Runner supports Arch Linux and Arch-based systems only"
    return 1
  fi

  case "$RAVN_UI" in
    auto | gum | bash) ;;
    *)
      print_error "Invalid RAVN_UI value: ${RAVN_UI} (expected auto, gum, or bash)"
      return 1
      ;;
  esac

  for command_name in git curl gum; do
    command_exists "$command_name" || missing+=("$command_name")
  done

  if ((${#missing[@]} > 0)); then
    sudo pacman -Syu --noconfirm --needed git curl gum || {
      print_error "Unable to install interactive dependencies: ${missing[*]}"
      return 1
    }
  fi

  for command_name in git curl gum; do
    if ! command_exists "$command_name"; then
      print_error "Required command not found after preflight: ${command_name}"
      return 1
    fi
  done

  if [[ $RAVN_UI == bash ]]; then
    RAVN_UI_EFFECTIVE="bash"
  else
    RAVN_UI_EFFECTIVE="gum"
  fi
  export RAVN_UI_EFFECTIVE
}

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
      error_msg "No subcommand in non-interactive mode. Use: setup.sh run|verify|reset|update|check-updates <task>"
      return 2
    fi
    ravn_validate_interactive_dependencies || return
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

  step "Final Configuration"
  print_log -g "[FINAL CONFIG] " -b " :: " "Starting final configuration..."

  discover_tasks
  run_pipeline
}

main "$@"
