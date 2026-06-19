# Purpose

Source of truth for clean configuration files and templates that populate the user's `$HOME`. Mirrors the target filesystem layout (`$HOME/.config/`, `$HOME/.local/`, `$HOME/.bashrc`, etc.) so `restore_cfg.sh` can deploy them verbatim.

# Ownership

Owned by the RaVN installer pipeline. Changes here propagate to user systems on install/update.

# Local Contracts

- **Mirror layout**: Directory structure under `Configs/` must match the target path relative to `$HOME`. If a file deploys to `$HOME/.config/hypr/hyprland.conf`, it lives at `Configs/.config/hypr/hyprland.conf`.
- **Tracking**: Every deployable file or directory must have a corresponding row in [restore_cfg.psv](../Scripts/restore_cfg.psv) with the appropriate flag (`P`, `S`, `O`, `B`, or `I`).
- **Sync direction**: Active system configs flow back here via `dotbare-sync` / `sync_back.sh`. Never hand-edit a config in `Configs/` if the live version in `$HOME` is the authoritative copy — sync it back first.
- **No runtime artifacts**: This directory holds only clean template state. Do not commit generated caches, sockets, or runtime data.

# Work Guidance

- Shell config files (`.bashrc`, `.zshenv`, `.profile`) live at the `Configs/` root.
- Application configs live under `Configs/.config/<app>/`.
- Local binaries and desktop entries live under `Configs/.local/`.
- After adding or removing a config target, update `restore_cfg.psv` and verify with `restore_cfg.sh --dry-run` when available.

# Verification

# Child DOX Index

- [.local/bin/AGENTS.md](.local/bin/AGENTS.md) — Local binaries, system controls, and Git worktree helper tools.
