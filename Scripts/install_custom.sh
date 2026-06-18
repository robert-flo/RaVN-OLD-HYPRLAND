#!/usr/bin/env bash

set -Eeuo pipefail

scrDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${scrDir}/global_fn.sh"

CACHE_DIR="${HOME}/.cache/bootstrap"
LOG_DIR="${CACHE_DIR}/logs"

mkdir -p "$LOG_DIR"

TASKS=()

INSTALLED=0
SKIPPED=0
FAILED=0

discover_tasks() {

    mapfile -t TASKS < <(
        find "${scrDir}/installers" \
            -type f \
            -name "*.sh" |
            sort
    )

}

spinner() {

    local pid=$1
    local delay=.08

    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

    while kill -0 "$pid" 2>/dev/null; do
        for frame in "${frames[@]}"; do
            printf "\r%s " "$frame"
            sleep "$delay"
        done
    done
}

run_task() {

    local file="$1"

    unset PACKAGE
    unset CHECK

    source "$file"

    local name="$PACKAGE"

    printf "%-18s" "$name"

    if command -v "$CHECK" &>/dev/null; then
        success "󰄬 skipped"
        ((++SKIPPED))
        return
    fi

    local log="${LOG_DIR}/${name}.log"

    local start
    start=$(date +%s)

    (
        install
    ) >"$log" 2>&1 &

    local pid=$!

    spinner "$pid"

    wait "$pid"

    local status=$?
    local end
    end=$(date +%s)
    local elapsed=$((end-start))

    if ((status == 0)); then
        printf "\r"
        success "󰄬 ${elapsed}s"
        ((++INSTALLED))
    else
        printf "\r"
        error_msg "󰄲 failed"
        info "󰈔 ${log}"
        ((++FAILED))
    fi
}

run_pipeline() {

    local start
    start=$(date +%s)

    echo
    info "󰋼 Bootstrap started"
    echo

    for file in "${TASKS[@]}"; do
        run_task "$file"
    done

    local end
    end=$(date +%s)

    echo
    echo "────────────────────────────"
    echo

    info "󱐋 Summary"
    echo

    success "󰄬 Installed : $INSTALLED"
    success "󰄬 Skipped   : $SKIPPED"

    if ((FAILED)); then
        error_msg "󰄲 Failed    : $FAILED"
    else
        success "󰄬 Failed    : 0"
    fi

    echo
    info "Completed in $((end-start))s"
}

main() {
    discover_tasks
    run_pipeline
}

main "$@"
