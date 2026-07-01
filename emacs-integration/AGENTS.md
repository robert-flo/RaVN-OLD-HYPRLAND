# Purpose

Governs the initiative of porting Josh Blais' Emacs-centric workflow
(`joshuablais/nixos-config`, config profile **"Studium Emacs"**) into this
repository (`robert-flo/RaVN`), targeting Arch Linux + Hyprland instead of
NixOS. Scope is Emacs plus everything Emacs directly depends on: shell
(zsh), launcher scripts, and Hyprland keybinds that invoke Emacs.

This file is a DOX child document. It does not replace the root
`AGENTS.md` — all rules there (style, ShellCheck, DOX hierarchy, worktree
workflow, branching policy) still apply. This file adds rules specific to
**how source material is ported from `nixos-config` into `RaVN`.**

# Ownership

Owned by the user (`robert-flo`). The agent executes one atomic
integration per work session, on request, following
[INSTRUCTIONS.md](INSTRUCTIONS.md). Nothing here authorizes background or
speculative work outside an explicit session request.

# Source of Truth

- **Upstream source**: `https://github.com/joshuablais/nixos-config`
  - Canonical Emacs config: **`dotfiles/emacs/`** ("Studium Emacs",
    vanilla `use-package` + `elpaca`).
  - **`dotfiles/doom/` is legacy and MUST NOT be ported.** Verified by
    inspecting `modules/home-manager/dotfiles.nix` (only `.config/emacs`
    is symlinked, never `.config/doom`) and `modules/home-manager/
    emacs-wayland.nix` (`DOOMDIR`/`DOOMLOCALDIR` are commented out). If a
    future session finds this has changed upstream, stop and confirm with
    the user before proceeding — do not silently switch source trees.
  - Shell config: `dotfiles/zsh/.zshrc`, `dotfiles/zsh/.zprofile`.
  - Emacs-adjacent scripts: `dotfiles/hypr/scripts/emacs-launcher.go`
    (and its compiled `emacs-launcher` binary) — **do not** port the
    `dotfiles/sway/` twin, this project uses Hyprland only.
  - Hyprland binds that invoke Emacs: scattered across
    `dotfiles/hypr/*.conf` (grep for `emacs`, `emacsclient`,
    `emacs-launcher`).
- **Destination**: this repo, `robert-flo/RaVN`, following its existing
  `Configs/` mirror-of-`$HOME` layout and DOX rules from the root
  `AGENTS.md`.

# Path Mapping (nixos-config → RaVN)

| Source (relative to `nixos-config/`)         | Destination (relative to `RaVN/`)                | Notes |
|---|---|---|
| `dotfiles/emacs/`                            | `Configs/.config/emacs/`                         | Full Emacs config tree (init.el, early-init.el, lisp/, snippets/, themes/) |
| `dotfiles/zsh/.zshrc`                        | merge into `Configs/.config/zsh/.zshrc` + `Configs/.config/zsh/user.zsh` | RaVN's zsh is modular (`conf.d/`, `functions/`); do not blindly overwrite — see INSTRUCTIONS.md §Zsh handling |
| `dotfiles/zsh/.zprofile`                     | `Configs/.zprofile` (create if absent)           | Confirm no clash with `Configs/.config/zsh/.zshenv` |
| `dotfiles/hypr/scripts/emacs-launcher.go`    | `Configs/.local/bin/emacs-launcher` (compiled binary; keep `.go` source alongside or in a `src/` note) | RaVN has no `hypr/scripts/`; all executables live flat in `.local/bin/`, PATH-available |
| Emacs-related binds in `dotfiles/hypr/*.conf`| `Configs/.config/hypr/userprefs.conf`            | `userprefs.conf` is flag `P` (populate-once, never overwritten by upstream HyDE updates) — the only safe place for personal binds. **Never add Emacs binds to `keybindings.conf`** (flag `P` too, but conventionally owned by HyDE core, keep it clean) |

Package equivalences (Nix → Arch/AUR) are decided **by the user, one at a
time, as they come up** — do not pre-emptively write a package list. When
a session needs a package, ask or propose the `pacman`/AUR name and let
the user confirm before adding it to `Scripts/` package manifests.

# Local Contracts

- **One atomic unit per session.** A session begins when the user says
  `integra <path>`, where `<path>` is always relative to the root of
  `nixos-config`. It ends with a single PR from an isolated worktree into
  the `emacs` branch (never directly into `dev`, never directly into the
  live checkout). See [INSTRUCTIONS.md](INSTRUCTIONS.md) for the full
  procedure.
- **`emacs` branch is a long-lived integration branch**, analogous to a
  big feature branch. It sits between per-session worktree branches and
  `dev`. `RELEASE_POLICY.md` says PRs target `dev` — that rule is honored
  at the point where `emacs` itself gets merged into `dev` (a separate,
  user-triggered milestone), not on every atomic session.
- **Respect existing user changes.** Per the user: whatever the port
  overwrites in files the user already customized will be resolved
  step-by-step by the user, not pre-emptively avoided by the agent. The
  agent still must not silently clobber unrelated content — port only
  what the requested `<path>` covers.
- **Keybind conflicts are resolved in the moment**, not via a pre-built
  mapping table. When porting a bind, check `Configs/.config/hypr/
  keybindings.conf` and `Configs/.config/hypr/userprefs.conf` for the same
  key combo first. If taken, propose an alternative to the user in the
  session output and land the bind in `userprefs.conf` with a comment
  noting the original Josh Blais bind it replaces, e.g.:
  ```
  # from joshuablais/nixos-config dotfiles/hypr/*.conf — original: $mainMod, E
  bindd = $mainMod SHIFT, E, Open vterm frame, exec, emacsclient -n -e '(my/new-frame-with-vterm)'
  ```
- **Doom-isms must be de-Doomified.** Josh's `dotfiles/emacs/` is already
  vanilla (no `use-package!`, `map!`, `after!` macros from Doom), so this
  should rarely trigger — but if a session encounters Doom-only macros
  (leftover from copy-paste between his `doom/` and `emacs/` trees, which
  happens in his repo), rewrite them to plain `use-package`/
  `with-eval-after-load`/`define-key` before porting.
- **No `agenix`/NixOS-only mechanisms ported as-is.** Where Josh reads
  secrets via `agenix` (`/run/agenix/...`) or shells out to `nix eval` /
  `nixos-rebuild`, flag it clearly in the session output as needing a
  manual decision (the user is evaluating `pass`/GPG as the likely
  replacement) instead of guessing a translation.

# Work Guidance

- Follow [INSTRUCTIONS.md](INSTRUCTIONS.md) step by step. Do not skip the
  "read + report" step even for small files — the user reads the report
  before the agent writes anything.
- Update [PROGRESS.md](PROGRESS.md) at the end of every session — it is
  the only persistent memory of what has already been ported across
  sessions.
- When a session's target `<path>` is a directory, do not silently
  recurse into subsystems that deserve their own session (e.g. `integra
  dotfiles/emacs/lisp` should NOT also pull in `dotfiles/emacs/lisp/
  custom/mu4e`-style large subsystems in the same pass if they're
  independently substantial — list them and ask whether to split).
- If `dotfiles/emacs` gets created in `Configs/.config/emacs/` for the
  first time, that session must also create a DOX child doc at
  `Configs/.config/emacs/AGENTS.md` (Purpose/Ownership/Local Contracts/
  Work Guidance/Verification/Child DOX Index, per root DOX rules) and
  register it in `Configs/AGENTS.md`'s Child DOX Index. This
  `emacs-integration/AGENTS.md` governs the *porting process*; the new
  `Configs/.config/emacs/AGENTS.md` governs the *resulting config* going
  forward (day-to-day edits unrelated to porting).
- Register every new deployable path in `Scripts/restore_cfg.psv`
  (correct flag — see flag legend at the top of that file) as part of the
  same session, not as a follow-up.

# Verification

- Any new/changed `.sh` under `Configs/.local/bin/` must pass
  `shellcheck` and `shfmt -d` per root `AGENTS.md`.
- Any new/changed Emacs Lisp should at minimum byte-compile cleanly
  (`emacs -Q --batch -f batch-byte-compile <file>.el`) with no errors
  (warnings are acceptable and can be logged in `PROGRESS.md`).
- Hyprland config changes: reload with `hyprctl reload` (or equivalent)
  and confirm no duplicate-bind warnings in `hyprctl` logs before opening
  the PR.
- Before opening the PR, `git diff` inside the worktree must contain
  **only** the files relevant to the session's `<path>` — no incidental
  changes.

# Child DOX Index

- [INSTRUCTIONS.md](INSTRUCTIONS.md) — atomic, per-session procedure.
- [PROGRESS.md](PROGRESS.md) — live log of what has been ported, what's
  pending, and open decisions (package equivalences, keybind resolutions,
  agenix→pass decisions).
