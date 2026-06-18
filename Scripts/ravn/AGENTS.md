# Purpose

Modular bootstrap framework (RaVN Framework v1) that replaces monolithic installer scripts with convention-driven, auto-discovered task modules. Orchestrates final system configuration and application setup through a lifecycle pipeline.

# Ownership

Owned by the RaVN installer pipeline. Called by `install.sh` as a replacement for `install_fnl.sh` + `install_custom.sh` during the final configuration phase.

# Local Contracts

- **Shebang**: All scripts use `#!/usr/bin/env bash`.
- **Module contract**: Every task under `tasks/` must define `PACKAGE` and `install()`. Optional: `DESCRIPTION`, `CATEGORY`, `DEPENDS`, `INTERACTIVE`, `before()`, `check()`, `after()`, `cleanup()`. Defaults are provided by `framework/package.sh`.
- **Discovery**: Modules are auto-discovered via `find tasks/ -name "*.sh" | sort`. No hardcoded arrays or registration functions.
- **Naming**: Category directories and files both use numeric prefixes for ordering (e.g., `00-core/01-omarchy.sh`). Categories sort first, then files within each category.
- **Dependency ordering**: `00-core/` runs before `10-apps/` by design. Modules in `10-apps/` that require `omarchy-npx-install` (codex, copilot, ghui, opencode, pi, playwright) depend on `00-core/01-omarchy.sh` completing first.
- **Lifecycle order**: `before → check → install → after → cleanup`. The `check()` function returns 0 to skip, 1 to proceed.
- **Interactive modules**: Set `INTERACTIVE=true` in the module header. The pipeline prompts for confirmation — modules must not prompt themselves.
- **Logging**: Per-package logs go to `cache/logs/<package>.log`.
- **State**: `cache/state/` is reserved for future persistent state via `state_get`/`state_set`.
- **Runtime library**: `global_fn.sh` is symlinked from the parent `Scripts/` directory and provides logging, spinners, counters, retry, download, and git helpers.
- **Counters**: Modules must not call `count_ok`/`count_fail`/`count_skip` directly. The pipeline handles counter increments based on lifecycle outcomes.

# Work Guidance

## Key files

| File | Role |
|---|---|
| `setup.sh` | Thin entrypoint — sources global_fn.sh, loads framework, calls main() |
| `global_fn.sh` | Symlink → `../global_fn.sh` (runtime library) |
| `framework/package.sh` | Default module contract (lifecycle stubs) |
| `framework/discover.sh` | `discover_tasks()` — find-based module discovery |
| `framework/pipeline.sh` | `run_task()` + `run_pipeline()` — lifecycle orchestration |
| `framework/hooks.sh` | `hook_defined()` + `run_hook()` — optional hook detection |
| `framework/state.sh` | `state_get/set/has` — key-value state (skeleton) |
| `framework/retry.sh` | Compatibility layer verifying `retry()` availability |

## Subdirectories

- `tasks/00-core/` — Core integrations (Omarchy, RaVN repo sync). Runs first.
- `tasks/10-apps/` — Application configs and CLI tools (Spicetify, Dotbare, TUI CLIs via npx)
- `tasks/20-shell/` — Shell environment modules (reserved)
- `tasks/30-system/` — System tweaks (firewall, SSH agent, SSH config). Runs last.
- `config/` — TOML configuration files
- `cache/logs/` — Per-package log output (gitignored)
- `cache/state/` — Persistent state data (gitignored)
- `docs/` — Documentation

## Adding a task module

1. Create `tasks/<category>/<NN>-<name>.sh` with `#!/usr/bin/env bash`.
2. Define `PACKAGE`, `DESCRIPTION`, and at minimum `check()` + `install()`.
3. The framework discovers it on next run. No registration or list updates needed.
4. Update this AGENTS.md only if adding a new category directory.

# Verification

```bash
# Syntax check all scripts
find Scripts/ravn -name "*.sh" -exec bash -n {} \;

# Dry-run the pipeline
flg_DryRun=1 bash Scripts/ravn/setup.sh
```

# Child DOX Index

None.
