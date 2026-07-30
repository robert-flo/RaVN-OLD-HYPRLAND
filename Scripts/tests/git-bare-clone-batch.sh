#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT=$(mktemp -d)
readonly TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly REPO_ROOT
FAKE_BIN="$TEST_ROOT/bin"
readonly FAKE_BIN
FAKE_GIT_LOG="$TEST_ROOT/git.log"
readonly FAKE_GIT_LOG
BARE_HOME="$TEST_ROOT/bare"
readonly BARE_HOME
GROUP_ONE="$TEST_ROOT/group-one"
readonly GROUP_ONE
GROUP_TWO="$TEST_ROOT/group-two"
readonly GROUP_TWO

mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/git" << 'EOF'
#!/usr/bin/env bash

set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_GIT_LOG"

if [[ -n ${FAKE_GIT_FAIL_MATCH:-} && $* == *$FAKE_GIT_FAIL_MATCH* ]]; then
  exit 42
fi

case "${1:-}" in
clone)
  if [[ ${FAKE_GIT_FAIL_URL:-} == $3 ]]; then
    exit 42
  fi
  mkdir -p "$4"
  ;;
--git-dir=*)
  printf '%s\n' 'refs/remotes/origin/main'
  ;;
worktree)
  mkdir -p "$4"
  ;;
*)
  ;;
esac
EOF
chmod +x "$FAKE_BIN/git"

run_clone() {
  env \
    PATH="$FAKE_BIN:$PATH" \
    HOME="$TEST_ROOT/home" \
    BARE_HOME="$BARE_HOME" \
    FAKE_GIT_LOG="$FAKE_GIT_LOG" \
    "$REPO_ROOT/Configs/.local/bin/git-bare-clone" \
    "$@"
}

run_clone \
  --group "$GROUP_ONE" robert-flo/alpha git@github.com:example/beta.git \
  --group "$GROUP_TWO" https://github.com/example/gamma.git \
  > /dev/null

test -d "$BARE_HOME/alpha"
test -d "$BARE_HOME/beta"
test -d "$BARE_HOME/gamma"
test -d "$GROUP_ONE/alpha/main"
test -d "$GROUP_ONE/beta/main"
test -d "$GROUP_TWO/gamma/main"
grep -q 'clone --bare git@github.com:robert-flo/alpha.git' "$FAKE_GIT_LOG"

mapfile -t clone_lines < <(grep '^clone --bare ' "$FAKE_GIT_LOG")
[[ ${clone_lines[0]} == 'clone --bare git@github.com:robert-flo/alpha.git '* ]]
[[ ${clone_lines[1]} == 'clone --bare git@github.com:example/beta.git '* ]]
[[ ${clone_lines[2]} == 'clone --bare https://github.com/example/gamma.git '* ]]

SINGLE_GROUP="$TEST_ROOT/single"
readonly SINGLE_GROUP
run_clone -w "$SINGLE_GROUP" robert-flo/single > /dev/null
test -d "$BARE_HOME/single"
test -d "$SINGLE_GROUP/single/main"

mkdir -p "$BARE_HOME/existing"
run_clone --group "$GROUP_ONE" robert-flo/existing robert-flo/after-existing > /dev/null
test -d "$BARE_HOME/after-existing"
if grep -q 'clone --bare git@github.com:robert-flo/existing.git' "$FAKE_GIT_LOG"; then
  printf 'expected existing bare repository to be skipped\n' >&2
  exit 1
fi
grep -q 'clone --bare git@github.com:robert-flo/after-existing.git' "$FAKE_GIT_LOG"

mkdir -p "$GROUP_ONE/worktrees-existing"
run_clone --group "$GROUP_ONE" robert-flo/worktrees-existing robert-flo/after-worktrees > /dev/null
test ! -e "$BARE_HOME/worktrees-existing"
test -d "$BARE_HOME/after-worktrees"
if grep -q 'clone --bare git@github.com:robert-flo/worktrees-existing.git' "$FAKE_GIT_LOG"; then
  printf 'expected existing worktrees directory to be skipped\n' >&2
  exit 1
fi

assert_fail_fast() {
  local failure_match=$1
  local failing_repository=$2
  local later_repository=$3

  if env \
    PATH="$FAKE_BIN:$PATH" \
    HOME="$TEST_ROOT/home" \
    BARE_HOME="$BARE_HOME" \
    FAKE_GIT_LOG="$FAKE_GIT_LOG" \
    FAKE_GIT_FAIL_MATCH="$failure_match" \
    "$REPO_ROOT/Configs/.local/bin/git-bare-clone" \
    --group "$GROUP_TWO" "robert-flo/$failing_repository" "robert-flo/$later_repository" \
    > /dev/null 2>&1; then
    printf 'expected batch failure for %s\n' "$failure_match" >&2
    exit 1
  fi

  test ! -e "$BARE_HOME/$later_repository"
}

assert_fail_fast 'clone --bare git@github.com:robert-flo/failing-clone.git' 'failing-clone' 'after-clone-failure'
assert_fail_fast 'fetch origin' 'failing-fetch' 'after-fetch-failure'
assert_fail_fast 'worktree add main main' 'failing-worktree' 'after-worktree-failure'
assert_fail_fast '--set-upstream-to=origin/main main' 'failing-tracking' 'after-tracking-failure'

if run_clone -w "$SINGLE_GROUP" --group "$GROUP_TWO" invalid > /dev/null 2>&1; then
  printf 'expected incompatible -w and --group options to fail\n' >&2
  exit 1
fi

printf 'git-bare-clone batch mode: passed\n'
