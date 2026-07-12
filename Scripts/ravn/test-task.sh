#!/usr/bin/env bash
# =============================================================================
# test-task.sh — Isolated Docker Tester for RaVN Task Modules
# =============================================================================
#
# Purpose:
#   Allows safe, reproducible testing of any RaVN task module in a clean
#   Docker environment (Arch Linux) without affecting the host system.
#
#   This is the recommended way to validate tasks before committing them.
#
# Usage:
#   ./test-task.sh --all
#   ./test-task.sh hermes
#   ./test-task.sh 25-hermes
#   ./test-task.sh 10-npm-apps
#   ./test-task.sh hermes codex grok
#   ./test-task.sh hermes --dry-run
#   ./test-task.sh hermes --keep
#
# Supported selectors:
#   --all                 → All discovered tasks
#   <name>                → Matches filename or PACKAGE= value
#   <category>            → e.g. 00-core, 10-npm-apps, 30-system
#   <NN-name.sh>          → Specific task file
#
# Options:
#   --dry-run             Run in simulation mode inside the container
#   --keep                Do not remove the container after execution (debugging)
#   -h, --help            Show this help
#
# How it works:
#   1. Starts a fresh Arch Linux container
#   2. Sources global_fn.sh (required by most tasks)
#   3. Sources the task module
#   4. Executes its install() function
#   5. Verifies that check() returns success afterwards
#   6. Reports PASS / FAIL for each task
#
# This script was created after successfully validating the Hermes task
# (25-hermes.sh) in complete isolation.
#
# Location: Scripts/ravn/test-task.sh
# =============================================================================

set -e

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TASKS_DIR="${RAVN_DIR}/tasks"
GLOBAL_FN="${RAVN_DIR}/global_fn.sh"

DOCKER_IMAGE="archlinux:latest"

print_usage() {
  cat <<EOF
test-task.sh — Pruebas aisladas de tareas RaVN (Docker)

Uso:
  $(basename "$0") --all                    # Todas las tareas
  $(basename "$0") <nombre|patrón>          # Una o varias por nombre
  $(basename "$0") 10-npm-apps              # Todas las de una categoría
  $(basename "$0") hermes codex             # Varias tareas específicas

Opciones:
  --dry-run     Ejecuta install() en modo simulación
  --keep        Mantiene el contenedor después de la prueba (debug)
  --mise-version <ver>  Fija el fixture de mise para Docker/VM
  -h, --help    Muestra esta ayuda

Ejemplos:
  ./test-task.sh hermes
  ./test-task.sh 25-hermes --dry-run
  ./test-task.sh --all
EOF
}

get_task_metadata() {
  local task_file="$1"
  local metadata=""

  metadata=$(
    # shellcheck disable=SC1091,SC1090
    source "${RAVN_DIR}/framework/package.sh"
    # shellcheck disable=SC1090
    source "$task_file"
    printf '%s|%s|%s|%s' "${PACKAGE:-}" "${TEST_LEVEL:-}" "${INSTALLER_STRATEGY:-}" "${REFERENCE_ONLY:-false}"
  )
  printf '%s' "$metadata"
}

task_is_reference_only() {
  local task_file="$1"
  local metadata=""
  local reference_only=""

  metadata=$(get_task_metadata "$task_file")
  IFS='|' read -r _ _ _ reference_only <<<"$metadata"
  [[ ${reference_only:-false} == true ]]
}

partition_active_tasks() {
  local task_file=""
  local package=""
  local -a active_tasks=()
  local -a reference_tasks=()

  ACTIVE_TASKS=()
  SKIPPED_REFERENCES=()

  for task_file in "$@"; do
    [[ ! -f $task_file ]] && continue
    if task_is_reference_only "$task_file"; then
      metadata=$(get_task_metadata "$task_file")
      IFS='|' read -r package _ _ _ <<<"$metadata"
      [[ -z $package ]] && package=$(basename "$task_file" .sh)
      reference_tasks+=("$package")
    else
      active_tasks+=("$task_file")
    fi
  done

  ACTIVE_TASKS=("${active_tasks[@]}")
  SKIPPED_REFERENCES=("${reference_tasks[@]}")
}

run_static_test() {
  local task_file="$1"

  bash -n "$task_file" && shellcheck "$task_file"
}

# Parse arguments
TASKS_TO_TEST=()
DRY_RUN=0
KEEP_CONTAINER=0
INCLUDE_REFERENCES=0
MISE_FIXTURE_VERSION="${RAVN_MISE_FIXTURE_VERSION:-2026.6.11}"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --all)
    mapfile -t TASKS_TO_TEST < <(find "$TASKS_DIR" -name "*.sh" | sort)
    shift
    ;;
  ALL | all)
    mapfile -t TASKS_TO_TEST < <(find "$TASKS_DIR" -name "*.sh" | sort)
    shift
    ;;
  --dry-run)
    DRY_RUN=1
    shift
    ;;
  --keep)
    KEEP_CONTAINER=1
    shift
    ;;
  --include-reference)
    INCLUDE_REFERENCES=1
    shift
    ;;
  --mise-version)
    if (($# < 2)); then
      echo "Error: --mise-version requiere una versión." >&2
      exit 2
    fi
    MISE_FIXTURE_VERSION="$2"
    shift 2
    ;;
  -h | --help)
    print_usage
    exit 0
    ;;
  *)
    if [[ -d "$TASKS_DIR/$1" ]]; then
      mapfile -t found < <(find "$TASKS_DIR/$1" -name "*.sh" | sort)
      TASKS_TO_TEST+=("${found[@]}")
    else
      mapfile -t found < <(find "$TASKS_DIR" -name "*${1}*.sh" | sort)
      if [[ ${#found[@]} -eq 0 ]]; then
        mapfile -t found < <(grep -rl "PACKAGE=.*${1}" "$TASKS_DIR" 2>/dev/null | sort)
      fi
      TASKS_TO_TEST+=("${found[@]}")
    fi
    shift
    ;;
  esac
done

if [[ ${#TASKS_TO_TEST[@]} -eq 0 ]]; then
  echo "Error: No se especificaron tareas para probar."
  print_usage
  exit 1
fi

# Deduplicate
mapfile -t TASKS_TO_TEST < <(printf "%s\n" "${TASKS_TO_TEST[@]}" | sort -u)

ACTIVE_TASKS=()
SKIPPED_REFERENCES=()
if ((INCLUDE_REFERENCES == 0)); then
  partition_active_tasks "${TASKS_TO_TEST[@]}"
  TASKS_TO_TEST=("${ACTIVE_TASKS[@]}")
fi

echo "==> RaVN Task Tester (entorno aislado Docker)"
echo "    Tareas activas a probar: ${#TASKS_TO_TEST[@]}"
if ((${#SKIPPED_REFERENCES[@]} > 0)); then
  echo "    Omitidas (reference-only): ${#SKIPPED_REFERENCES[@]} (${SKIPPED_REFERENCES[*]})"
fi
echo ""

FAILED=()
PASSED=()
UNSUPPORTED=()

for task_file in "${TASKS_TO_TEST[@]}"; do
  [[ ! -f "$task_file" ]] && continue

  task_name=$(basename "$task_file" .sh)
  rel_path=${task_file#"$TASKS_DIR"/}

  echo "────────────────────────────────────────────────────────"
  echo "Probando: $rel_path"

  metadata=$(get_task_metadata "$task_file")
  IFS='|' read -r package test_level installer_strategy reference_only <<<"$metadata"
  [[ -z $package ]] && package="$task_name"

  if [[ ${reference_only:-false} == true && $INCLUDE_REFERENCES == 0 ]]; then
    echo "↷ $package → OMITIDA (reference-only; use --include-reference)"
    continue
  fi

  case "$test_level" in
  static)
    if run_static_test "$task_file"; then
      echo "✓ $package → PASÓ (static)"
      PASSED+=("$package")
    else
      echo "✗ $package → FALLÓ (static)"
      FAILED+=("$package")
    fi
    continue
    ;;
  live)
    echo "⚠ $package → NO VERIFICABLE (requiere live)"
    UNSUPPORTED+=("$package")
    continue
    ;;
  "" | isolated)
    ;;
  *)
    echo "⚠ $package → NO VERIFICABLE (TEST_LEVEL inválido: $test_level)"
    UNSUPPORTED+=("$package")
    continue
    ;;
  esac

  required_packages="curl git which"

  test_script=$(mktemp)
  cat >"$test_script" <<EOF
#!/usr/bin/env bash
set -e
export PATH="\$HOME/.local/bin:\$PATH"
export OMARCHY_NPX_INSTALLER="/omarchy-npx-install"
echo "=== Actualizando sistema base ==="
pacman -Syu --noconfirm ${required_packages} 2>&1 | tail -3

echo "=== Ejecutando tarea: $package ==="

# Source global_fn.sh first (provides step, warn_msg, info, success, etc.)
if [[ -f "/global_fn.sh" ]]; then
source "/global_fn.sh" 2>/dev/null || true
fi

source "/package.sh" 2>/dev/null || true
source "/hooks.sh" 2>/dev/null || true
source "/contract.sh" 2>/dev/null || true
source "/mise.sh" 2>/dev/null || true
source "/mise-cli.sh" 2>/dev/null || true
source "/upstream.sh" 2>/dev/null || true
export RAVN_DIR="/"
source "/task.sh" 2>/dev/null || true

if [[ "$installer_strategy" == "mise" || "$installer_strategy" == "omarchy-npx" ]]; then
  export RAVN_ALLOW_MISE_BOOTSTRAP=1
  export RAVN_MISE_FIXTURE_VERSION="$MISE_FIXTURE_VERSION"
  export RAVN_MISE_BOOTSTRAP_DIR="/tmp/ravn-mise"
  ravn_bootstrap_mise > /dev/null
  RAVN_MISE_BIN="\$(ravn_mise_binary)"
  export RAVN_MISE_BIN
  export PATH="\$(dirname "\$RAVN_MISE_BIN"):\$PATH"
  ravn_verify_mise > /dev/null
  printf 'mise fixture: %s\n' "\$RAVN_EVIDENCE_MISE_VERSION"
fi
if declare -f install >/dev/null; then
  if (( $DRY_RUN == 1 )); then
    echo "Modo dry-run activado"
    if declare -f check >/dev/null; then
      if check; then
        echo "check() → ya instalado (skip)"
      else
        echo "check() → necesita instalación"
      fi
    fi
    echo "install() simulado correctamente"
  else
    install
  fi
else
  echo "⚠ La tarea no define función install()"
fi

echo "=== Verificando resultado ==="
if declare -f verify >/dev/null && task_capability verify; then
  if verify; then
    echo "✓ verify() pasó correctamente"
    exit 0
  else
    echo "✗ verify() falló después de la instalación"
    exit 1
  fi
elif declare -f check >/dev/null; then
  echo "⚠ verify() no está implementado; resultado no verificable"
  exit 42
else
  echo "⚠ Tarea sin verify() — resultado no verificable"
  exit 42
fi
EOF

  chmod +x "$test_script"

  container_name="ravn-test-$(date +%s)-$$"
  docker_args=("--name" "$container_name" "--rm")

  if ((KEEP_CONTAINER == 1)); then
    docker_args=("--name" "$container_name")
  fi

  if docker run "${docker_args[@]}" \
    -v "$task_file:/task.sh:ro" \
    -v "$GLOBAL_FN:/global_fn.sh:ro" \
    -v "$RAVN_DIR/omarchy-npx-install:/omarchy-npx-install:ro" \
    -v "$RAVN_DIR/framework/package.sh:/package.sh:ro" \
    -v "$RAVN_DIR/framework/hooks.sh:/hooks.sh:ro" \
    -v "$RAVN_DIR/framework/contract.sh:/contract.sh:ro" \
    -v "$RAVN_DIR/framework/mise.sh:/mise.sh:ro" \
    -v "$RAVN_DIR/framework/mise-cli.sh:/mise-cli.sh:ro" \
    -v "$RAVN_DIR/framework/upstream.sh:/upstream.sh:ro" \
    -v "$test_script:/test.sh:ro" \
    "$DOCKER_IMAGE" bash /test.sh; then
    echo "✓ $package → PASÓ"
    PASSED+=("$package")
  else
    rc=$?
    if ((rc == 42)); then
      echo "⚠ $package → NO VERIFICABLE"
      UNSUPPORTED+=("$package")
    else
      echo "✗ $package → FALLÓ"
      FAILED+=("$package")
    fi
  fi

  rm -f "$test_script"
done

echo ""
echo "════════════════════════════════════════════════════════"
echo "Resumen de pruebas"
echo "  ✓ Pasaron:  ${#PASSED[@]}"
echo "  ✗ Fallaron: ${#FAILED[@]}"
if ((${#SKIPPED_REFERENCES[@]} > 0)); then
  echo "  ↷ Omitidas (reference): ${#SKIPPED_REFERENCES[@]}"
fi
echo "  ⚠ No verificables: ${#UNSUPPORTED[@]}"
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "  Fallidos: ${FAILED[*]}"
  exit 1
fi
echo "════════════════════════════════════════════════════════"
