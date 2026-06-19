#!/usr/bin/env bash

GIT_ISSUE_WORKTREE="/home/hydenix/Dropbox/ludus/Dotfiles2/dev/bin/git-issue-worktree"
REPO_DIR="$HOME/Work/ravn"

slugs=(
  base-snapshot
  neovim-khanelivim
  nixpkgs-unstable-llm-agents-overlay
  ai-tooling
  tmux-workmux
  git-auth-gpg
  modular-makefile
  worktree-scripts
)

for i in {1..8}; do
  num=$(printf "%02d" "$i")
  slug="${slugs[$((i-1))]}"
  echo "Creando worktree y rama: issue-$num-$slug"
  "$GIT_ISSUE_WORKTREE" -r "$REPO_DIR" -B dev "$num" "$slug"
done