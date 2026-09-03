#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OMARCHYVM_SCRIPT="$SCRIPT_DIR/omarchyvm.sh"
TEST_TMP_BASE="${OMARCHYVM_TEST_TMPDIR:-${XDG_CACHE_HOME:-$HOME/.cache}/omarchyvm-tests}"
mkdir -p "$TEST_TMP_BASE"
FIXTURE_DIR="$(mktemp -d "$TEST_TMP_BASE/omarchyvm-install-test.XXXXXX")"
FAKE_BIN="$FIXTURE_DIR/bin"
FAKE_HOME="$FIXTURE_DIR/home"

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

mkdir -p "$FAKE_BIN" "$FAKE_HOME/.ssh" "$FIXTURE_DIR/cache/omarchyvm"
printf 'ssh-ed25519 AAAAC3Nzofixturekeyfortest omarchyvm-test@fixture\n' > "$FAKE_HOME/.ssh/id_ed25519.pub"

# Sparse 2GB ISO passes the size sanity check without costing disk
truncate -s 2G "$FIXTURE_DIR/fake-omarchy.iso"

cat > "$FAKE_BIN/genisoimage" << 'FAKE_GENISOIMAGE'
#!/usr/bin/env bash
output_path=""
previous=""
for arg in "$@"; do
  if [[ $previous == "-output" ]]; then
    output_path="$arg"
    break
  fi
  previous="$arg"
done
[[ -n $output_path ]] || exit 2
: > "$output_path"
FAKE_GENISOIMAGE
chmod +x "$FAKE_BIN/genisoimage"

for command_name in curl openssl python3 ssh-keygen qemu-img; do
  ln -sf "$(command -v "$command_name")" "$FAKE_BIN/$command_name"
done

# SSH never answers: the install can never complete
cat > "$FAKE_BIN/ssh" << 'FAKE_SSH'
#!/usr/bin/env bash
exit 255
FAKE_SSH
chmod +x "$FAKE_BIN/ssh"

export PATH="$FAKE_BIN:/usr/bin:/bin"
export HOME="$FAKE_HOME"
export XDG_CACHE_HOME="$FIXTURE_DIR/cache"

# Case 1: QEMU dies immediately with a host-forwarding error
cat > "$FAKE_BIN/qemu-system-x86_64" << 'FAKE_QEMU'
#!/usr/bin/env bash
echo "qemu-system-x86_64: -netdev user,id=net0,hostfwd=tcp::2223-:22: Could not set up host forwarding rule" >&2
exit 1
FAKE_QEMU
chmod +x "$FAKE_BIN/qemu-system-x86_64"

set +e
hostfwd_output=$(OMARCHY_ISO="$FIXTURE_DIR/fake-omarchy.iso" "$OMARCHYVM_SCRIPT" --rebuild 2>&1)
hostfwd_status=$?
set -e

[[ $hostfwd_status -ne 0 ]] || fail "host-forwarding failure returned success"
assert_contains "$hostfwd_output" "host forwarding for port"
[[ ! -e $XDG_CACHE_HOME/omarchyvm/snapshots/omarchy-base.qcow2 ]] || fail "failed install cached a base snapshot"
[[ ! -e $XDG_CACHE_HOME/omarchyvm/install.building.qcow2 ]] || fail "failed install retained its building disk"

# Case 2: QEMU stays up but SSH never answers -> timeout
cat > "$FAKE_BIN/qemu-system-x86_64" << 'FAKE_QEMU'
#!/usr/bin/env bash
sleep 120
FAKE_QEMU
chmod +x "$FAKE_BIN/qemu-system-x86_64"

set +e
timeout_output=$(OMARCHY_ISO="$FIXTURE_DIR/fake-omarchy.iso" OMARCHY_INSTALL_TIMEOUT=0 "$OMARCHYVM_SCRIPT" --rebuild 2>&1)
timeout_status=$?
set -e

[[ $timeout_status -ne 0 ]] || fail "SSH timeout returned success"
assert_contains "$timeout_output" "Timed out"
[[ ! -e $XDG_CACHE_HOME/omarchyvm/snapshots/omarchy-base.qcow2 ]] || fail "timed-out install cached a base snapshot"
[[ ! -e $XDG_CACHE_HOME/omarchyvm/install.building.qcow2 ]] || fail "timed-out install retained its building disk"

printf 'PASS: OmarchyVM install failure modes\n'
