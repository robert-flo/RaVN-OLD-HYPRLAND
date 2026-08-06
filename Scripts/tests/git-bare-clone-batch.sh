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

# Strip leading -C <dir> so worktree/branch ops see the real subcommand.
cwd=""
if [[ ${1:-} == -C ]]; then
  cwd="${2:-}"
  shift 2
fi

case "${1:-}" in
clone)
  if [[ ${FAKE_GIT_FAIL_URL:-} == $3 ]]; then
    exit 42
  fi
  mkdir -p "$4"
  ;;
--git-dir=*)
  # Emulate bare-repo git invocations: for-each-ref / show-ref / fetch / config
  if [[ $* == *'for-each-ref'* ]]; then
    printf '%s\n' 'refs/remotes/origin/main'
  elif [[ $* == *'show-ref'* ]]; then
    # Local heads exist after a bare clone in the happy path
    exit 0
  fi
  ;;
worktree)
  # worktree add <path> <commit>  OR  worktree add -b <branch> <path> <start>
  path=""
  if [[ ${2:-} == add && ${3:-} == -b ]]; then
    path="${5:-.}"
  elif [[ ${2:-} == add ]]; then
    path="${3:-.}"
  fi
  if [[ -n $path ]]; then
    if [[ -n $cwd && $path != /* ]]; then
      mkdir -p "$cwd/$path"
    else
      mkdir -p "$path"
    fi
  fi
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
: > "$FAKE_GIT_LOG"
run_clone --group "$GROUP_ONE" robert-flo/existing robert-flo/after-existing > /dev/null
test -d "$BARE_HOME/after-existing"
if grep -q 'clone --bare git@github.com:robert-flo/existing.git' "$FAKE_GIT_LOG"; then
  printf 'expected existing bare repository not to be re-cloned\n' >&2
  exit 1
fi
grep -q 'fetch origin' "$FAKE_GIT_LOG" || {
  printf 'expected existing bare repository to be fetched for sync\n' >&2
  exit 1
}
test -d "$GROUP_ONE/existing/main"
grep -q 'clone --bare git@github.com:robert-flo/after-existing.git' "$FAKE_GIT_LOG"

mkdir -p "$GROUP_ONE/worktrees-existing"
: > "$FAKE_GIT_LOG"
run_clone --group "$GROUP_ONE" robert-flo/worktrees-existing robert-flo/after-worktrees > /dev/null
test ! -e "$BARE_HOME/worktrees-existing"
test -d "$BARE_HOME/after-worktrees"
if grep -q 'clone --bare git@github.com:robert-flo/worktrees-existing.git' "$FAKE_GIT_LOG"; then
  printf 'expected worktrees-without-bare to be skipped (no bare clone)\n' >&2
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
