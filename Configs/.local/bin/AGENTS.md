# Purpose

This directory contains executable scripts and binaries deployed to `${HOME}/.local/bin/` that manage system controls, media downloading, dotfiles synchronization, and Git worktree workflows.

# Ownership

Owned by the RaVN installer pipeline. Restored to user environments via [restore_cfg.psv](../../Scripts/restore_cfg.psv) (flag `O`).

# Local Contracts

- **Execution Permissions**: All files in this directory must have execute permissions (`chmod +x`).
- **Dependency Guard**: Scripts in this directory require specific system packages (e.g., `git`, `gh`, `yt-dlp`, `gum`) which must be verified by `restore_cfg.sh` using package auditing before copying.

# Work Guidance

## Core Utilities

| Binary / Script | Role | Dependencies |
|---|---|---|
| `hyde-shell` | Core HyDE shell and virtual environment manager | `bash` |
| `hydectl` | Core control utility for HyDE settings and operations | - |
| `hyde-ipc` | IPC daemon for HyDE services | - |
| `dotbare-sync` | Synchronization tool to mirror active system configs back to git | `dotbare` |
| `descargar-video` / `descargar-video-x` | Interactive media download wrappers | `yt-dlp`, `gum` |

## Git Worktree Workflows

These tools implement a modern Git workflow based on a bare repository (no working directory) shared by multiple active worktrees (independent branch folders).

- `git-bare-clone`: Clones a remote repository as a bare repo under `~/.local/share/git-bare/` and populates worktrees for all remote branches under `~/Work/` (customizable via `$BARE_HOME` and `$WORKTREES_HOME`).
- `git-create-worktree`: Creates a new worktree for a branch with automatic upstream tracking. Must be run within a clone directory or specify a target repo with `-r/--repo`.
- `git-issue-worktree`: Creates a worktree linked to a GitHub issue using `gh` CLI. Requires the `-r` option to point to an *existing active worktree*, not the bare repo directory.
- `crear-worktrees-simple.sh`: Simplifies bare clone orchestration for basic setups.

# Verification

- Restored binaries can be validated by running them directly from the PATH.
- Verify manifest mapping in `restore_cfg.psv` matches the target binary list.
