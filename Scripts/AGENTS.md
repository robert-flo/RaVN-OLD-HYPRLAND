# Purpose

Automation scripts for installing, updating, and restoring RaVN system state. Covers package management, service enablement, configuration deployment, version tracking, and data migrations.

# Ownership

Owned by the RaVN installer pipeline. All scripts are sourced or invoked by `install.sh` or run standalone by the user.

# Local Contracts

- **Shebang rule**: Standard scripts use `#!/usr/bin/env bash`. Migration scripts under `migrations/` use `#!/usr/bin/env sh` (POSIX compliant).
- **Shared library**: Source `global_fn.sh` via `source "${scrDir}/global_fn.sh"` at the top of every script that needs logging, spinners, or package helpers. Do not redefine those utilities locally.
- **Package lists**: `pkg_core.lst` and `pkg_extra.lst` define installable packages. `install_pkg.lst` is the resolved list consumed at install time. Use `install_pkg.sh` to process them.
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
| `install_fnl.sh` | Final setup and cleanup |
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

## Subdirectories

- `extra/` — Optional scripts: Flatpak install (`install_fpk.sh`), kernel module install (`install_mod.sh`), app restore (`restore_app.sh`), desktop link restore (`restore_lnk.sh`), drive mount helper (`drivext_mnt.sh`).
- `migrations/` — Version-tagged POSIX scripts run by `install.sh` during updates. Named `v<semver>.sh`.
- `ravnvm/` — NixOS-based VM tool for testing RaVN branches. See child DOX.

## Adding a migration

1. Create `migrations/v<YY.M.P>.sh` with `#!/usr/bin/env sh`.
2. Keep logic POSIX compliant.
3. Print brief stdout messages explaining what the migration adjusts.

# Verification

# Child DOX Index

- [ravnvm/AGENTS.md](ravnvm/AGENTS.md) — NixOS VM tool for contributor testing.
