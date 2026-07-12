# RaVN Framework v1

A modular, convention-driven bootstrap framework for Arch Linux desktop environments. Inspired by Omarchy, HyDE, Homebrew, Cargo, mise, and LazyVim.

## Philosophy

- **Convention over configuration** — Drop a `.sh` file in `tasks/`, it runs automatically.
- **Preserve behavior** — Code is moved, not rewritten. Every function from the original installer lives on in a module.
- **Thin entrypoint** — `setup.sh` is ~15 lines. All logic lives in `framework/` and `tasks/`.
- **Separation of concerns** — The pipeline handles orchestration. Modules handle installation. `global_fn.sh` handles utilities.

## Structure

```
ravn/
├── setup.sh                    # Thin entrypoint (~15 lines)
├── global_fn.sh                # Symlink → ../global_fn.sh (runtime library)
│
├── framework/                  # Engine — orchestration, discovery, hooks
│   ├── discover.sh             # discover_tasks() via find
│   ├── pipeline.sh             # run_task() + run_pipeline()
│   ├── package.sh              # Default module contract
│   ├── hooks.sh                # Lifecycle hook detection
│   ├── state.sh                # Persistent state (skeleton)
│   └── retry.sh                # Retry re-export from global_fn.sh
│
├── tasks/                      # Installer modules (auto-discovered)
│   ├── 10-npm-apps/            # npm-backed CLI tools
│   ├── 80-app-configs/         # application configuration trees + launchers
│   ├── 20-curl-apps/           # HTTPS vendor shell-installer tasks
│   ├── 20-shell/               # Shell environment modules (reserved)
│   ├── 90-system/              # Final system configuration tasks
│   └── tasks_legacy/           # Quarantined core, npm, and system tasks
│
├── config/                     # Configuration files
│   ├── ravn.conf               # Framework settings
│   └── packages.conf           # Package enable/disable (active)
│
├── cache/                      # Runtime data (gitignored)
│   ├── logs/                   # Per-package log files
│   └── state/                  # Persistent state data
│
└── docs/                       # Documentation
    └── LIFECYCLE.md            # Module lifecycle reference
```

## Creating a Package

Create a new `.sh` file anywhere under `tasks/`. The framework discovers it automatically.

### Minimal Example

```bash
#!/usr/bin/env bash
PACKAGE="my-tool"
DESCRIPTION="Install my-tool from source"
CATEGORY="apps"

check() {
  command -v my-tool &>/dev/null
}

install() {
  sudo pacman -S --needed --noconfirm my-tool
}
```

### Full Example

```bash
#!/usr/bin/env bash
PACKAGE="example"
DESCRIPTION="Example package with full lifecycle"
CATEGORY="apps"
DEPENDS=("git" "curl")
INTERACTIVE=false

before() {
  mkdir -p "$HOME/.config/example"
}

check() {
  [[ -f "$HOME/.config/example/.installed" ]]
}

install() {
  git clone https://github.com/user/example "$HOME/.local/share/example"
}

after() {
  touch "$HOME/.config/example/.installed"
  info "Example installed. Run 'example --help' to get started."
}

cleanup() {
  rm -rf /tmp/example-build
}
```

### Module Contract

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `PACKAGE` | string | yes | `""` | Unique package name |
| `DESCRIPTION` | string | no | `""` | Human-readable description |
| `CATEGORY` | string | no | `""` | Logical grouping |
| `DEPENDS` | array | no | `()` | Dependencies (future) |
| `INTERACTIVE` | bool | no | `false` | Prompt user before install |

### Lifecycle

```
before() → check() → install() → after() → cleanup()
```

See [LIFECYCLE.md](docs/LIFECYCLE.md) for detailed documentation.

## Adding a Package

1. Choose the appropriate category directory under `tasks/`.
2. Create a new `.sh` file with a numeric prefix for ordering (e.g., `04-my-tool.sh`).
3. Define `PACKAGE`, `DESCRIPTION`, and at minimum `check()` + `install()`.
4. The framework discovers it on next run. No registration needed.

## Task Metadata Contract

New tasks must declare the metadata used by the task menu and test runner:

```bash
TASK_ID="my-tool"
TASK_FAMILY="cli-tools"          # baseline | cli-tools | desktop-apps | system-admin
INSTALLER_STRATEGY="mise"        # pacman | mise | omarchy-npx | flatpak | upstream | custom
TEST_LEVEL="isolated"             # static | isolated | live
```

The lifecycle contract requires `check()`, `install()`, `verify()`, `reset()`, and `verify_reset()`. Every task must own and implement both reset operations; the runner must never infer uninstall behavior. Existing tasks without the complete contract are treated as legacy until migrated; they must not be presented as fully verified.

## Non-interactive Baseline Mode

The dotfiles installer must invoke the entrypoint explicitly with:

```bash
bash Scripts/ravn/setup.sh --baseline
```

This mode discovers only tasks with `TASK_FAMILY="baseline"`, never opens a menu, never prompts, and returns a failure status when a selected baseline task cannot be verified. If no baseline tasks have been migrated yet, it exits successfully without running optional tasks.

## Running

```bash
# Run from the RaVN installer (automatic — called by install.sh)
bash Scripts/ravn/setup.sh

# Dry-run mode (inherits flg_DryRun from parent installer)
flg_DryRun=1 bash Scripts/ravn/setup.sh
```

## Testing administrative tasks

Administrative tasks are not package installers. Their completion is measured
by observable postconditions, ownership boundaries, permissions, recovery, and
reconciliation evidence. Use the isolated harness first:

```bash
bash Scripts/ravn/test-task-admin.sh admin-lifecycle --approve
bash Scripts/ravn/test-task-admin-batch.sh admin-batch --approve
```

Administrative evidence has three distinct levels:

| Level | Environment | Proves | Does not prove |
|---|---|---|---|
| Isolated | Temporary HOME on the host | Fixture lifecycle and result classification | Container or host isolation |
| Docker | Clean container with selected mounts | Reproducible lifecycle behavior and container isolation | Host configuration behavior |
| Host | Real HOME with explicit authorization | Backup, reconciliation, and host postconditions | Safety of an unreviewed invocation |

Run the Docker fixture harness after the isolated checks:

```bash
bash Scripts/ravn/test-task-admin-docker.sh admin-lifecycle --approve
```

Docker reports are stored separately from isolated and host reports. A Docker
result must never be described as host validation. If Docker is unavailable,
the harness prints `SKIP` and does not claim verification.

Isolated mode is the default and replaces `HOME` with a temporary directory.
It must cover read-only planning, explicit approval, apply, verification,
reset/reinstall, failure, partial verification, pending activation, and
unsupported verification. Administrative batch tests must also cover resource
conflicts, dependency ordering, rollback, skipped dependents, and explicitly
authorized independent continuation.

Host mode is a separate, opt-in operation. It must never be inferred from an
isolated test or from a missing flag:

```bash
bash Scripts/ravn/test-task-admin-host.sh --host ssh-config \
  --approve --authorize-host
```

The host runner performs a read-only preflight, verifies a recoverable backup,
then applies and verifies the task against the real `HOME`. Host evidence is
stored separately under `cache/admin-host-reports/`; isolated and Docker
evidence must not be presented as host validation. If verification fails, the
report must identify partial state, the backup, the activation boundary, and
the recovery action. A new SSH connection observes the effective configuration;
existing sessions are not claimed to have changed.

For the SSH reference task, run the dedicated Docker regression test as well:

```bash
bash Scripts/ravn/tests/03-ssh-config-docker.sh
```

Every canonical administrative task must provide a dedicated lifecycle test
and declare identity, execution profile, privilege requirement, dependencies,
ownership, capabilities, reversibility, activation boundary, postconditions,
evidence, and test level. The SSH reference task is the approved example.
Docker is the current isolation boundary. VM execution for privileged or
host-sensitive scenarios is future work and must not be implied by a passing
Docker test.

## Runtime Library

The framework uses `global_fn.sh` for all shared utilities:

| Function | Purpose |
|---|---|
| `info`, `success`, `warn_msg`, `error_msg`, `step` | Semantic logging with Unicode icons |
| `spin $pid "msg"` | Braille spinner animation |
| `run_with_status "msg" command` | Execute with spinner |
| `retry N command` | Exponential backoff retry |
| `download_file url [output]` | curl/wget abstraction |
| `clone_or_update_repo name repo dest ref [ssh]` | Git clone/update with retry |
| `pkg_installed pkg` | Check if pacman package is installed |
| `count_ok`, `count_fail`, `count_skip` | Installation counters |
| `print_summary "label"` | Dashboard summary box |
