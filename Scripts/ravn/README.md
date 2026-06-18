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
│   ├── 00-core/                # Core integrations (Omarchy, RaVN) — runs first
│   ├── 10-apps/                # Application configs + CLI tools (npx, curl)
│   ├── 20-shell/               # Shell environment modules (reserved)
│   └── 30-system/              # System tweaks (firewall, SSH) — runs last
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

## Running

```bash
# Run from the RaVN installer (automatic — called by install.sh)
bash Scripts/ravn/setup.sh

# Dry-run mode (inherits flg_DryRun from parent installer)
flg_DryRun=1 bash Scripts/ravn/setup.sh
```

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
