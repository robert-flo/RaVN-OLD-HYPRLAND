# Purpose

Automation scripts for installing, updating, and restoring RaVN system state. Covers package management, service enablement, configuration deployment, version tracking, and data migrations.

# Ownership

Owned by the RaVN installer pipeline. All scripts are sourced or invoked by `install.sh` or run standalone by the user.

# Local Contracts

- **Shebang rule**: Standard scripts use `#!/usr/bin/env bash`. Migration scripts under `migrations/` use `#!/usr/bin/env sh` (POSIX compliant).
- **Pipeline Order**: Final configuration is handled by `ravn/setup.sh`, which replaces the legacy monolithic scripts (`install_fnl.sh` and `install_custom.sh`). It auto-discovers task modules under `ravn/tasks/` and runs them through the framework lifecycle pipeline. Core integrations (Omarchy, RaVN) run first via sorted numeric prefixes in `ravn/tasks/00-core/`.
- **Spinner Safe Invocation**: In scripts with `set -e` enabled, wrap `spin` invocations using `spin "$pid" "msg" || status=$?` to capture the exit status without triggering premature shell termination.
- **Restore system**: `restore_cfg.psv` is the tracking manifest for config deployment. `restore_cfg.sh` reads it. See root AGENTS.md § Configuration Tracking for flag semantics.
- **Version metadata**: `version.sh` exports repo metadata (`RAVN_VERSION`, `RAVN_BRANCH`, etc.) from git tags and commits.

# Work Guidance

## Key files

| File | Role |
|---|---|
| `global_fn.sh` | Shared library — logging, spinners, pkg helpers, git/download wrappers |
| `install.sh` | Main orchestrator — packages → services → configs → migrations → post-install |
| `install_pre.sh` | Pre-install checks and setup |
| `install_pkg.sh` | Package installation logic |
| `install_pst.sh` | Post-install tweaks |
| `install_fnl.sh` | Final system configuration tweaks (legacy). Superseded by `ravn/setup.sh` |
| `ravn/setup.sh` | RaVN Framework v1 entrypoint — modular bootstrap pipeline. See child DOX |
| `install_aur.sh` | AUR helper bootstrap |
| `chaotic_aur.sh` | Chaotic-AUR mirror configuration |
| `restore_cfg.sh` | Config deployment from `Configs/` via `restore_cfg.psv` |
| `restore_fnt.sh` | Font restoration from `Source/arcs/` |
| `restore_shl.sh` | Shell (zsh/fish/bash) environment setup |
| `restore_svc.sh` | Systemd service enablement via `restore_svc.lst` |
| `restore_thm.sh` | Theme restoration |
| `dotbare_init.sh` | Bare git repo init for dotfile tracking |
| `diff_cfg.sh` | Diff local configs against repo templates |
| `version.sh` | Git metadata and release-note generation |
| `uninstall.sh` | Removal / cleanup |
| `clean_test.sh` | VM test cleanup — deletes tracked configs and HyDE/RaVN remnants |

## Subdirectories

- `extra/` — Optional scripts: Flatpak install (`install_fpk.sh`), kernel module install (`install_mod.sh`), app restore (`restore_app.sh`), desktop link restore (`restore_lnk.sh`), drive mount helper (`drivext_mnt.sh`).
- `launchers/` — Webapp, TUI, and edge-browser launcher installer (`install_launchers.sh`). Manifests (`webapps.sh`, `tuis.sh`, `edge-webapps.sh`) list every entry installed via `omarchy-webapp-install`, `omarchy-tui-install`, and `ravn-browser-webapp-install`. To add a new persistent webapp or TUI, append a `ravn_webapp_install` / `ravn_tui_install` row to the matching manifest instead of authoring `.desktop` files by hand — the launcher regenerates and tracks them.
- `migrations/` — Version-tagged POSIX scripts run by `install.sh` during updates. Named `v<semver>.sh`.
- `ravn/` — RaVN Framework v1: modular bootstrap framework with auto-discovered task modules. See child DOX.
- `ravnvm/` — NixOS-based VM tool for testing RaVN branches. See child DOX.

## Adding a migration

1. Create `migrations/v<YY.M.P>.sh` with `#!/usr/bin/env sh`.
2. Keep logic POSIX compliant.
3. Print brief stdout messages explaining what the migration adjusts.

# Verification

# Child DOX Index

- [ravn/AGENTS.md](ravn/AGENTS.md) — RaVN Framework v1: modular bootstrap pipeline and task modules.
- [ravnvm/AGENTS.md](ravnvm/AGENTS.md) — NixOS VM tool for contributor testing.
