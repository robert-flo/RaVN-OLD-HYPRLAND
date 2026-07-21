# RaVN task development guide

This directory contains the RaVN task runner. An agent adding or migrating a
task must treat the task's observable behavior as the deliverable: the task
must install the tool, verify that the tool actually runs, and fail clearly
when dependencies or postconditions are missing.

## Where tasks belong

Active task modules live under:

```text
Scripts/ravn/tasks/<category>/<number>-<name>.sh
```

Use the existing category that matches the responsibility:

- `tasks/10-npm-apps/` — npm CLIs and npm-backed application tools.
- `tasks/20-curl-apps/` — vendor shell installers downloaded over HTTPS.
- `tasks/30-github-apps/` — tools distributed from GitHub and managed by mise.
- `tasks/20-shell/` — shell tools and shell configuration tasks.
- `tasks/90-system/` — final system configuration tasks executed after package
  and shell setup; use this category for administrative end-of-install steps.
- `tasks/80-app-configs/` — application configuration trees and launchers
  installed from upstream repositories.
- Add a new category only when an existing category cannot express the task;
  document the new category here and update discovery tests.

Legacy modules live under `tasks_legacy/`. Do not edit or delete a legacy task
while migrating it. Add one active replacement, validate it, and remove or
quarantine the legacy module only through an explicitly reviewed migration.

Files are discovered automatically with `find tasks/ -name "*.sh" | sort`.
There is no task registry to edit. Numeric prefixes control ordering, so retain
the legacy task's number when the replacement is a one-for-one migration.

For issue work, create the worktree with the `git-issue-worktree` helper from
`PATH`:

```bash
git-issue-worktree \
  -r <repository-path> \
  -B origin/dev \
  <issue-number> <slug>
```

Options must precede the issue number. This repository uses `origin/dev`, not
`origin/main`.

`git-issue-worktree` is the issue-aware interface over `git-create-worktree`.
It delegates worktree creation to that helper and derives the topic branch and
worktree directory names from the issue number and slug. Use
`git-create-worktree` directly for general feature or chore work; do not use
raw `git worktree` commands.

Do not commit directly to `dev`; use the issue worktree, then push a branch and
merge through a pull request.

## Universal task lifecycle contract

Every active task, regardless of backend or task family, must implement all
five lifecycle operations:

```text
check()
install()
verify()
reset()
verify_reset()
```

`check()` determines whether work is needed; `install()` applies the desired
state; `verify()` proves the postcondition; `reset()` removes task-owned
resources; and `verify_reset()` proves the reset postcondition. A task is not
complete, testable, or merge-ready when any of these operations is missing.
The runner must never infer reset behavior from `install()` or `cleanup()`.

## Unified CLI task shape

Every canonical CLI task uses one public entrypoint and declares its backend
explicitly:

```bash
# shellcheck disable=SC2034
CLI_COMMAND="tool"
# shellcheck disable=SC2034
CLI_INSTALLER="mise" # or upstream

ravn_cli_task
```

Mise tasks additionally declare `CLI_PACKAGE`. Upstream tasks declare
`CLI_INSTALL_URL`, `CLI_VERSION_ARGS`, and provider-specific update fields such
as `CLI_UPDATE_CHECK_ARGS`, `CLI_UPDATE_ARGS`, and `CLI_INSTALL_DIR_ENV`.
Backend-specific fields remain explicit; only backend dispatch is hidden.

The task author must not call `ravn_mise_cli_task` or `ravn_upstream_task`
directly in a canonical CLI descriptor.

## Canonical npm CLI task shape

For a versioned npm CLI, the task file should contain only the CLI-specific
identity and the shared mise entrypoint:

```bash
#!/usr/bin/env bash

# shellcheck disable=SC2034
CLI_PACKAGE="@openai/codex"
# shellcheck disable=SC2034
CLI_COMMAND="codex"

ravn_mise_cli_task
```

Replace the values with the actual npm package and executable command. For
example, GitHub Copilot uses `CLI_PACKAGE="@github/copilot"` and
`CLI_COMMAND="copilot"`.

### Meaning of the two required fields

`CLI_PACKAGE` is the exact npm package specifier passed to mise. It may include
an npm scope, such as `@openai/codex`. Do not use the executable name when the
package name differs. Do not add `npm:` here; the shared backend adds that
prefix when writing `mise.toml`.

`CLI_COMMAND` is the executable the package exposes and the command used for
real verification. It is also used to derive the task identity, the wrapper
name in `$HOME/.local/bin`, and the task-owned state directory. It must be the
actual command available after installation, not a display name.

The `# shellcheck disable=SC2034` comments are intentional: the variables are
read by the shared backend after the task file is sourced. Keep the directive
on the variable declaration; do not disable ShellCheck for the whole file.

Do not copy the old `omarchy-npx-install` implementation into a new canonical
task. `mise` is the standard backend for versioned npm CLIs. The shared
`ravn_mise_cli_task` entrypoint loads `framework/mise-cli.sh` and supplies the
canonical lifecycle, including dependency handling, install, real command
verification, update, rollback, reset, and evidence recording.

If a package cannot use the generic mise backend, stop and document the reason
in the issue before introducing a custom implementation.

## Task contract and ownership

### Administrative Testability Contract (mandatory)

Every canonical administrative task must declare `ADMIN_TASK_ID`,
`ADMIN_EXECUTION_PROFILE`, `ADMIN_REQUIRES_PRIVILEGE`, owned resources and
conflicts, capabilities, reversibility, activation boundary, postconditions,
evidence scope, and test level. It must expose read-only `admin_plan`,
authorized `admin_apply`, observable `admin_verify`, and honest recovery and
reset hooks. The universal task lifecycle contract above still applies:
administrative tasks must expose both `reset()` and `verify_reset()` in
addition to their administrative reset behavior where the runner requires it.
Do not use opaque `eval`, undeclared elevation, whole-file claims,
or success based only on a process exit code.

The required progression is isolated first, then Docker evidence, then host
validation only when the task explicitly supports it. Host mode must require
an explicit `--host` selector, `--approve`, and non-interactive authorization;
it must preflight resources and permissions, verify a recoverable backup, and
write reconciliation evidence separately from isolated results. Failed host
verification must remain unsuccessful and include recovery instructions.

Use `03-ssh-config.sh` and `03-ssh-config-lifecycle.sh` as the reference
implementation. A new administrative task is incomplete until its lifecycle
matrix covers clean, existing, malformed, conflicting, partial, rollback,
reset, idempotence, and reinstall behavior.

The SSH reference also has a dedicated Docker regression test at
`tests/03-ssh-config-docker.sh`. Run it when changing the SSH task; it verifies
the effective parser result, permissions, unmanaged-content preservation,
idempotence, reset, and rollback in an Arch container without touching the
host HOME.

The shared backend populates the task metadata and lifecycle functions. A
canonical task must therefore be executable without shell initialization and
must not open a TUI or prompt for credentials.

The backend owns these resources for a CLI command `<command>`:

- mise configuration and installed tool state under
  `${XDG_DATA_HOME:-$HOME/.local/share}/ravn/tasks/<command>`;
- the single active wrapper at `$HOME/.local/bin/<command>`;
- task evidence and audit state managed by the runner.

The active wrapper must be the only exposed command for the task. Do not create
additional global symlinks or wrappers. Keep the legacy descriptor unchanged
until the replacement has passed validation.

The generic backend uses `latest` for explicit update policy, not as a reason
for ordinary `run` to update a verified installation. It manages Node through
mise, enables required npm lifecycle scripts, verifies the real command, and
retains the previous verified configuration where rollback is possible.

## Task-specific lifecycle contract — required per task

Every new or migrated active task must ship its own lifecycle integration test.
Framework tests and Docker isolation prove the runner and backends in general;
they do **not** prove that **this** task integrates correctly end to end.

### Naming and placement

For a task file `tasks/<category>/<number>-<name>.sh`, add:

```text
Scripts/ravn/tests/<number>-<name>-lifecycle.sh
```

Examples:

- `tasks/10-npm-apps/13-ghui.sh` → `tests/13-ghui-lifecycle.sh`
- `tasks/10-npm-apps/11-codex.sh` → `tests/11-codex-lifecycle.sh`

One lifecycle file per task. Do not share a category-wide lifecycle test across
`10-npm-apps`. Do not merge ghui and codex into one script.

### What the lifecycle test must prove

Run on the host against the real task selector (`<command>` / `CLI_COMMAND`).
Skip with a clear `SKIP:` line only when a hard dependency is missing (for
example mise unavailable). Never report `PASS` when the scenario did not run.

At minimum, the script must assert all of the following for **that task only**:

1. `run` — clean or satisfied install ends verified;
2. idempotence — a second `run` does not unexpectedly reinstall or update;
3. real command — wrapper executes (for example `<command> --version`);
4. `check-updates` — completes without error on a verified install;
5. `update` — happy path when applicable, or document `SKIP` with reason;
6. **rollback** — a failed update does not replace the previous verified
   version (same resolved version before and after the failed update);
7. `reset --yes` — task-owned resources are removed;
8. post-reset `verify` — reports absence or dependency failure as expected;
9. reinstall after reset — `run` + `verify` succeed again.

For canonical mise CLI tasks, criterion 6 may use `RAVN_TEST_UPDATE_VERIFY_FAIL=1`
during `update` to force candidate promotion failure, then assert rollback.
See `tests/13-ghui-lifecycle.sh` as the reference implementation.

### When a task is incomplete

A PR that adds or migrates a task is **not merge-ready** until:

- the task module exists under `tasks/`;
- `tests/<number>-<name>-lifecycle.sh` exists and passes (or `SKIP` with reason);
- `bash Scripts/ravn/test-task.sh <command>` passes in Docker;
- discovery counts are updated when the active task set changes.

Existing tasks migrated before this rule (for example codex, copilot, opencode)
remain legacy debt until each one gains its own `tests/<number>-<name>-lifecycle.sh`
in a follow-up migration PR. New work must not add tasks without the lifecycle file.

## Mandatory testing workflow

Testing is the most important part of adding a task. A task is not complete
because npm exited successfully or because a wrapper file exists. Every new or
migrated task must prove that the installed command is usable in a clean
environment.

Run these checks from the repository root or adjust paths accordingly.

### 1. Static checks first

```bash
bash -n Scripts/ravn/tasks/10-npm-apps/<number>-<name>.sh
shellcheck Scripts/ravn/tasks/10-npm-apps/<number>-<name>.sh
shfmt -d Scripts/ravn/tasks/10-npm-apps/<number>-<name>.sh
git diff --check
```

Fix every ShellCheck warning. Do not use a broad disable directive to hide a
real problem. Use the repository's Bash style: quote command arguments, use
`[[ ]]` for tests, localize function variables, and preserve non-zero statuses.

### 2. Discovery and deterministic framework tests

```bash
bash Scripts/ravn/tests/discovery.sh
bash Scripts/ravn/tests/contract.sh
bash Scripts/ravn/tests/runner.sh
bash Scripts/ravn/tests/state.sh
bash Scripts/ravn/tests/mise.sh
bash Scripts/ravn/tests/menu.sh
bash Scripts/ravn/tests/opencode-contract.sh
bash Scripts/ravn/tests/grok-matrix.sh contract
bash Scripts/ravn/tests/dry-run.sh
bash Scripts/ravn/tests/test-task-selection.sh
```

If adding a canonical task changes the discovered task count, update the
discovery assertion and verify that no `tasks_legacy` file is discovered.
Never weaken the test to make a task disappear.

### 3. Isolated Docker test — required

For an npm CLI, run the real isolated test:

```bash
bash Scripts/ravn/test-task.sh <command>
```

For example:

```bash
bash Scripts/ravn/test-task.sh codex
bash Scripts/ravn/test-task.sh copilot
bash Scripts/ravn/test-task.sh 10-npm-apps
```

This test starts a clean Arch container, bootstraps the pinned mise fixture,
installs Node and the npm package, invokes the task's `install()`, and then
executes the task's real `verify()` path. A successful result must say
`<package> → PASÓ`; a merely successful installer exit is insufficient.

Use `--mise-version <version>` only when reproducing a known fixture issue.
Use `--keep` when a failure needs container inspection; remove the container
after debugging. Use `--dry-run` only to inspect control flow — it does not
prove installation or command usability.

Reference-only tasks are excluded from category and `--all` selectors by
default. They appear in the summary as `Omitidas (reference)`, not as
`No verificables`. Pass `--include-reference` to run them in Docker.

A skipped reference task is not a failed active task, but it also is not
evidence that the canonical task works.

### 4. Task-specific lifecycle test — required

For every task you add or migrate, create and run its dedicated lifecycle
contract (see **Task-specific lifecycle contract** above):

```bash
bash Scripts/ravn/tests/<number>-<name>-lifecycle.sh
```

Example for ghui:

```bash
bash Scripts/ravn/tests/13-ghui-lifecycle.sh
```

Copy `tests/13-ghui-lifecycle.sh` when migrating another mise CLI task; replace
the task selector, wrapper path, and any task-specific verification arguments.
Keep the rollback, reset, and reinstall assertions.

Manual `setup.sh` invocations are still useful while developing the lifecycle
script:

```bash
bash Scripts/ravn/setup.sh run <command>
bash Scripts/ravn/setup.sh verify <command>
bash Scripts/ravn/setup.sh check-updates <command>
bash Scripts/ravn/setup.sh update <command>
bash Scripts/ravn/setup.sh reset <command> --yes
bash Scripts/ravn/setup.sh matrix grok contract
```

In non-interactive environments (agents, CI, pipes without a TTY), `reset`
requires `--yes`. Without it, the runner exits with a clear error instead of
waiting for confirmation or recording a misleading `reset-refused`.

When a scenario cannot run because the host lacks mise, network access, or a
required platform, record it as `SKIP`, `UNSUPPORTED`, or `NOT_RUN` with the
reason inside the lifecycle script. Never report `PASS` when the scenario did
not execute.

### 5. Full repository gates before commit

```bash
find Scripts/ravn -name '*.sh' -type f -exec bash -n {} +
find Scripts/ravn -name '*.sh' -type f -print0 | xargs -0 shellcheck
shfmt -d Scripts/ravn
flg_DryRun=1 bash Scripts/ravn/setup.sh
bash Scripts/ravn/tests/dry-run.sh
bash Scripts/ravn/tests/<number>-<name>-lifecycle.sh
bash Scripts/ravn/test-task.sh <command>
git diff --check
```

`flg_DryRun=1 bash Scripts/ravn/setup.sh` runs the discovered active-task
pipeline in dry-run mode (no menu, no install). In a non-interactive shell,
`setup.sh` without a subcommand exits with usage guidance instead of opening
the TUI.

The full Docker matrix can require network access and may take time. If it
cannot run, report the exact command and reason in the handoff; do not claim
the task is fully validated. Run the focused task test again after every fix.

## Failure diagnosis

- `dependency-missing`: mise or another required runtime is unavailable;
  verify the injected binary path and bootstrap policy.
- install failure: inspect the task log and the mise/npm resolution output;
  do not create a wrapper manually.
- verification failure: run the wrapper directly with its verification args;
  check the resolved package version, Node version, and lifecycle scripts.
- `update-failed`: confirm the previous verified configuration remains active.
- `rollback-failed`: treat as a blocking reliability failure; do not merge.
- Docker `NO VERIFICABLE`: inspect `TEST_LEVEL` and whether `verify()` is
  available; do not interpret it as success. Reference-only omissions are
  reported separately and are not failures.
- `reset` without `--yes` in a non-interactive shell: pass `--yes` explicitly.
- `setup.sh` with no subcommand in a non-interactive shell: use
  `run|verify|reset|update|check-updates <command>` or `flg_DryRun=1` for the
  pipeline gate.

## Completion checklist

Before opening a PR, confirm all of the following:

- The task is under the correct active category and has the correct numeric
  filename prefix.
- `CLI_PACKAGE` is the exact npm package and `CLI_COMMAND` is the real binary.
- The task uses `ravn_mise_cli_task` unless an issue documents an exception.
- `tests/<number>-<name>-lifecycle.sh` exists, passes, and covers rollback,
  reset, and reinstall for this task.
- The legacy task is preserved and unrelated tasks are untouched.
- Static, deterministic, and isolated Docker checks pass.
- `bash Scripts/ravn/test-task.sh <command>` passed in Docker.
- The real command was executed from a clean environment.
- Any skipped or unsupported matrix layer is explicitly reported.
- The issue, commit, PR, and merge target are linked.
- The PR is merged into the recorded base branch before deleting its worktree
  or local/remote topic branches.
