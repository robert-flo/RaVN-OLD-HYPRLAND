#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT=$(mktemp -d)
readonly TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly REPO_ROOT
SUDO_LOG="$TEST_ROOT/sudo.log"
readonly SUDO_LOG
PHASE_LOG="$TEST_ROOT/phases.log"
readonly PHASE_LOG

sudo() {
  printf '%s\n' "$*" >> "$RAVN_TEST_SUDO_LOG"
  return 1
}
export -f sudo

seed_user_home() {
  local user_home=$1

  mkdir -p "$user_home/.config/fish"
  printf 'managed configuration must be replaced\n' > "$user_home/.config/fish/config.fish"
}

run_user_only() {
  local mode=$1
  local user_home=$2
  local output=$3
  local exit_status=0

  set +e
  env \
    HOME="$user_home" \
    XDG_CACHE_HOME="$user_home/.cache" \
    XDG_CONFIG_HOME="$user_home/.config" \
    XDG_STATE_HOME="$user_home/.local/state" \
    RAVN_TEST_SUDO_LOG="$SUDO_LOG" \
    bash "$REPO_ROOT/Scripts/install.sh" "$mode" < /dev/null > "$output" 2>&1
  exit_status=$?
  set -e

  if ((exit_status != 0)); then
    printf 'install.sh %s exited with %s:\n' "$mode" "$exit_status" >&2
    cat "$output" >&2
    return 1
  fi
}

assert_user_only_result() {
  local user_home=$1
  local output=$2

  if [[ -s $SUDO_LOG ]]; then
    printf 'user-only restore invoked sudo:\n' >&2
    cat "$SUDO_LOG" >&2
    return 1
  fi

  cmp "$REPO_ROOT/Configs/.config/fish/config.fish" "$user_home/.config/fish/config.fish"
  rg -uuu -q 'managed configuration must be replaced' "$user_home/.config/cfg_backups"
  rg -q '\[user-only\].*skipping privileged phases' "$output"
}

write_phase_stub() {
  local path=$1
  local phase=$2

  mkdir -p "$(dirname "$path")"
  printf '%s\n' '#!/usr/bin/env bash' "printf '%s\\n' '$phase' >> \"\$RAVN_TEST_PHASE_LOG\"" > "$path"
  chmod +x "$path"
}

create_full_restore_fixture() {
  local fixture_root=$1
  local fixture_scripts="$fixture_root/Scripts"

  mkdir -p "$fixture_scripts"
  cp "$REPO_ROOT/Scripts/install.sh" "$fixture_scripts/install.sh"
  # shellcheck disable=SC2016
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/ravn"' \
    'print_log() { printf "%s " "$@"; printf "\\n"; }' > "$fixture_scripts/global_fn.sh"

  write_phase_stub "$fixture_scripts/restore_fnt.sh" font_restore
  write_phase_stub "$fixture_scripts/restore_cfg.sh" config_restore
  write_phase_stub "$fixture_scripts/restore_thm.sh" theme_restore
  write_phase_stub "$fixture_scripts/migrations/v00.0.0.sh" migration
  write_phase_stub "$fixture_scripts/launchers/install_launchers.sh" launchers
}

run_full_restore_fixture() {
  local fixture_root=$1
  local user_home=$2
  local output=$3
  local exit_status=0

  set +e
  env \
    HOME="$user_home" \
    XDG_CACHE_HOME="$user_home/.cache" \
    XDG_CONFIG_HOME="$user_home/.config" \
    XDG_STATE_HOME="$user_home/.local/state" \
    RAVN_TEST_SUDO_LOG="$SUDO_LOG" \
    RAVN_TEST_PHASE_LOG="$PHASE_LOG" \
    bash "$fixture_root/Scripts/install.sh" -r < /dev/null > "$output" 2>&1
  exit_status=$?
  set -e

  if ((exit_status != 0)); then
    printf 'fixture install.sh -r exited with %s:\n' "$exit_status" >&2
    cat "$output" >&2
    return 1
  fi
}

USER_ONLY_HOME="$TEST_ROOT/user-only-home"
readonly USER_ONLY_HOME
USER_ONLY_OUTPUT="$TEST_ROOT/user-only.out"
readonly USER_ONLY_OUTPUT
seed_user_home "$USER_ONLY_HOME"
run_user_only -o "$USER_ONLY_HOME" "$USER_ONLY_OUTPUT"
assert_user_only_result "$USER_ONLY_HOME" "$USER_ONLY_OUTPUT"
test -f "$REPO_ROOT/Scripts/install_pkg.lst"

: > "$SUDO_LOG"
COMPATIBILITY_HOME="$TEST_ROOT/compatibility-home"
readonly COMPATIBILITY_HOME
COMPATIBILITY_OUTPUT="$TEST_ROOT/compatibility.out"
readonly COMPATIBILITY_OUTPUT
seed_user_home "$COMPATIBILITY_HOME"
run_user_only -ro "$COMPATIBILITY_HOME" "$COMPATIBILITY_OUTPUT"
assert_user_only_result "$COMPATIBILITY_HOME" "$COMPATIBILITY_OUTPUT"
cmp "$USER_ONLY_HOME/.config/fish/config.fish" "$COMPATIBILITY_HOME/.config/fish/config.fish"

: > "$SUDO_LOG"
FULL_RESTORE_FIXTURE="$TEST_ROOT/full-restore-fixture"
readonly FULL_RESTORE_FIXTURE
FULL_RESTORE_HOME="$TEST_ROOT/full-restore-home"
readonly FULL_RESTORE_HOME
FULL_RESTORE_OUTPUT="$TEST_ROOT/full-restore.out"
readonly FULL_RESTORE_OUTPUT
create_full_restore_fixture "$FULL_RESTORE_FIXTURE"
run_full_restore_fixture "$FULL_RESTORE_FIXTURE" "$FULL_RESTORE_HOME" "$FULL_RESTORE_OUTPUT"

if [[ ! -s $SUDO_LOG ]]; then
  printf 'install.sh -r did not retain its privileged preflight\n' >&2
  exit 1
fi

for phase in font_restore config_restore theme_restore migration launchers; do
  rg -qx "$phase" "$PHASE_LOG"
done

printf 'install user-only mode: passed\n'
