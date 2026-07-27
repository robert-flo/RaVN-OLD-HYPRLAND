#!/usr/bin/env bash
set -Eeuo pipefail

# Layout reproducible para los repositorios de https://github.com/robert-flo
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BARE_HOME="/z_clones"
WORKTREES_HOME="/z_Transformer" # valor por defecto; cada grupo lo sobreescribe
GIT_BARE_CLONE="$SCRIPT_DIR/git-bare-clone"
GITHUB_OWNER="robert-flo"

clone_repo() {
  local worktrees_dir="$1"
  local repo="$2"
  local bare_dir="$BARE_HOME/$repo"
  local url="https://github.com/$GITHUB_OWNER/$repo.git"

  BARE_HOME="$BARE_HOME" WORKTREES_HOME="$worktrees_dir" \
    "$GIT_BARE_CLONE" -w "$worktrees_dir" "$url"
}

clone_group() {
  local worktrees_dir="$1"
  shift
  local repo

  for repo in "$@"; do
    clone_repo "$worktrees_dir" "$repo"
  done
}

[[ -x "$GIT_BARE_CLONE" ]] || {
  printf 'Error: no se puede ejecutar %s\n' "$GIT_BARE_CLONE" >&2
  exit 1
}

# El orden de estos grupos define la ubicación de los worktrees.
clone_group "/z_Emptys" \
  dotfiles-aur \
  dotfiles---hermes-agent-era \
  my-worktree-helpers---hermes-agent-era \
  RaVN-VM---hermes-agent-era

clone_group "/z_Packages" \
  git-setup-arch \
  shared_dir-AUR

clone_group "/z_RaVN-DOT" \
  HyDE \
  Ivar \
  RaVN \
  Rollo \
  Valhalla

clone_group "$WORKTREES_HOME" \
  bare-minimun \
  final.sh \
  herdr-terminal-file-manager \
  neovim-robert-flo \
  ravn-installer-rewrite \
  searxng

clone_group "/z_Shipped" \
  dotfiles \
  git-setup \
  shared_dir

printf '\nEstructura solicitada procesada correctamente.\n'
