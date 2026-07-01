# Emacs Integration — Progress Log

Live log of what has been ported from `joshuablais/nixos-config` into this
repo, and what's still open. Updated at the end of every session per
[INSTRUCTIONS.md](INSTRUCTIONS.md) §Step 7. Read this file at the start of
every session before doing anything else.

## Status legend

- ✅ Done — merged into `emacs` branch
- 🔶 In review — PR open against `emacs`, not yet merged
- ⏸️ Deferred — flagged during a session, intentionally postponed
- ❓ Open decision — needs the user's input before it can proceed

---

## Ported

| Source (`nixos-config`) | Destination (`RaVN`) | Status | PR / branch | Notes |
|---|---|---|---|---|
| `dotfiles/emacs/` | `Configs/.config/emacs/` | ✅ Done | N/A (Direct dev integration) | Main Emacs config tree |

## Open decisions

| Topic | Context | Status |
|---|---|---|
| `agenix` secrets (mu4e password, radicale, gnus, LLM API keys) | Josh reads these via `/run/agenix/*` or `pass LLMs/...`. User is evaluating `pass`/GPG as the Arch equivalent. | ❓ pending |
| Package equivalences (Nix pkg name → pacman/AUR name) | Decided one at a time as sessions hit them. | ❓ ongoing, no table kept preemptively |

## Deferred / not yet scheduled

_(populate as sessions surface dependencies on not-yet-ported modules —
e.g. "org-config.el references `org-caldav-sync`, which lives in
`custom/org-caldav-config.el`, not yet ported")_

## Known large subsystems (candidates for their own multi-session tracks)

Based on `dotfiles/emacs/README.org`'s module list — not started, listed
here only as a map for future `integra` targets, in a reasonable
dependency-aware order:

1. Core: `early-init.el`, `init.el`, `flash-config.el`, `completion.el`,
   `editing.el`, `grammars.el` (treesit/eglot), `keys.el`
2. Files/nav: `dired-config.el`, `workspaces.el`, `persist.el`
3. Terminal/launcher: `vterm-config.el`, `everywhere.el`,
   `emacs-launcher.go` (script), `universal-launcher.el` (custom)
4. Org core: `org-config.el`, `org-roam-config.el`, `org-caldav-config.el`
   (custom), `agenda-custom.el`
5. Writing/spelling: `writing.el`, `spelling.el`, `markdown.el`
6. Dev tooling: `development.el`, `magit-config.el`, `test-runner.el`,
   `guix-config.el` (likely skip — Guix-specific), `ledger-config.el`
7. Media/comms (bigger, likely lower priority per user's "100% del
   flujo" goal but still last in practice): `mail.el` (mu4e),
   `gnus-config.el`, `jabber-config.el`, `erc-config.el`,
   `elfeed-config.el`, `emms-config.el`, `reading.el` (nov/calibre/pdf)
8. Custom scripts (`lisp/custom/*`): `pomodoro.el`, `done-refile.el`,
   `create-daily.el`, `post-to-blog.el`, `posse-twitter.el`,
   `jitsi-meeting.el`, `gimp-tweet.el`, `jb-0x0.el`,
   `jb-clipboard-manager.el`, `nm.el`
9. Theming: `themes/compline-theme.el`, `themes/lauds-theme.el`
10. Snippets: `snippets/**` (per-mode, low-risk, batchable)
