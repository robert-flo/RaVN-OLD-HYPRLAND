# Purpose

Governs the custom Emacs configuration ("Studium Emacs", vanilla use-package + elpaca) ported from joshuablais/nixos-config. It defines local contracts, work guidance, and verification for day-to-day edits of the Emacs configuration in RaVN.

# Ownership

Owned by the user (`robert-flo`).

# Local Contracts

- **Vanilla Setup**: Keep configuration modular and vanilla-compatible (no Doom-only macros).
- **Elpaca Package Manager**: Use `elpaca` + `use-package` for package management. After every `use-package` with `:demand t` in `lisp/**/*.el`, add `(elpaca-wait)` immediately below the closing form (same pattern as `magit-config.el`). Group consecutive `:demand t` blocks may share one wait after the last block in the group.
- **Path structure**:
  - `init.el` is the main entry point.
  - `early-init.el` handles startup optimization and core UI configurations.
  - `lisp/` houses standard configuration modules.
  - `lisp/custom/` houses custom Lisp functions and integrations.
  - `themes/` houses custom color themes.
  - `snippets/` houses YASnippet templates.

# Work Guidance

- Avoid adding Nix-specific packages or paths.
- Store sensitive values in `~/.authinfo.gpg` or retrieve them via the `pass` utility.
- When adding new modules, ensure they are required in `init.el` and registered in the `provide` form of the module file.
- **Hyprland global keybinds** call `~/.local/bin/` helpers, not inline `emacsclient`:
  - `emacs-launcher` — workspace switch + Elisp command (Go binary, respects ignore-errors)
  - `emacs-launch-frame` — Super+Shift+E new GUI frame
  - `emacs-new-vterm-frame` — Super+E vterm frame
  - `emacs-everywhere` — Super+Ctrl+E `thanos/type` (no workspace switch)
- **Emacs startup**: Emacs is launched directly from Hyprland (`exec-once = emacs` in `userprefs.conf`) after importing Wayland environment variables into systemd. The Emacs server starts automatically via `(server-start)` hook in `tools.el`. No systemd daemon unit is used.
- **External service setup** (pass, mu4e, EMMS): see [SERVICE-SETUP.md](SERVICE-SETUP.md).
- **mu4e per-user config**: copy `lisp/custom/mail-user.el.example` → `mail-user.el`; host needs `~/Mail`, `~/.mbsyncrc`, `~/.msmtprc`, `mu index`

# Verification

- Byte-compile check: run `emacs -Q --batch -f batch-byte-compile <file>.el` on any modified Lisp files to ensure there are no compilation errors.

# Child DOX Index
