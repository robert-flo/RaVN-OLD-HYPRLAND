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
| `play-yt` | Stream YouTube videos in MPV with forced H.264/VA-API | `mpv`, `yt-dlp` |

---

## Git Worktree Workflows

These tools implement a modern Git workflow based on a **bare repository** (no working directory, holding only the `.git` metadata) shared by multiple active **worktrees** (independent folders for each branch), allowing you to work on multiple branches simultaneously without stash or checkout.

```
~/.local/share/git-bare/<repo>/ (Bare repository containing refs, objects, config)
  └── ~/Work/<repo>/
      ├── main/           ← Worktree 1
      ├── develop/        ← Worktree 2
      └── feature-xyz/    ← Worktree 3
```

### 1. `git-bare-clone`
Clones a remote repository as a bare repo and instantiates worktrees for all remote branches.

* **Default Paths**:
* Bare repo: `~/.local/share/git-bare/<repo>` (Override with `$BARE_HOME`)
* Worktrees: `~/Work/<repo>` (Override with `$WORKTREES_HOME`)
* **Syntax**:
  ```bash
  git-bare-clone [-h] [-v] [-w <path>] <repository>
  git-bare-clone [--verbose] --group <worktrees-path> <repository>... [--group <worktrees-path> <repository>...]
  ```
* **Options**:
  * `-h, --help`: Show help.
  * `-v, --verbose`: Enable debug verbosity.
  * `-w, --worktrees-dir`: Custom worktrees base directory.
  * `--group <worktrees-path> <repository>...`: Batch clone one or more repositories into the given worktrees path. Repeat `--group` to use several destinations in one invocation.
* **Repository formats**: Accepts SSH and HTTPS Git URLs, local paths, and GitHub shorthand (`owner/repository`, expanded to `git@github.com:owner/repository.git`).
* **Batch / re-run contract**: An existing bare is **not** re-cloned; the script fetches `origin` and creates worktrees only for remote branches that still lack a local directory. A worktrees directory without a bare is skipped. A real clone/sync failure stops the batch immediately and returns Git's failure status.
* **Sync example**: after `master` was the only remote branch at first clone, re-run `git-bare-clone owner/repo` once `dev`/`rc` exist on the remote to materialize their worktrees.
* **Workflow Example**:
  ```bash
  git-bare-clone https://github.com/user/myrepo.git
  # Results in:
  # ~/.local/share/git-bare/myrepo/ (Bare repo)
  # ~/Work/myrepo/main/ (Worktree 1)
  # ~/Work/myrepo/develop/ (Worktree 2)
  ```
* **Batch Example**:
  ```bash
  git-bare-clone \
    --group /projects/platform acme/api acme/web \
    --group ~/Work example/tooling example/docs
  ```
  Each repository keeps its bare clone under `~/.local/share/git-bare/`; only its worktrees go to the group path.

### 2. `git-create-worktree`
Creates a new worktree linked to a branch with automatic upstream tracking.

* **Syntax**: `git-create-worktree [-h] [-v] [-r <repo>] [-b <branch>] [-B <base>] [-p <prefix>] [-N] <path>`
* **Options**:
  * `-r, --repo`: Route of the repository (or execute inside it). Default: current directory.
  * `-b, --branch`: Name of branch to create/use. Default: `<prefix><path>`.
  * `-B, --base`: Base branch for new worktree. Default: `origin/main` (or `origin/develop`).
  * `-p, --prefix`: Prefix for the branch name (e.g. `team/`). Default: `git config github.user`.
  * `-N, --no-create-upstream`: Skip upstream creation and push.
* **Workflow Example (from anywhere)**:
  ```bash
  git-create-worktree -r ~/Work/myrepo -b "feature/login" "login-page"
  # Creates worktree under ~/Work/myrepo/login-page linked to branch feature/login
  ```

### 3. `git-issue-worktree`
Creates a worktree linked to a GitHub issue using `gh` CLI and parses context metadata.

* **Syntax**: `git-issue-worktree [-h] [-v] [-r <repo>] [-B <base>] [-p <prefix>] <issue_number> <slug>`
* **Options**: Matches `git-create-worktree`.
* **CRITICAL WARNING**: Unlike `git-create-worktree`, the `-r` option **must point to an existing active worktree** (e.g. `~/Work/myrepo/main`), **NOT** to the bare repository directory (`~/.local/share/git-bare/myrepo`).
* **Workflow Example**:
  ```bash
  git-issue-worktree -r ~/Work/myrepo/main -B develop 42 login-fix
  # Fetches issue #42 details from GitHub
  # Creates worktree under ~/Work/myrepo/42-login-fix linked to branch <user>/issue/42-login-fix
  ```

---

### 4. `meld-comparisons`
Interactive menu that opens Meld for common multi-repo directory comparisons
(Valhalla / RaVN / Rollo / HyDE under `~/Work`).

* **Syntax**: `meld-comparisons`
* **Dependencies**: `meld`, `global_fn.sh` (same directory when restored)

### 5. `ravn-dot`
Interactive TUI (`fzf`) for reconciling drift between `Configs/` and `$HOME`
using `Scripts/restore_cfg.psv`.

---

## Decision Matrix: When to use which?

```
Do you have a GitHub issue for the task?
    ├─ YES → Do you want automatic issue context & PR tracking?
    │          ├─ YES → git-issue-worktree ✨
    │          └─ NO  → git-create-worktree
    └─ NO  → Is it ad-hoc work/experimental?
               └─ YES → git-create-worktree
```

| Criterion | `git-create-worktree` | `git-issue-worktree` |
| :--- | :--- | :--- |
| **Use case** | Ad-hoc features, chores, refactoring | Linked task from GitHub issue tracker |
| **Requires Issue** | No | Yes (number) |
| **Requires `gh` CLI** | No | Yes (authenticated) |
| **Branch naming** | Custom or defaults to path | Structured (`<user>/issue/<number>-<slug>`) |
| **Context display** | Directory path | Issue status, Title, PR guidelines |

---

## Verification

- Restored binaries can be validated by running them directly from the PATH.
- Verify manifest mapping in `restore_cfg.psv` matches the target binary list.
