# AGENTS.md — RaVN

Guidance for any agent (or developer) working in the RaVN dotfiles repository. Sections are ordered to build context progressively: repo orientation, code standards, configuration mechanics, dev/release workflow, the mandatory Matt Pocock skills planning flow, and finally the RaVN-specific task execution process that ties everything together.

## Table of Contents

1. [Repository Structure & Purpose](#repository-structure--purpose)
2. [Global Helper Library (`global_fn.sh`)](#global-helper-library-global_fnsh)
3. [Style](#style)
4. [Error Handling](#error-handling)
5. [ShellCheck & Scripting Safety](#shellcheck--scripting-safety)
6. [Verification](#verification)
7. [Migrations](#migrations)
8. [Configuration Tracking (`restore_cfg.psv`)](#configuration-tracking-restore_cfgpsv)
9. [User Preferences](#user-preferences)
10. [Visual Changes](#visual-changes)
11. [Git Worktree Workflow (Development)](#git-worktree-workflow-development)
12. [Branching & Release Policy](#branching--release-policy)
13. [Task Planning & Skills Workflow (Matt Pocock Skills)](#task-planning--skills-workflow-matt-pocock-skills)
14. [Task Execution Workflow](#task-execution-workflow)

---

## Agent skills

### Issue tracker

GitHub Issues via `gh` CLI. External PRs are not triaged. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context. See `docs/agents/domain.md`.

## Repository Structure & Purpose

- `Configs/` - Source of truth for clean configuration files and templates that populate the user's `$HOME` (e.g., `.config/`, `.bashrc`).
- `Scripts/` - Automation scripts for installation, updating, and restoring configuration states:
  - `global_fn.sh` - Core library of shared variables, visual logging settings, and professional installer utility functions. Sourced in scripts via `source "${scrDir}/global_fn.sh"`.
  - `install.sh` - Main orchestration entry point (handles packages, services, config restoration, migrations, and final system post-install tweaks).
  - `restore_cfg.sh` - Restores configuration directories and files using tracking flags defined in `restore_cfg.psv`.
  - `migrations/` - Version-specific migration scripts (e.g., `v26.4.3.sh`) run automatically by the installer.
  - `extra/` - Optional, standalone scripts not invoked by `install.sh` — launched manually as needed (e.g., external drive mounting, Flatpak installation, additional modules, app/symlink restoration).
  - `launchers/` - Subsystem for installing and managing app launchers (Omarchy-style web apps and TUIs), including install binaries (`omarchy-*`, `ravn-browser-webapp-install`) and supporting libs.
  - `ravn/` - The actual RaVN engine: a modular installation framework with its own `AGENTS.md`, `framework/` (core logic: discovery, hooks, packaging, pipeline, retry, state), and `tasks/` organized by domain (`00-core`, `10-apps`, `20-shell`, `30-system`). The root-level `install.sh` is a separate, higher-level orchestration entry point. Includes `test-task.sh` for Docker-based local CI.
  - `ravnvm/` - Script for running RaVN inside a virtual machine, for testing and development purposes.
- `Configs/.local/bin/` - Personal CLI utility scripts, copied to `$HOME/.local/bin` by the dotfiles installer. Includes git workflow tools (`git-create-worktree`, `git-bare-clone`, `git-issue-worktree`, `git-setup`), the dotfiles reconciliation TUI `ravn-dot`, Emacs helpers, Hyprland/hyde utilities (`hyde-shell`, `hydectl`, `hyde-ipc`, `monitor-toggle.sh`, `toggle-gaps.sh`, etc.), and media tools (`descargar-video`, `play-yt`, `record.sh`).
- `Source/arcs/` - Compressed tar archives (`.tar.gz`, `.vsix`) containing fonts, cursors, SDDM themes, GTK assets, and Firefox/Code configuration baselines.
- `make/` - Modular Makefile system, split by task domain: `aliases.mk`, `cleanup.mk`, `dev.mk`, `docs.mk`, `format.mk`, `git.mk`, `logs.mk`, `system.mk`, `updates.mk`. `make/STYLE.md` standardizes the design language (naming, structure, output conventions) for all make targets in this directory — scoped specifically to `make/`, not a superset of the general "Style" section.
- `.git-hooks/` - Contains the pre-commit hook (shfmt + shellcheck quality gate); see "Verification".
- `docs/` - Documentation site built with Starlight (Astro).

## Global Helper Library (`global_fn.sh`)

> [!IMPORTANT]
> **MANDATORY CHECK**: Before implementing any custom helper logic (such as git cloning, file downloading, retries, spinners, or status logging), you **MUST** inspect [global_fn.sh](Scripts/global_fn.sh) and reuse its existing helper functions (like `clone_or_update_repo` or `download_with_spinner`) instead of writing new custom shell routines.

Always prioritize the helper functions imported from [global_fn.sh](Scripts/global_fn.sh) over raw shell commands:

- **Logging:** Use `info`, `success`, `warn_msg`, `error_msg`, `step`, and `print_log` for unified, semantic output with visual indicators.
- **Process Feedback:** Wrap long actions in `spin <pid> [msg]` or run them directly using `run_with_status "message" <command>` to show an interactive Braille spinner.
- **Package Auditing:** Use `pkg_installed <package>` to check package status.
- **Git & Downloads:** Use `clone_or_update_repo <name> <repo> <dest> [branch] [ssh]` and `download_file <url> [dest]` to perform downloads and cloning with built-in retry mechanisms and user feedback.
- **Robustness:** Use `retry <tries> <command>` for actions prone to transient failures.

## Style

- Two spaces for indentation, no tabs.
- Use bash 5 conditionals: use `[[ ]]` for string/file tests and `(( ))` for numeric tests.
- In `[[ ]]`, don't quote variables, but do quote string literals when comparing values (e.g., `[[ $branch == "dev" ]]`).
  > Note: this applies only inside `[[ ]]`. For command arguments outside `[[ ]]`, see the SC2086 rule in "ShellCheck & Scripting Safety" — there, quoting is always required.
- Prefer `(( ))` over numeric operators inside `[[ ]]` (e.g., `(( count < 50 ))`, not `[[ $count -lt 50 ]]`).
- For strings/paths with spaces, quote them instead of escaping spaces with `\ ` (e.g., `"$APP_DIR/Disk Usage.desktop"`, not `$APP_DIR/Disk\ Usage.desktop`).
- Shebangs:
  - Standard bash scripts must use `#!/usr/bin/env bash` consistently (never `#!/usr/bin/env sh`).
  - Migration scripts executed via `sh` by the installer should use `#!/usr/bin/env sh` (or be POSIX compliant).
- **`local` in functions**: every function-scoped variable must be declared with `local`. When the value comes from a command, declare the empty variable first and assign it on a separate line — never `local var=$(cmd)` on a single line, since it masks the command's exit code (SC2155). Correct example:
  ```bash
  local key_id=""
  key_id=$(gpg --list-secret-keys ... || true)
  ```
- **Naming**:
  - Variables and functions: `snake_case`.
  - Read-only constants (colors, icons, script-level config): `UPPER_SNAKE_CASE` + `readonly`.
  - Functions: prefixed by verb/category based on responsibility, not by source file (e.g., `print_*`, `verify_*`, `setup_*`, `configure_*`, `get_*`, `do_*`).

## Error Handling

- For scripts with strict error handling (`set -e` / `pipefail`), protect pipelines or command substitutions in variable assignments that might return a non-zero exit status (e.g., `grep` queries returning empty results) by appending `|| true` or `|| echo ""` to prevent premature shell termination.

## ShellCheck & Scripting Safety

- **Zero-Warning Policy**: All new or modified shell scripts must pass `shellcheck` with zero warnings or errors before committing. The pre-commit hook (`shellcheck` + `shfmt`) will block the commit if any warnings are found. This rule is non-negotiable.
  - **Exclusion list**: the list of files/paths excluded from the check lives only inside the pre-commit hook (`.git/hooks/pre-commit` or the source script that generates it) — that is the single source of truth. Do not duplicate this list here; if you need to know what's excluded, consult the hook directly.
- **Direct Command Checks (SC2181/SC2319)**: Avoid checking `$?` indirectly (e.g., `if [ $? -eq 0 ]`). Check commands directly (e.g., `if my_command; then`) or use success tracking variables (`success=0; my_command || success=1; if (( success == 0 )); then`).
- **Quote Variable Expansions (SC2086)**: Always double-quote variable expansions when they are used as command arguments to prevent word splitting (e.g., `"$var"`), except inside `[[ ]]` where expansion is safe.
- **Built-in Parameter Expansion (SC2001)**: Avoid calling external tools like `sed` or `awk` for simple string replacements on single variables; prefer built-in Bash parameter expansion (e.g., `${var//search/replace}`).
- **Localizing False Positives**: Do not ignore entire files for linter warnings. Use inline `# shellcheck disable=SCxxxx` directives only on the specific lines where a false positive occurs (e.g., AWK variables inside single quotes).

## Verification

### Automatic (pre-commit hook)

On every commit, the hook (`shfmt` + `shellcheck`) automatically runs only against **staged** files that are shell scripts:

- **shfmt**: auto-fixes formatting in place and re-stages the changed files. Exact flags: `shfmt -i 2 -sr -kp -ci -w "$file"`.
- **shellcheck**: blocks the commit if it finds warnings. On failure, it generates an AI-ready report in `logs/shellcheck-report-<timestamp>.log` with the warnings and a ready-to-use prompt for asking an agent to explain and fix each one.
- **Escape hatch** (emergencies only): `SKIP_HOOKS=1 git commit` — skips both checks.

### Manual (full-repo audit)

To review the entire repo (not just staged files), e.g. before a release:

```bash
# ShellCheck across all scripts
shellcheck Scripts/**/*.sh

# shfmt: only shows the diff, does NOT modify files (unlike the hook)
shfmt -i 2 -sr -kp -ci -d Scripts/
```

> Note: `shellcheck Scripts/**/*.sh` requires `shopt -s globstar` enabled in the bash session to expand recursively; otherwise it will only match one level of subdirectories.
> Note: unlike the hook (which uses `-w` and auto-fixes), the manual command uses `-d` (diff only) — it doesn't modify anything, it just shows you what would change.

## Migrations

- Located in `Scripts/migrations/`, named after version tags in `vYY.M.patch.sh` format (e.g., `v25.8.2.sh`) — the same versioning scheme used for release tags (see "Branching & Release Policy").
- Migrations are run via `sh` inside `install.sh`. For shebang and POSIX-compliance requirements, see "Style" § Shebangs — do not restate those rules here.
- Output brief details to stdout explaining what the migration is adjusting, so the user is informed during updates.

## Configuration Tracking (`restore_cfg.psv`)

`restore_cfg.psv` is the manifest that defines which files/directories are tracked between `Configs/` (repo) and `$HOME` (live system). It is the single source of truth consulted both by `restore_cfg.sh` (repo → `$HOME`, automatic) and by `ravn-dot` (bidirectional review — see "User Preferences" § Live Synchronization).

1. **Adding files to tracking:** to add a configuration target to the restore system, insert a row using the format:
   ```text
   Flag|${HOME}/path/to/directory|file_name|dependency
   ```
   **Flags:**
   - `P` (Populate/Preserve) - Copy target from `Configs/` to destination ONLY if it does not exist. Prevents overwriting local user changes.
   - `S` (Sync) - Copy target from `Configs/` and overwrite local file.
   - `O` (Overwrite) - Force overwrite. Overwrites everything recursively if the target is a directory.
   - `B` (Backup) - Backs up the target before modifying.
   - `I` (Install/Import) - Imports or configures associated packages.
2. **Reviewing and syncing changes:** run `ravn-dot`. It reads `restore_cfg.psv` to determine which files are tracked, diffs each one between `Configs/` and `$HOME`, and presents an interactive `fzf` menu per differing file, where you can view the diff, resolve visually with `meld` or `nvim`, or choose which side to keep (repo → `$HOME` or `$HOME` → repo). This is the current, human-driven source of truth for reconciling drift — see "User Preferences" § Live Synchronization for how this fits into the agent's automated workflow.

## User Preferences

### Live Synchronization

`Configs/` (repo) and `$HOME` (live system) must be kept in sync in both directions, but the tooling for each direction is different:

- **repo → `$HOME`**: Whenever a file inside `Configs/` is changed, immediately synchronize it to its corresponding live path in `$HOME` — via `restore_cfg.sh` or a manual copy. `restore_cfg.sh` only supports this direction.
- **`$HOME` → repo**: Whenever a file inside `$HOME` is changed and needs to be captured back into the repo (e.g., after live validation — see "Task Execution Workflow" § Phase 3), copy it back to its corresponding path in `Configs/`. There is no automated tool for this direction; `restore_cfg.psv` serves as the map/bridge between `$HOME` and `Configs/` paths and should guide which files to copy (see "Configuration Tracking").
- **`ravn-dot`**: an interactive TUI (`fzf`-based) for reviewing and reconciling differences between `Configs/` and `$HOME` (see "Configuration Tracking" for details). It has no headless/non-interactive mode (only `--dry-run`), so **agents should not invoke it as part of an automated workflow** — it's a tool for manual human review, useful for auditing drift between repo and `$HOME` outside of a specific task.

## Visual Changes

- When making visual, style, or layout changes to **Waybar** (its different layouts/configs), always verify the result by taking and analyzing a screenshot before considering the change complete.
  - **Capture command**: `hyde-shell screenshot m` (monitor screenshot, per `keybindings.conf`).
  - **Save location**: at the agent's discretion (e.g., a temp path).
  - **Cleanup**: the screenshot file **must always be deleted** after it has been analyzed — never leave capture artifacts behind.
  - **Analysis**: the agent itself inspects the captured image directly (no separate review step by the user is implied by this rule).
  - **Scope**: this rule is specific to Waybar and its layouts. It does not extend to other visual surfaces (GTK themes, SDDM, cursors, etc.) unless stated elsewhere.

## Git Worktree Workflow (Development)

To protect the user's active system configurations from accidental resets or uncommitted code loss during development, and to maintain task isolation:

> [!NOTE]
> **Disambiguating "ravn" paths** — three distinct things share this name:
> - `Scripts/ravn/` — the RaVN engine source code, inside this repo (see "Repository Structure & Purpose").
> - `~/.local/share/ravn/` — the live, installed configuration clone on the user's system. **Formerly** used directly for active development (deprecated practice) — today it should only be touched for tracking config updates or system-wide script execution, never for feature development.
> - `~/Work/RaVN/dev` (and other worktrees under `~/Work/<repo>/`) — the **current, correct** location for all active development.

- **Isolated Development in `~/Work`**: All active development work must be carried out inside worktrees under `~/Work/<repo>/` (which are created from the bare repository at `~/.local/share/git-bare/<repo>`).
- **No Direct Modification in Live Clone**: Do not perform development or commit changes directly inside the live configuration clone located at `~/.local/share/ravn/` (except when updating tracking config files or executing system-wide scripts).
- **Automation Utilities** (all restored under `~/.local/bin/` — see "Repository Structure & Purpose" for their source in `Configs/.local/bin/`):
  - `git-create-worktree` for general feature/chore branches.
  - `git-issue-worktree` for GitHub-tracked issues.
  - > [!IMPORTANT]
    > **MANDATORY**: `git-bare-clone` must always be used to create bare repositories (whether invoked via a `make` target or manually) — never create a bare repo with raw `git` commands. This is a recurring compliance gap: agents have created bare repos manually instead of using this script.
- **Workflow Benefit**: Developing under `~/Work` isolates development changes from host configuration restoration processes. This eliminates the need to manually disable ravn tracking (e.g. setting `ravn=false` in `Scripts/ravn/config/packages.conf`) to protect local changes from being overwritten during installer or `restore_cfg.sh` runs.

## Branching & Release Policy

Refer to [RELEASE_POLICY.md](RELEASE_POLICY.md) for details. **The following rules are non-negotiable and must be strictly followed by all agents and developers:**

- **`dev`**: The active branch for all features and PRs. **Under no circumstances should `dev` receive direct commits.** It must always be fed exclusively by auxiliary topic/feature branches created in isolated worktrees (via `git-create-worktree`, in `Configs/.local/bin/` — see "Repository Structure & Purpose") and merged in.
- **`rc`** (Release Candidate): Receives a merge from `dev` on the second-to-last Friday of the month. Frozen for regression testing and bug fixes only. **`rc` only receives merges from `dev`.**
- **`master`**: Receives a merge from `rc` on the last Friday of the month for the official monthly version release, tagged as `YY.M.patch` (e.g., `26.4.3`) — consistent with the versioning scheme already used by migration scripts in `Scripts/migrations/`.

> [!WARNING]
> **This policy is currently enforced by convention only, not by tooling.** The pre-commit hook (see "Verification") checks formatting/linting, but does **not** currently block direct commits to `dev`, `rc`, or `master`. In practice, direct commits to `dev` happen regularly despite this rule. Until branch protection is implemented (at the hook level or via the git host), agents and developers must self-enforce this policy manually — treat it as strictly as if it were technically blocked.

## Task Planning & Skills Workflow (Matt Pocock Skills)

This repository mandates [Matt Pocock's engineering skills](https://github.com/mattpocock/skills) for planning and reviewing work. `/setup-matt-pocock-skills` has already been run — the issue tracker, triage label vocabulary, and domain doc layout it configures live at `docs/agents/issue-tracker.md`, `docs/agents/triage-labels.md`, and `docs/agents/domain.md`.

> [!NOTE]
> Unsure which skill fits a given situation? Run `/ask-matt` — it's the router over all installed skills.

### Task Sizing (before choosing a path)

> This classification is a local convention for this repository — it does not come from the Matt Pocock skills repo itself, which branches on "single-session vs. multi-session" rather than "trivial vs. engineering." It is layered on top of the official flow below, not a replacement for it. Do not confuse this with the `/triage` skill (below), which is a different thing: `/triage` moves *incoming* issues/PRs through a bug/enhancement state machine — it has nothing to do with sizing a task you're about to start.

1. **Trivial / Administrative Tasks** — simple config changes (e.g., `.gitignore`, env var templates), doc typo fixes, minor dependency bumps.
   - **Fast-Track**: skip straight to `/implement`, then close with `/code-review`.
2. **Engineering Tasks** — anything that alters, adds, or removes business logic, task modules, `restore_cfg.psv` schema, or architecture.
   - **Full Pipeline**: execute the 5-step chain below, sequentially, without exceptions.

> [!IMPORTANT]
> **Classify out loud, don't decide silently.** `/grill-with-docs` has `disable-model-invocation: true` by design — Matt Pocock deliberately reserved the decision to start an interview for the human, not the agent. Silently classifying a task as Trivial and jumping straight to `/implement` overrides that design choice. Instead:
> 1. Classify the task using the criteria above.
> 2. **State the classification and the resulting path before writing any code** — e.g., *"Classifying this as Trivial — going straight to `/implement`. Say so if you'd rather start with `/grill-with-docs`."* This gives the user a cheap veto before work begins, not after.
> 3. **When in doubt, default to the Full Pipeline**, not the shortcut — consistent with "Strict Operational Rules" § Anti-Rationalization below. The Fast-Track is for genuinely unambiguous, low-risk edits; if there's any real design or domain ambiguity, that ambiguity is exactly what `/grill-with-docs` exists to resolve.

### The Main Build Chain

```txt
/grill-with-docs → /to-spec → /to-tickets → /implement → /code-review
```

This is the official main flow of the Matt Pocock skills (per `ask-matt`'s routing logic). Each step is **user-invoked only** (the agent does not reach for these on its own) — but per "Strict Operational Rules" below, once a task is classified as an Engineering Task, the agent must drive this chain itself in sequence rather than waiting to be prompted step by step.

| Step | Command | Purpose | Exit Gate |
| :---: | :--- | :--- | :--- |
| 1 | `/grill-with-docs` | A relentless interview to sharpen a plan or design, writing resolved terms to `CONTEXT.md` and hard decisions as ADRs as it goes. | Design ambiguities resolved; glossary/ADRs updated. |
| 2 | `/to-spec` | Synthesize the current conversation into a spec (no re-interviewing) and publish it to the issue tracker with the `ready-for-agent` label. | Spec published to the tracker. |
| 3 | `/to-tickets` | Break the spec/conversation into tracer-bullet tickets, each declaring its blocking edges, published to the tracker. | Atomic ticket set with blocking edges published. |
| 4 | `/implement` | Implement a piece of work from a spec or ticket, driving `/tdd` internally at agreed seams. Runs typechecking and tests regularly. | Working code, tests passing. No "vibe coding." |
| 5 | `/code-review` | Two-axis parallel review of the diff since a fixed point — Standards (repo conventions) and Spec (does it match the ticket/PRD). | Side-by-side Standards vs. Spec report. |

> [!IMPORTANT]
> **Standard review framing**: every invocation of `/code-review` in this repository must be framed with this literal instruction:
>
> ```text
> Review this repository as if you are blocking or approving a production PR.
> ```
>
> This framing is mandatory and non-negotiable — it consistently produces a stricter, higher-signal review than a neutral "review this" prompt, and it is what's used everywhere `/code-review` is invoked in this repo (including "Task Execution Workflow" § Phase 4).

> [!NOTE]
> **Context hygiene** (per `ask-matt`): keep steps 1–3 in one unbroken context window — don't `/compact` or clear context until after `/to-tickets`, so grilling, spec, and tickets build on the same reasoning. Each `/implement` then starts fresh from the ticket. If a session approaches the model's effective reasoning window before `/to-tickets` is done, use `/handoff` rather than pushing on with degraded context.

### Decision Tree

```txt
                              New Request
                                   │
                                   ▼
                    Classify: Trivial or Engineering?
                    (see "Task Sizing" criteria)
                                   │
              ┌────────────────────┴────────────────────┐
              ▼                                          ▼
          TRIVIAL                                   ENGINEERING
              │                                          │
              ▼                                          ▼
   State classification +                     State classification +
   path out loud. Give user                   path out loud. Give user
   a cheap veto before                        a cheap veto before
   starting.                                  starting.
              │                                          │
              │ (no objection)                           │ (no objection)
              ▼                                          ▼
        /implement                              /grill-with-docs
              │                                          │
              │                            ┌─────────────┴─────────────┐
              │                            ▼                           │
              │                   Design ambiguity                     │
              │                   still unresolved?                    │
              │                            │                           │
              │                    YES ────┘                          NO
              │                     │                                  │
              │              Keep grilling                             ▼
              │              (same context                        /to-spec
              │               window — no                              │
              │               /compact yet)                            ▼
              │                                          Multi-session build?
              │                                       (per ask-matt, NOT "how
              │                                        many files touched")
              │                                                        │
              │                                        ┌───────────────┴───────────────┐
              │                                        ▼                               ▼
              │                                       NO                              YES
              │                                        │                               │
              │                                        ▼                               ▼
              │                                  /implement                     /to-tickets
              │                                  (same context                        │
              │                                   window)                    /implement per ticket
              │                                        │                    (fresh context each,
              │                                        │                     via /handoff if needed)
              └────────────────────┬───────────────────┴───────────────────────────────┘
                                    ▼
                              /code-review
                          (Standards + Spec)
                                    │
                                    ▼
                       Commit → push → PR into `dev`
                    (never direct commits — see
                     "Branching & Release Policy")
```

### On-ramps

- **Incoming bugs/requests not created by you** → `/triage` first (moves them through categorize → verify → grill → agent-ready brief), which then feeds `/implement`. Tickets that `/to-tickets` already produced are already agent-ready — do not re-triage them.
- **A hard, resistant bug** (intermittent, regressed between known-good states) → `/diagnosing-bugs` instead of guessing.

### Strict Operational Rules & Anti-Rationalization

- **No Parallel Paths**: The Matt Pocock skills chain is not a suggestion or one option among several — it is *the* workflow for this repository. The agent must not invent, improvise, or substitute its own ad-hoc planning process (its own informal "let me think through this" sequence, a custom checklist, a different ordering of steps) in place of `/grill-with-docs → /to-spec → /to-tickets → /implement → /code-review`. If a task is an Engineering Task, the path is already decided — the agent's job is to walk it, not to design an alternative.
- **Internal by Default**: The agent must drive this chain itself, internally, as its own default operating procedure — not as something it only does when explicitly asked to "use the skills" or "follow Matt Pocock's workflow." Treat every applicable task as if the chain were already silently invoked the moment work begins, the same way "Style" or "ShellCheck & Scripting Safety" apply without needing to be requested.
- **Absolute Sequentiality**: Never run `/implement` for an Engineering Task unless a valid spec (`/to-spec`) and broken-down tickets (`/to-tickets`) already exist to back it up.
- **No Skipping Under Pressure**: Time pressure, an urgent tone from the user, a "just do it quickly," or the agent's own confidence that it "already understands the task" are not valid reasons to bypass a step. If a step feels unnecessary, that feeling is itself the signal to check with the user (per "Task Sizing") rather than to quietly skip it.
- **Verification is Non-Negotiable**: Do not claim a task is complete based on intuition. `/implement` and `/code-review` exit gates require deterministic proof (passing tests, successful builds, explicit terminal confirmation) — see "Verification" for the RaVN-specific lint/test commands that back this up.
- **The Socratic Mandate**: During `/grill-with-docs`, do not be agreeable. Actively find flaws, missing requirements, and architectural conflicts *before* a single line of production code is written.

### How this fits with RaVN's own workflow

`/implement` (step 4) is where the generic Pocock flow meets RaVN-specific mechanics. "Task Execution Workflow" (below) is the detailed, repo-specific process — worktree isolation, package registration, config sync, Docker testing, live validation — that governs *how* `/implement` and the surrounding steps actually get carried out in this repository. Read the two together: this section decides *which skills to invoke and when*; "Task Execution Workflow" defines *what happens inside each phase* for RaVN specifically.

## Task Execution Workflow

> [!IMPORTANT]
> **MANDATORY & NON-NEGOTIABLE**: For Engineering Tasks (see "Task Planning & Skills Workflow" § Task Sizing), these phases describe what happens specifically during and around `/implement`. Whenever a new task or feature is requested, the agent must execute these phases in strict sequence. No phase may be skipped. Each phase cross-references the governing section that defines its rules — do not restate or bypass those rules.

### Phase 1 — Environment & Task Setup

1. **Create an isolated worktree** for the task via `git-create-worktree` (see "Git Worktree Workflow"). No direct commits to `dev`.
2. **Determine the best implementation approach** for the requested task. When feasible, prefer creating a task module under `Scripts/ravn/tasks/<category>/<NN>-<name>.sh` following the module contract (see [Scripts/ravn/AGENTS.md](Scripts/ravn/AGENTS.md) § Adding a task module); otherwise choose the most appropriate mechanism (script, config edit, migration, etc.).
3. **Register new packages**, only if the task requires system packages:
   - [Scripts/pkg_core.lst](Scripts/pkg_core.lst) — base packages installed for every user.
   - [Scripts/pkg_extra.lst](Scripts/pkg_extra.lst) — optional packages the user can opt into.

   Add an accurate inline description in either case.

### Phase 2 — Configuration & Synchronization

4. **Update configuration templates** in `Configs/` (shell/zsh aliases, etc.) and add tracking rows to [restore_cfg.psv](Scripts/restore_cfg.psv) as needed (see "Configuration Tracking").
5. **Sync `Configs/` → `$HOME`** immediately after every `Configs/` change (see "User Preferences" § Live Synchronization) — this is required to validate the change against the real, live environment in the next phase.

### Phase 3 — Testing & Validation

6. **Run lint and syntax checks** on all touched scripts: `shellcheck <file>`, `shfmt -i 2 -sr -kp -ci -d <file>`, and `bash -n <file>` (see "Verification").
7. **Run an isolated Docker test** via [Scripts/ravn/test-task.sh](Scripts/ravn/test-task.sh) to validate the task in a clean `archlinux:latest` container (see [Scripts/ravn/AGENTS.md](Scripts/ravn/AGENTS.md) § Testing Tasks in Isolation).
8. **Validate live in `$HOME`, then sync back to the repo**:
   - Work and test directly against the live files in `$HOME` — this is the only place things like Waybar rendering or a Hyprland reload can actually be confirmed (see "Visual Changes" for the specific screenshot verification rule when Waybar/layouts are touched).
   - Iterate until the change is 100% confirmed working and meets the user's requirements.
   - Copy the validated final state from `$HOME` back into `Configs/` (see "User Preferences" § Live Synchronization, `$HOME` → repo direction), so that `$HOME` and the repo are in sync before pushing. `ravn-dot` may optionally be pointed to by the agent as a suggestion for the user to manually audit the sync afterward, but the agent itself should not depend on it (it's interactive-only).

### Phase 4 — Deployment

9. **Run `/code-review`** against the fixed point where the worktree branched off, using the standard review framing (see "Task Planning & Skills Workflow" § The Main Build Chain) — Standards + Spec review. Resolve any Blocker/Major findings before proceeding.
10. **Commit, push, and merge into `dev`** via PR (see "Branching & Release Policy"). `dev` must never receive direct commits.
