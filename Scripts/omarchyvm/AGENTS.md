# Purpose

OmarchyVM is a standalone QEMU/KVM tool for installing Omarchy unattended in
an isolated VM (ISO + `cidata` drive, no wizard) and running the installed
system from a cached snapshot.

# Ownership

This directory owns the OmarchyVM CLI, interactive menu, cidata generation,
UEFI VM lifecycle, base snapshot, storage reporting, and executable tests. It
is not part of the main dotfiles installer pipeline.

# Local Contracts

- **Entry point**: `omarchyvm.sh` is the single executable interface.
- **Interactive menu**: no-argument execution validates the environment, then
  exposes ephemeral/persistent runs, base rebuild, storage, snapshots,
  resources, usage, and SSH.
- **Direct CLI**: preserve `--rebuild`, `--persist`, `--iso`, `--user`,
  `--password`, `--hostname`, `--timezone`, `--keymap`, `--list`, `--clean`,
  `--install-deps`, `--check-deps`, `--install-ssh-alias`, `--ssh`,
  `--build-cidata-only`, and `--help`. There are no positional arguments.
- **VM defaults**: use `VM_MEMORY=8G` and `VM_CPUS=4` unless overridden for the
  current invocation or session.
- **Unattended source of truth**: `build_cidata` synthesizes the
  configurator's own output files; its schema mirrors the official harness
  (`omarchy-iso` `test/integration.d/base-test.sh`). Installs are always
  unencrypted — LUKS needs a passphrase at boot and is not unattended.
- **ISO cache**: use `$XDG_CACHE_HOME/omarchyvm/`, preserving
  `omarchy-*.iso` when cleaning snapshots and temporary VM data.
- **SSH port**: default `2223` (not `2222`: ravnvm and the official
  `omarchy-iso-boot` already use `2222`); auto-fallback to the next free port
  via `ensure_ssh_port_free`.
- **SSH alias**: `Host omarchyvm`, separate from ravnvm's `Host ravnvm`.
- **Single VM session**: reject a second VM launch while another OmarchyVM
  process owns the session lock; keep read-only commands and SSH access
  available.
- **Make interface**: `make/omarchy.mk` is an alternative interaction surface
  over the same engine. Do not duplicate VM execution logic there.
- **Visual language**: preserve the shared numbered-menu convention: green
  selection key, Nerd Font icon, then action label; use the established section,
  prompt, status, and graceful-exit helpers.

# Interactive Menu Contract

The menu currently provides:

1. Run installed system (ephemeral), with a mode submenu for persistent choice.
2. Run installed system (persistent).
3. Rebuild base (unattended install).
4. Show VM storage usage.
5. Clean VM cache (preserves the ISO).
6. List snapshots.
7. Configure RAM and CPU for the current session.
8. Show the shared OmarchyVM usage information.
9. Connect to the running VM through SSH.
10. Install the optional `ssh omarchyvm` host alias.

Missing dependencies must be handled before the normal menu and may offer only
dependency installation or exit. Empty snapshots, failed cleanup, missing VMs,
invalid input, normal exit, and Ctrl-C must return clear feedback without
corrupting cached base data.

# Work Guidance

- Keep user-facing usage documentation in `README.md`; do not let help text and
  menu behavior drift from the executable contract.
- Reuse existing VM, cache, snapshot, SSH, and usage functions before adding
  new seams.
- Keep session resource changes in memory; do not create a persistent resource
  configuration file unless explicitly requested.
- When the official ISO or installer schema changes, update
  `OMARCHY_ISO_VERSION` and `build_cidata` together with the tests.
- Make changes on a feature branch and merge them through a PR.
- Keep commits focused and preserve unrelated user changes.

# Verification

Run the executable suite from the repository root:

```bash
Scripts/omarchyvm/tests/cidata.sh
Scripts/omarchyvm/tests/install-flow.sh
Scripts/omarchyvm/tests/menu.sh
```

Fixtures default to disk-backed `$XDG_CACHE_HOME/omarchyvm-tests` (never
`/tmp`/tmpfs, which is quota-prone); override with `OMARCHYVM_TEST_TMPDIR`.

Also run `bash -n`, `shellcheck`, `shfmt`, and the repository pre-commit hook.
Tests should exercise external behavior through the script with isolated cache
fixtures and mocked external commands where a real VM, download, or SSH
connection would otherwise be required. The 2GB sparse ISO fixture passes the
size sanity check without costing disk.

# Child DOX Index

This directory has no child boundaries.
