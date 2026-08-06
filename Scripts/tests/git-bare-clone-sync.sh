#!/usr/bin/env bash
# Real-git coverage: re-running git-bare-clone creates worktrees for remote
# branches that appeared after the initial clone.

set -euo pipefail

TEST_ROOT=$(mktemp -d)
readonly TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly REPO_ROOT

ORIGIN="$TEST_ROOT/origin.git"
readonly ORIGIN
BARE_HOME="$TEST_ROOT/bare"
readonly BARE_HOME
WORK_HOME="$TEST_ROOT/work"
readonly WORK_HOME
SEED="$TEST_ROOT/seed"
readonly SEED

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

git init --bare "$ORIGIN" > /dev/null
git clone "$ORIGIN" "$SEED" > /dev/null 2>&1
git -C "$SEED" config user.email "test@example.com"
git -C "$SEED" config user.name "Test"
printf 'master\n' > "$SEED/README"
git -C "$SEED" add README
git -C "$SEED" commit -m "init on master" > /dev/null
git -C "$SEED" branch -M master
git -C "$SEED" push -u origin master > /dev/null 2>&1

export BARE_HOME WORKTREES_HOME="$WORK_HOME"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

"$REPO_ROOT/Configs/.local/bin/git-bare-clone" "$ORIGIN" > "$TEST_ROOT/first.out"

# basename(origin.git) with .git stripped → origin
REPO_NAME="origin"
[[ -d $BARE_HOME/$REPO_NAME ]] || fail "bare not created under $BARE_HOME"
[[ -d $WORK_HOME/$REPO_NAME/master ]] || fail "master worktree missing after first clone"
[[ ! -e $WORK_HOME/$REPO_NAME/dev ]] || fail "dev worktree should not exist yet"
[[ ! -e $WORK_HOME/$REPO_NAME/rc ]] || fail "rc worktree should not exist yet"

# Publish new remote branches after the initial bare clone
git -C "$SEED" checkout -b dev > /dev/null 2>&1
printf 'dev\n' > "$SEED/README"
git -C "$SEED" commit -am "dev branch" > /dev/null
git -C "$SEED" push -u origin dev > /dev/null 2>&1

git -C "$SEED" checkout -b rc > /dev/null 2>&1
printf 'rc\n' > "$SEED/README"
git -C "$SEED" commit -am "rc branch" > /dev/null
git -C "$SEED" push -u origin rc > /dev/null 2>&1

"$REPO_ROOT/Configs/.local/bin/git-bare-clone" "$ORIGIN" > "$TEST_ROOT/second.out"

[[ -d $WORK_HOME/$REPO_NAME/master ]] || fail "master worktree lost after sync"
[[ -d $WORK_HOME/$REPO_NAME/dev ]] || fail "dev worktree not created on sync"
[[ -d $WORK_HOME/$REPO_NAME/rc ]] || fail "rc worktree not created on sync"

# Idempotent: third run creates nothing new and keeps existing worktrees
"$REPO_ROOT/Configs/.local/bin/git-bare-clone" "$ORIGIN" > "$TEST_ROOT/third.out"
[[ -d $WORK_HOME/$REPO_NAME/master ]] || fail "master worktree lost after third run"
[[ -d $WORK_HOME/$REPO_NAME/dev ]] || fail "dev worktree lost after third run"
[[ -d $WORK_HOME/$REPO_NAME/rc ]] || fail "rc worktree lost after third run"

grep -Eiq 'No new worktrees needed|Already present' "$TEST_ROOT/third.out" ||
  fail "third run should report no new worktrees needed"

printf 'git-bare-clone sync missing branches: passed\n'
