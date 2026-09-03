#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OMARCHYVM_SCRIPT="$SCRIPT_DIR/omarchyvm.sh"
TEST_TMP_BASE="${OMARCHYVM_TEST_TMPDIR:-${XDG_CACHE_HOME:-$HOME/.cache}/omarchyvm-tests}"
mkdir -p "$TEST_TMP_BASE"
FIXTURE_DIR="$(mktemp -d "$TEST_TMP_BASE/omarchyvm-test.XXXXXX")"
FAKE_BIN="$FIXTURE_DIR/bin"

cleanup() {
  rm -rf "$FIXTURE_DIR"
}

trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"

  grep -Fq -- "$needle" <<< "$haystack" || fail "expected output to contain: $needle"
}

mkdir -p "$FAKE_BIN"
touch "$FAKE_BIN/qemu-system-x86_64" "$FAKE_BIN/qemu-img"
chmod +x "$FAKE_BIN/qemu-system-x86_64" "$FAKE_BIN/qemu-img"
ln -s /usr/bin/true "$FAKE_BIN/ssh"
export PATH="$FAKE_BIN:$PATH"
export XDG_CACHE_HOME="$FIXTURE_DIR/cache"

menu_output=$(printf 'q\n' | "$OMARCHYVM_SCRIPT")
assert_contains "$menu_output" "Choose an action"
assert_contains "$menu_output" "Run installed system (ephemeral)"
assert_contains "$menu_output" "Run installed system (persistent)"
assert_contains "$menu_output" "Rebuild base (unattended install)"
assert_contains "$menu_output" "Configure RAM and CPU"
assert_contains "$menu_output" "Install SSH alias"
assert_contains "$menu_output" "Connect to VM via SSH"
assert_contains "$menu_output" "Goodbye"

invalid_output=$(printf 'x\n\nq\n' | "$OMARCHYVM_SCRIPT")
assert_contains "$invalid_output" "Invalid option: x"

mode_output=$(printf '1\nq\nq\n' | "$OMARCHYVM_SCRIPT")
assert_contains "$mode_output" "Choose VM mode"
assert_contains "$mode_output" "Ephemeral"
assert_contains "$mode_output" "Persistent"
assert_contains "$mode_output" "Back"

help_output=$("$OMARCHYVM_SCRIPT" --help)
assert_contains "$help_output" "Usage: omarchyvm"
assert_contains "$help_output" "--rebuild"
assert_contains "$help_output" "OMARCHY_SSH_PORT"

snapshot_output=$("$OMARCHYVM_SCRIPT" --list)
assert_contains "$snapshot_output" "Available Omarchy snapshots"
assert_contains "$snapshot_output" "No snapshots found"

touch "$XDG_CACHE_HOME/omarchyvm/omarchy-4.0.2.iso"
touch "$XDG_CACHE_HOME/omarchyvm/snapshots/omarchy-base.qcow2"
clean_output=$("$OMARCHYVM_SCRIPT" --clean)
assert_contains "$clean_output" "ISO preserved"
[[ -f "$XDG_CACHE_HOME/omarchyvm/omarchy-4.0.2.iso" ]] || fail "clean removed the ISO"
[[ ! -e "$XDG_CACHE_HOME/omarchyvm/snapshots/omarchy-base.qcow2" ]] || fail "clean retained the base snapshot"

storage_output=$(printf 'q\n' | "$OMARCHYVM_SCRIPT")
assert_contains "$storage_output" "VM cache:"
assert_contains "$storage_output" "Base snapshot:"

storage_menu_output=$(printf '4\n\nq\n' | "$OMARCHYVM_SCRIPT")
assert_contains "$storage_menu_output" "Storage"
assert_contains "$storage_menu_output" "VM cache:"

resource_defaults_output=$(printf '7\n\n\n\nq\n' | "$OMARCHYVM_SCRIPT")
assert_contains "$resource_defaults_output" "Configure VM resources"
assert_contains "$resource_defaults_output" "Session resources: 8G RAM, 4 CPUs"

resource_values_output=$(printf '7\n16G\n8\n\nq\n' | "$OMARCHYVM_SCRIPT")
assert_contains "$resource_values_output" "Session resources: 16G RAM, 8 CPUs"

resource_invalid_output=$(printf '7\n16G\n0\n\nq\n' | "$OMARCHYVM_SCRIPT")
assert_contains "$resource_invalid_output" "CPU count must be a positive integer"
if grep -Fq "Session resources: 16G RAM, 0 CPUs" <<< "$resource_invalid_output"; then
  fail "invalid CPU count was accepted"
fi

menu_help_output=$(printf '8\nq\nq\n' | "$OMARCHYVM_SCRIPT")
assert_contains "$menu_help_output" "Usage: omarchyvm [OPTIONS]"
assert_contains "$menu_help_output" "OMARCHY_SSH_PORT"
assert_contains "$menu_help_output" "OMARCHY_INSTALL_TIMEOUT"

ssh_menu_output=$(printf '9\n\nq\n' | "$OMARCHYVM_SCRIPT")
assert_contains "$ssh_menu_output" "Connect to VM via SSH"

make_output=$(make -s DRY_RUN=1 dev-omarchy 2>&1)
assert_contains "$make_output" "omarchyvm.sh"
make_persist_output=$(make -s DRY_RUN=1 dev-omarchy-persist 2>&1)
assert_contains "$make_persist_output" "omarchyvm.sh --persist"
make_setup_output=$(make -s DRY_RUN=1 dev-omarchy-setup 2>&1)
assert_contains "$make_setup_output" "omarchyvm.sh --check-deps"
assert_contains "$make_setup_output" "omarchyvm.sh --install-deps"
make_ssh_output=$(make -s DRY_RUN=1 dev-omarchy-ssh 2>&1)
assert_contains "$make_ssh_output" "omarchyvm.sh --ssh"
make_help_output=$(make -s help 2>&1)
assert_contains "$make_help_output" "dev-omarchy"

rm -f "$FAKE_BIN/qemu-system-x86_64" "$FAKE_BIN/qemu-img"
for command_name in env bash realpath dirname clear awk df du find sed basename mktemp mkdir rm grep cat git curl python3 openssl ssh-keygen stat timedatectl flock tr free; do
  ln -sf "$(command -v "$command_name")" "$FAKE_BIN/$command_name"
done
recovery_output=$(PATH="$FAKE_BIN" printf 'q\n' | PATH="$FAKE_BIN" "$OMARCHYVM_SCRIPT")
assert_contains "$recovery_output" "Required dependencies missing"
assert_contains "$recovery_output" "Install dependencies"
if grep -Fq "Choose an action" <<< "$recovery_output"; then
  fail "dependency recovery opened the normal menu"
fi

printf 'PASS: OmarchyVM interaction surfaces\n'
