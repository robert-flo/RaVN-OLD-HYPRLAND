# Style
 
- Two spaces for indentation, no tabs
- Use bash 5 conditionals: use `[[ ]]` for string/file tests and `(( ))` for numeric tests
- In `[[ ]]`, don't quote variables, but do quote string literals when comparing values (e.g., `[[ $branch == "dev" ]]`)
- Prefer `(( ))` over numeric operators inside `[[ ]]` (e.g., `(( count < 50 ))`, not `[[ $count -lt 50 ]]`)
- For strings/paths with spaces, quote them instead of escaping spaces with `\ ` (e.g., `"$APP_DIR/Disk Usage.desktop"`, not `$APP_DIR/Disk\ Usage.desktop`)
- Shebangs:
  - Standard bash scripts must use `#!/usr/bin/env bash` consistently (never `#!/usr/bin/env sh`).
  - Migration scripts executed via `sh` by the installer should use `#!/usr/bin/env sh` (or be POSIX compliant).
- For scripts with strict error handling (`set -e` / `pipefail`), protect pipelines or command substitutions in variable assignments that might return a non-zero exit status (e.g., `grep` queries returning empty results) by appending `|| true` or `|| echo ""` to prevent premature shell termination.

## ShellCheck & Scripting Safety

- **Zero-Warning Policy**: All new or modified shell scripts (excluding those explicitly in the ignore list) must pass `shellcheck` with zero warnings or errors before committing.
- **Direct Command Checks (SC2181/SC2319)**: Avoid checking `$?` indirectly (e.g., `if [ $? -eq 0 ]`). Check commands directly (e.g., `if my_command; then`) or use success tracking variables (`success=0; my_command || success=1; if (( success == 0 )); then`).
- **Quote Variable Expansions (SC2086)**: Always double-quote variable expansions when they are used as command arguments to prevent word splitting (e.g., `"$var"`), except inside `[[ ]]` where expansion is safe.
- **Built-in Parameter Expansion (SC2001)**: Avoid calling external tools like `sed` or `awk` for simple string replacements on single variables; prefer built-in Bash parameter expansion (e.g., `${var//search/replace}`).
- **Localizing False Positives**: Do not ignore entire files for linter warnings. Use inline `# shellcheck disable=SCxxxx` directives only on the specific lines where a false positive occurs (e.g., AWK variables inside single quotes).


# Repository Structure & Purpose

- `Configs/` - Source of truth for clean configuration files and templates that populate the user's `$HOME` (e.g., `.config/`, `.bashrc`).
- `Scripts/` - Automation scripts for installation, updating, and restoring configuration states:
  - `global_fn.sh` - Core library of shared variables, visual logging settings, and professional installer utility functions. Sourced in scripts via `source "${scrDir}/global_fn.sh"`.
  - `install.sh` - Main orchestration entry point (handles packages, services, config restoration, migrations, and final system post-install tweaks).
  - `restore_cfg.sh` - Restores configuration directories and files using tracking flags defined in `restore_cfg.psv`.
  - `dotbare_init.sh` - Instantiates the dotbare bare git repository in `$HOME/.cfg` to manage local dotfiles.
  - `migrations/` - Directory containing version-specific migration scripts (e.g., `v26.4.3.sh`) run automatically by the installer.
- `Source/arcs/` - Compressed tar archives (`.tar.gz`, `.vsix`) containing fonts, cursors, SDDM themes, GTK assets, and Firefox/Code configuration baselines.

# Configuration Tracking & Sourcing of Truth (`restore_cfg.psv` and `dotbare`)

RaVN relies on `dotbare` for tracking active dotfiles in `$HOME`, with clean versions mirrored in the `Configs/` subdirectory of the repository.

1. **Adding files to tracking:** To add a configuration target to the restore system, insert a row in [restore_cfg.psv](Scripts/restore_cfg.psv) using the format:
   ```text
   Flag|${HOME}/path/to/directory|file_name|dependency
   ```
   **Flags:**
   - `P` (Populate/Preserve) - Copy target from `Configs/` to destination ONLY if it does not exist. Prevents overwriting local user changes.
   - `S` (Sync) - Copy target from `Configs/` and overwrite local file.
   - `O` (Overwrite) - Force overwrite. Overwrites everything recursively if the target is a directory.
   - `B` (Backup) - Backs up the target before modifying.
   - `I` (Install/Import) - Imports or configures associated packages.

2. **Committing active changes:** Use `dotbare` commands (e.g., `dotbare fstat`, `dotbare commit`, `dotbare push`) to commit system-level configurations to the playthrough bare repo.
3. **Syncing back to the repository:** Use `dotbare-sync` (or [sync_back.sh](Scripts/sync_back.sh)) to copy modifications from active `$HOME` back to `RaVN/Configs/` templates. Verify additions with `git diff` inside the RaVN repo.

# Helper Functions

Always prioritize the helper functions imported from [global_fn.sh](Scripts/global_fn.sh) over raw shell commands:

- **Logging:** Use `info`, `success`, `warn_msg`, `error_msg`, `step`, and `print_log` for unified, semantic output with visual indicators.
- **Process Feedback:** Wrap long actions in `spin <pid> [msg]` or run them directly using `run_with_status "message" <command>` to show an interactive Braille spinner.
- **Package Auditing:** Use `pkg_installed <package>` to check package status.
- **Git & Downloads:** Use `clone_or_update_repo <name> <repo> <dest> [branch] [ssh]` and `download_file <url> [dest]` to perform downloads and cloning with built-in retry mechanisms and user feedback.
- **Robustness:** Use `retry <tries> <command>` for actions prone to transient failures.

# Migrations

- Located in `Scripts/migrations/` and named after version tags (e.g., `v25.9.1.sh`).
- Migrations are run via `sh` inside `install.sh`. Ensure migration logic is POSIX compliant or specifically executes safely.
- Output brief details to stdout explaining what the migration is adjusting so the user is informed during updates.

# Visual Changes

- When making visual, style, or desktop configuration changes (such as modifications to Waybar or layouts), always verify the layout by taking and analyzing a screenshot.

# Branching & Release Policy

Refer to [RELEASE_POLICY.md](RELEASE_POLICY.md) for details. **The following rules are non-negotiable and must be strictly followed by all agents and developers:**
- **`dev`**: The active branch for all features and PRs. **Under no circumstances should `dev` receive direct commits.** It must always be fed exclusively by auxiliary topic/feature branches created in isolated worktrees (e.g. via `git-create-worktree`) and merged in.
- **`rc`** (Release Candidate): Receives a merge from `dev` on the penúltimo Friday of the month. Frozen for regression testing and bug fixes only. **`rc` only receives merges from `dev`.**
- **`master`**: Receives a merge from `rc` on the last Friday of the month for the official monthly version release (tagged as `YY.M`). **`master` only receives merges from `rc`.**


# Git Worktree Workflow (Development)

To protect the user's active system configurations from accidental resets or uncommitted code loss during development, and to maintain task isolation:

- **Isolated Development in `~/Work`**: All active development work must be carried out inside worktrees under `~/Work/<repo>/` (which are created from the bare repository at `~/.local/share/git-bare/<repo>`).
- **No Direct Modification in Live Clone**: Do not perform development or commit changes directly inside the live configuration clone located at `~/.local/share/ravn/` (except when updating tracking config files or executing system-wide scripts).
- **Automation Utilities**: Always use the following tools (restored under `~/.local/bin/`):
  - `git-create-worktree` for general feature/chore branches.
  - `git-issue-worktree` for GitHub-tracked issues.
- **Workflow Benefit**: Developing under `~/Work` isolates development changes from host configuration restoration processes. This eliminates the need to manually disable ravn tracking (e.g. setting `ravn=false` in `Scripts/ravn/config/packages.conf`) to protect local changes from being overwritten during installer or `restore_cfg.sh` runs.


# DOX framework

- DOX is highly performant AGENTS.md hierarchy installed here
- Agent must follow DOX instructions across any edits

## Core Contract

- AGENTS.md files are binding work contracts for their subtrees
- Work products, source materials, instructions, records, assets, and durable docs must stay understandable from the nearest applicable AGENTS.md plus every parent AGENTS.md above it

## Read Before Editing

1. Read the root AGENTS.md
2. Identify every file or folder you expect to touch
3. Walk from the repository root to each target path
4. Read every AGENTS.md found along each route
5. If a parent AGENTS.md lists a child AGENTS.md whose scope contains the path, read that child and continue from there
6. Use the nearest AGENTS.md as the local contract and parent docs for repo-wide rules
7. If docs conflict, the closer doc controls local work details, but no child doc may weaken DOX

Do not rely on memory. Re-read the applicable DOX chain in the current session before editing.

## Update After Editing

Every meaningful change requires a DOX pass before the task is done.

Update the closest owning AGENTS.md when a change affects:

- purpose, scope, ownership, or responsibilities
- durable structure, contracts, workflows, or operating rules
- required inputs, outputs, permissions, constraints, side effects, or artifacts
- user preferences about behavior, communication, process, organization, or quality
- AGENTS.md creation, deletion, move, rename, or index contents

Update parent docs when parent-level structure, ownership, workflow, or child index changes. Update child docs when parent changes alter local rules. Remove stale or contradictory text immediately. Small edits that do not change behavior or contracts may leave docs unchanged, but the DOX pass still must happen.

## Hierarchy

- Root AGENTS.md is the DOX rail: project-wide instructions, global preferences, durable workflow rules, and the top-level Child DOX Index
- Child AGENTS.md files own domain-specific instructions and their own Child DOX Index
- Each parent explains what its direct children cover and what stays owned by the parent
- The closer a doc is to the work, the more specific and practical it must be

## Child Doc Shape

- Create a child AGENTS.md when a folder becomes a durable boundary with its own purpose, rules, responsibilities, workflow, materials, or quality standards
- Work Guidance must reflect the current standards of the project or user instructions; if there are no specific standards or instructions yet, leave it empty
- Verification must reflect an existing check; if no verification framework exists yet, leave it empty and update it when one exists

Default section order:
- Purpose
- Ownership
- Local Contracts
- Work Guidance
- Verification
- Child DOX Index

## Style

- Keep docs concise, current, and operational
- Document stable contracts, not diary entries
- Put broad rules in parent docs and concrete details in child docs
- Prefer direct bullets with explicit names
- Do not duplicate rules across many files unless each scope needs a local version
- Delete stale notes instead of explaining history
- Trim obvious statements, repeated rules, misplaced detail, and warnings for risks that no longer exist

## Closeout

1. Re-check changed paths against the DOX chain
2. Update nearest owning docs and any affected parents or children
3. Refresh every affected Child DOX Index
4. Remove stale or contradictory text
5. Run existing verification when relevant
6. Report any docs intentionally left unchanged and why

## User Preferences

- **Live Synchronization**: Whenever making changes to a file inside the `Configs/` repository directory, the changes must immediately be synchronized to its corresponding live path in `$HOME` (e.g., by executing `restore_cfg.sh` or copying manually).

## Child DOX Index

- [Configs/AGENTS.md](Configs/AGENTS.md) - Configuration templates and restore definitions.
- [Scripts/AGENTS.md](Scripts/AGENTS.md) - Automation, package install, and update scripts.
  - [Scripts/ravnvm/AGENTS.md](Scripts/ravnvm/AGENTS.md) - NixOS virtualization environment settings.
- [Source/AGENTS.md](Source/AGENTS.md) - Binary archives, themes, fonts, and graphical assets.
