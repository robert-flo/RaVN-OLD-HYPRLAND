#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OMARCHYVM_SCRIPT="$SCRIPT_DIR/omarchyvm.sh"
TEST_TMP_BASE="${OMARCHYVM_TEST_TMPDIR:-${XDG_CACHE_HOME:-$HOME/.cache}/omarchyvm-tests}"
mkdir -p "$TEST_TMP_BASE"
FIXTURE_DIR="$(mktemp -d "$TEST_TMP_BASE/omarchyvm-cidata-test.XXXXXX")"
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

mkdir -p "$FAKE_BIN" "$FAKE_HOME/.ssh"
# Host key the builder must pick up into cidata authorized_keys
printf 'ssh-ed25519 AAAAC3Nzofixturekeyfortest omarchyvm-test@fixture\n' > "$FAKE_HOME/.ssh/id_ed25519.pub"

# Fake cidata ISO builder: touch the output instead of mastering 7GB
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

export PATH="$FAKE_BIN:$PATH"
export HOME="$FAKE_HOME"
export XDG_CACHE_HOME="$FIXTURE_DIR/cache"

build_output=$(OMARCHY_USER=arch OMARCHY_HOSTNAME=omarchy-vm OMARCHY_TIMEZONE=UTC OMARCHY_KEYMAP=us \
  "$OMARCHYVM_SCRIPT" --build-cidata-only 2>&1)
assert_contains "$build_output" "cidata ready"

cidata_dir="$XDG_CACHE_HOME/omarchyvm/cidata"
[[ -f $XDG_CACHE_HOME/omarchyvm/cidata.iso ]] || fail "cidata ISO was not created"

# Both JSON files must parse
python3 -c "import json; json.load(open('$cidata_dir/user_credentials.json')); json.load(open('$cidata_dir/user_configuration.json'))" ||
     fail "cidata JSON does not parse"

credentials=$(cat "$cidata_dir/user_credentials.json")
assert_contains "$credentials" '"username": "arch"'
# openssl $6$ crypt hash (never plaintext)
# shellcheck disable=SC2016 # grep pattern is intentionally literal single-quoted
grep -Eq '"enc_password": "\$6\$[^"]+"' "$cidata_dir/user_credentials.json" ||
     fail "password was not hashed with openssl passwd -6"
if grep -Fq '"enc_password": "arch"' "$cidata_dir/user_credentials.json"; then
  fail "plaintext password leaked into user_credentials.json"
fi

configuration=$(cat "$cidata_dir/user_configuration.json")
assert_contains "$configuration" '"hostname": "omarchy-vm"'
assert_contains "$configuration" '"device": "/dev/vda"'
assert_contains "$configuration" '"kb_layout": "us"'
assert_contains "$configuration" '"timezone": "UTC"'
assert_contains "$configuration" '"mode": "full_disk"'
if grep -Fq "disk_encryption" "$cidata_dir/user_configuration.json"; then
  fail "disk_encryption block must be absent (installs are unencrypted by design)"
fi
assert_contains "$(cat "$cidata_dir/user_encrypt_installation.txt")" "false"

# Host key must land in cidata authorized_keys (this is what enables sshd)
assert_contains "$(cat "$cidata_dir/authorized_keys")" "AAAAC3Nzofixturekeyfortest"
# Generated guest key must be there too
[[ -f $XDG_CACHE_HOME/omarchyvm/id_ed25519.pub ]] || fail "guest SSH key was not generated"
assert_contains "$(cat "$cidata_dir/authorized_keys")" "$(cut -d' ' -f2 "$XDG_CACHE_HOME/omarchyvm/id_ed25519.pub")"

# Optional identity files are omitted when env is empty...
[[ ! -e $cidata_dir/user_full_name.txt ]] || fail "user_full_name.txt should be absent without OMARCHY_FULL_NAME"
[[ ! -e $cidata_dir/user_email_address.txt ]] || fail "user_email_address.txt should be absent without OMARCHY_EMAIL"

# ...and present when set
OMARCHY_FULL_NAME="Test User" OMARCHY_EMAIL="test@example.com" \
  "$OMARCHYVM_SCRIPT" --build-cidata-only > /dev/null 2>&1
assert_contains "$(cat "$cidata_dir/user_full_name.txt")" "Test User"
assert_contains "$(cat "$cidata_dir/user_email_address.txt")" "test@example.com"

# Invalid --iso values are rejected
if "$OMARCHYVM_SCRIPT" --iso 'not a version!!' --build-cidata-only > /dev/null 2>&1; then
  fail "invalid --iso value was accepted"
fi

printf 'PASS: OmarchyVM cidata generation\n'
