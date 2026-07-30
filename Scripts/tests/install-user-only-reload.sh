#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT=$(mktemp -d)
readonly TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
readonly REPO_ROOT
FIXTURE_ROOT="$TEST_ROOT/fixture"
readonly FIXTURE_ROOT
FIXTURE_HOME="$TEST_ROOT/home"
readonly FIXTURE_HOME
FAKE_BIN="$TEST_ROOT/bin"
readonly FAKE_BIN
HYDE_LOG="$TEST_ROOT/hyde-shell.log"
readonly HYDE_LOG
INSTALL_LOG="$TEST_ROOT/install.log"
readonly INSTALL_LOG

mkdir -p "$FIXTURE_ROOT" "$FAKE_BIN"
cp -a "$REPO_ROOT/Scripts" "$FIXTURE_ROOT/Scripts"
cp -a "$REPO_ROOT/Configs" "$FIXTURE_ROOT/Configs"

cat > "$FAKE_BIN/hyde-shell" << 'EOF'
#!/usr/bin/env bash

set -euo pipefail
printf '%s\n' "$*" >> "$HYDE_LOG"
EOF
chmod +x "$FAKE_BIN/hyde-shell"

env \
  HOME="$FIXTURE_HOME" \
  PATH="$FAKE_BIN:/usr/bin:/bin" \
  HYDE_LOG="$HYDE_LOG" \
  bash "$FIXTURE_ROOT/Scripts/install.sh" -o \
  > "$INSTALL_LOG" 2>&1

grep -qx 'reload' "$HYDE_LOG"

env \
  HOME="$FIXTURE_HOME" \
  PATH="$FAKE_BIN:/usr/bin:/bin" \
  HYDE_LOG="$HYDE_LOG" \
  bash "$FIXTURE_ROOT/Scripts/install.sh" -ot \
  > "$TEST_ROOT/dry-run.log" 2>&1

grep -q 'Would run hyde-shell reload' "$TEST_ROOT/dry-run.log"
hyde_call_count=$(wc -l < "$HYDE_LOG")
((hyde_call_count == 1))

chmod -x "$FIXTURE_ROOT/Configs/.local/bin/hyde-shell"
env \
  HOME="$TEST_ROOT/missing-home" \
  PATH="/usr/bin:/bin" \
  bash "$FIXTURE_ROOT/Scripts/install.sh" -o \
  > "$TEST_ROOT/missing.log" 2>&1

grep -q 'hyde-shell was not found; continuing' "$TEST_ROOT/missing.log"

printf 'install user-only reload: passed\n'
