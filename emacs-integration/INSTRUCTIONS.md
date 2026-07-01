# Emacs Integration — Session Procedure

This is the exact, repeatable procedure for one work session. Read
[AGENTS.md](AGENTS.md) first for the rules; this document is the checklist
that executes them.

A session always starts with the user typing:

```
integra <path>
```

where `<path>` is relative to the root of `joshuablais/nixos-config`
(e.g. `dotfiles/emacs/lisp/org-config.el`, `dotfiles/emacs/early-init.el`,
`dotfiles/hypr/scripts/emacs-launcher.go`).

---

## Step 0 — Confirm source state (once per session, cheap)

1. If a local clone of `nixos-config` isn't already available in the
   working environment, fetch the current `<path>` content — via a fresh
   shallow clone, or `git show`/raw fetch of just that path if a clone
   already exists and is reasonably fresh. Don't assume yesterday's clone
   is current; Josh's repo is a literate/active config that changes often.
2. If `<path>` doesn't exist at that exact location anymore (renamed/
   moved/deleted upstream), stop and tell the user — do not guess a
   nearby file.

## Step 1 — Read and classify

1. Read the full contents of `<path>` (and, if it's a directory, list
   everything inside — don't summarize from memory of the earlier repo
   dump).
2. Classify what it is:
   - Emacs Lisp module (`lisp/*.el`, `early-init.el`, `init.el`)
   - Snippet (`snippets/**`)
   - Theme (`themes/*.el`)
   - Zsh (`.zshrc`, `.zprofile`)
   - Script (`hypr/scripts/emacs-launcher.go`)
   - Hyprland bind fragment (a `.conf` or a bind line pasted by the user)
3. Check for **Doom-isms** (`use-package!`, `map!`, `after!`, `:leader`,
   `set-file-template!`, etc.). If found, note that de-Doomification is
   needed before porting — see AGENTS.md.
4. Check for **NixOS-only mechanisms**: `agenix`, `/run/agenix/`, `nix
   eval`, `nixos-rebuild`, `pass LLMs/...` calls, hardcoded Nix store
   paths (`/nix/store/...`), `(executable-find "nixd")`-style Nix-tooling
   lookups. List every one found — do not silently drop or silently
   translate them.
5. Check for **hard dependencies on other, not-yet-ported modules**
   (e.g. a `lisp/org-config.el` that calls a function defined in
   `lisp/custom/pomodoro.el`). List them; don't pull them in
   automatically — flag as a dependency for the user to decide whether to
   integrate now or stub out.

## Step 2 — Report before writing anything

Present to the user, before touching any file:

1. **What this is** (1–2 lines).
2. **Where it will live** in RaVN (exact destination path, per the
   mapping table in `AGENTS.md`, or a proposed new entry if the mapping
   table doesn't cover it yet).
3. **What already exists there**, if anything (does the destination file/
   dir exist? Is it empty, HyDE-stock, or already user-customized?).
4. **Doom-isms found** (if any) and the plain-Emacs-Lisp rewrite plan.
5. **NixOS-only mechanisms found** (if any) and a proposed manual
   decision point (e.g. "this reads a password via `agenix`; you said
   you're evaluating `pass` — should I write a `pass`-based stub, or
   leave a `TODO` and skip that one form for now?").
6. **Keybind conflicts** (if the unit includes a Hyprland bind): check
   against `Configs/.config/hypr/keybindings.conf` and `userprefs.conf`,
   report any clash and a proposed alternative.
7. **Dependencies on unported modules** (if any).

Wait for the user's go-ahead (or answers to the flagged questions) before
Step 3. Small, obviously-safe units (e.g. a single self-contained snippet
file) can get a lighter version of this report, but never skip it
entirely.

## Step 3 — Create the worktree

```bash
git-create-worktree -r <path-to-RaVN-repo> \
  -b "emacs/<short-slug>" \
  -B "emacs" \
  "<short-slug>"
```

- `<short-slug>` describes the unit, e.g. `org-config`,
  `emacs-launcher-script`, `zshrc-editor-env`.
- Base branch is `emacs`, **not** `dev`/`main`. If the `emacs` branch
  doesn't exist yet (first-ever session), create it first from `dev`:
  ```bash
  git branch emacs origin/dev
  git push -u origin emacs
  ```
  then run `git-create-worktree` as above.

## Step 4 — Port the content

1. Write the destination file(s) inside the worktree, applying:
   - De-Doomification rewrites agreed in Step 2.
   - Path/variable adjustments (e.g. `~/.config/doom` → n/a; NixOS
     `executable-find` shell-outs → plain binary names available via
     `pacman`).
   - Any manual-decision stubs/TODOs agreed with the user for
     NixOS-only mechanisms.
2. If this is the **first** time `Configs/.config/emacs/` is created,
   also create `Configs/.config/emacs/AGENTS.md` per the DOX Child Doc
   Shape (Purpose/Ownership/Local Contracts/Work Guidance/Verification/
   Child DOX Index) and add a line for it in `Configs/AGENTS.md`'s Child
   DOX Index.
3. Register the new/changed path(s) in `Scripts/restore_cfg.psv` with the
   correct flag (see the legend at the top of that file — `S` for things
   that should always sync from the repo, `P` for things the user may
   customize locally and shouldn't be clobbered on update, `O` for
   binaries in `.local/bin/`).
4. If a Hyprland bind is part of this unit, add it to
   `Configs/.config/hypr/userprefs.conf` with the provenance comment
   format shown in `AGENTS.md`.

## Step 5 — Verify

Run the checks listed in `AGENTS.md`'s Verification section relevant to
what changed:

- `.el` files: byte-compile check.
- `.sh` / `.go`-adjacent shell wrappers: `shellcheck` + `shfmt -d`.
- Hyprland conf changes: reload and check for duplicate-bind warnings.
- `git diff` in the worktree touches only what this session's `<path>`
  covers.

If verification fails, fix within the same session before opening the PR
— don't open a red PR.

## Step 6 — Open the PR

1. Commit with a message describing exactly what was ported and from
   where, e.g.:
   ```
   emacs: port dotfiles/emacs/lisp/org-config.el → Configs/.config/emacs/lisp/org-config.el

   Source: joshuablais/nixos-config @ <commit-sha-if-known>
   ```
2. Push the branch and open a PR **into `emacs`** (not `dev`).
3. In the PR description, restate the Step 2 report (what/where/
   conflicts/open decisions) so it's reviewable without re-reading the
   session transcript.

## Step 7 — Update PROGRESS.md

Before ending the session, append an entry to `PROGRESS.md`:

- Source path integrated.
- Destination path(s).
- PR link/branch name.
- Any open decisions deferred (agenix→pass, package name TODOs, keybind
  alternatives chosen).
- Any discovered dependencies on not-yet-ported modules, so the next
  session can pick them.

---

## Syncing `emacs` → `dev`

This is a **separate, user-triggered milestone**, not part of every
session. When the user decides the `emacs` branch is ready (a logical
checkpoint — e.g. "core Emacs config is usable now"), open a normal PR
from `emacs` into `dev` per `RELEASE_POLICY.md`. The agent should not
initiate this on its own; only when asked.

## Handling `<path>` that is a whole directory

When `<path>` is a directory rather than a single file:

1. List every file inside it (recursively, one level of judgment at a
   time — don't blindly recurse into large independent subsystems, see
   AGENTS.md's Work Guidance).
2. If it's small and cohesive (e.g. `dotfiles/emacs/snippets/org-mode/`),
   treat the whole directory as one session/one PR.
3. If it's large or contains independently substantial subsystems (e.g.
   `dotfiles/emacs/lisp/` contains `mail.el`, `gnus-config.el`,
   `emms-config.el`, `org-roam-config.el` — each a real subsystem), stop
   and propose a split into multiple sessions, ordered by dependency
   (e.g. core editing/completion before mail/music/social).

## Zsh handling (special case)

RaVN's zsh is modular (`Configs/.config/zsh/conf.d/`,
`Configs/.config/zsh/functions/`, `Configs/.config/zsh/user.zsh`), while
Josh's is a single `.zshrc`. Do not overwrite RaVN's `.zshrc` wholesale.
Instead:

1. Read Josh's `.zshrc` line by line, classify each block (aliases, env
   vars, functions, `EDITOR`/`VISUAL` exports, `emacsclient` wrappers,
   plugin/prompt config already covered by RaVN's existing stack).
2. Skip anything RaVN's stack (starship, its own plugin manager, etc.)
   already provides in an equivalent way — flag it in the Step 2 report
   instead of duplicating.
3. Port the rest into the matching RaVN location:
   - Emacs-specific env/aliases/functions → a new
     `Configs/.config/zsh/functions/emacs.zsh` or a clearly-marked block
     in `Configs/.config/zsh/user.zsh` (ask the user which they prefer
     the first time this comes up, then reuse that decision).
   - Register in `restore_cfg.psv` accordingly.
