# OmarchyVM — Disposable Omarchy in One Command

> **Pitch:** Omarchy already knows how to install itself with nobody at the
> keyboard ([unattended installs](https://omarchy.org/manual/unattended-installs/)).
> OmarchyVM is the other half of that story: a single dependency-free shell
> script that turns the unattended installer into **disposable, snapshot-backed
> development VMs**. `make dev-omarchy-rebuild` once, then boot a pristine
> Omarchy in seconds — for testing dotfiles, previewing releases, or handing
> a contributor a known-good machine without touching bare metal.

```bash
make dev-omarchy-rebuild   # install once, unattended (~6 min, walk away)
make dev-omarchy           # boot pristine Omarchy, ephemeral (seconds)
make dev-omarchy-persist   # boot it with changes saved
```

No wizard. No USB stick. No second physical machine. The VM reboots itself
into the finished system, SSH is up on arrival, and every run after the first
boots from a cached snapshot.

---

## Why this exists

Testing anything against real Omarchy today means one of:

1. Installing on bare metal (slow, destructive),
2. Clicking through the ISO wizard in a VM by hand (slow, unrepeatable), or
3. Reading the `omarchy-iso` integration harness (powerful, but built for CI —
   QMP screendumps, OCR, `imv` reviews — not for humans).

The unattended-install machinery removed the *need* for hands on keyboard, but
nothing packaged it for *daily development*. OmarchyVM is that packaging: the
official `cidata` contract, a stock QEMU invocation, and the snapshot workflow
every developer already expects from tools like Vagrant — in ~1,500 lines of
bash with zero runtime dependencies beyond QEMU itself.

## How it works

```
┌──────────┐   ┌──────────┐   ┌───────────────────────┐   ┌──────────────┐   ┌───────────┐
│ ISO cache │ + │  cidata  │ → │ QEMU (UEFI, ISO+cidata│ → │ SSH answers? │ → │ snapshot  │
│  4.0.2    │   │   .iso   │   │  as two CD-ROMs)      │   │ = installed  │   │ base.qcow2│
└──────────┘   └──────────┘   └───────────────────────┘   └──────────────┘   └───────────┘
                                                                     │              │
                                                              timeout → fail,        ▼
                                                              never cache      ephemeral overlay
                                                              a broken base    or persistent disk
```

1. **ISO** — `https://iso.omarchy.org/omarchy-4.0.2.iso` is downloaded once
   (~6 GB) into `~/.cache/omarchyvm/` and reused. `curl -C -` resumes, files
   under 1 GB are rejected as error pages, `OMARCHY_ISO_SHA256` verifies when
   set. A local file (`--iso /path/a.iso`, `OMARCHY_ISO=`) skips the network.
2. **cidata** — the script synthesizes the configurator's *own* output files
   (same schema as the official `omarchy-iso` integration harness,
   `test/integration.d/base-test.sh`) and masters them with `genisoimage`
   (or `xorriso`) onto a drive labeled `cidata`:
   - `user_configuration.json` — archinstall full-disk layout for `/dev/vda`
     (2 GiB ESP + btrfs `@`, `@home`, `@log`, `@pkg`), Limine, hostname,
     timezone, keyboard, Omarchy mirrors. **No `disk_encryption` block — by
     design** (see below).
   - `user_credentials.json` — username + `openssl passwd -6` hash. The
     plaintext password never touches disk outside the process environment.
   - `user_encrypt_installation.txt` — `false`, matching the absent
     encryption block (the flag drives SDDM autologin, not LUKS).
   - `authorized_keys` — your `~/.ssh/*.pub` plus a generated guest key.
     This is what makes the installer enable `sshd` and open the firewall,
     so SSH works on first boot with no further steps.
   - Optional `user_full_name.txt` / `user_email_address.txt` when
     `OMARCHY_FULL_NAME` / `OMARCHY_EMAIL` are set.
   Both JSON files are validated with `python3 -m json` before mastering —
   a malformed config fails in milliseconds, not six minutes into an install.
3. **QEMU** — UEFI (`OVMF_CODE`/`OVMF_VARS`, `q35`, KVM), 40 GB `virtio-blk`
   disk (`/dev/vda`, exactly what `disk_config` targets), ISO + cidata as two
   ATAPI drives on an explicit AHCI controller, `virtio` net with host SSH
   forwarding. The empty disk falls through to the ISO on first boot; the
   installer finds `cidata`, skips the wizard, installs, and reboots alone.
4. **Completion signal** — full-auth SSH with the guest key. The live ISO
   environment carries no such key, so the first successful login *is* the
   proof that the installed system is up. No OCR, no fixed sleeps, no guessing
   from screenshots. Timeout (default 30 min) fails loudly and **never caches
   a broken base**.
5. **Snapshot** — the guest is powered off over SSH, the build disk is
   `qemu-img convert`ed to `snapshots/omarchy-base.qcow2`, and every later run
   boots a throwaway overlay (ephemeral) or the base itself (persistent).

### What you need to provide

Nothing. Defaults are a working developer machine:

| You give | Default | How |
|---|---|---|
| Nothing | user `arch` / password `arch`, host `omarchy-vm`, your host timezone (else UTC), `us` keyboard | just run it |
| SSH access | auto-collected from `~/.ssh/*.pub` | `ssh omarchyvm` needs no password |
| A newer ISO | `4.0.2` pinned, one variable to bump | `--iso 4.1.0` or `OMARCHY_ISO_VERSION=` |
| Your identity | omitted unless asked | `OMARCHY_FULL_NAME=` / `OMARCHY_EMAIL=` |
| A custom network port | `2223` (see below) | `OMARCHY_SSH_PORT=` |

```bash
omarchyvm --rebuild                                        # defaults
omarchyvm --rebuild --user alice --hostname vm1            # yours
OMARCHY_KEYMAP=es OMARCHY_TIMEZONE=Europe/Madrid omarchyvm --rebuild
```

## Design decisions (and their receipts)

- **Unencrypted installs only.** LUKS stops at a passphrase prompt on first
  boot — the opposite of unattended. The manual says the same; we enforce it
  by never emitting a `disk_encryption` block.
- **SSH on `2223`, with auto-fallback.** `2222` is already claimed by the
  official `omarchy-iso-boot` and sibling tooling. If the port is busy the
  script takes the next free one and tells you, instead of dying in
  `Could not set up host forwarding` — or worse, SSHing into *someone else's
  VM* that answered the port probe.
- **QEMU runs in its own process group (`setsid`).** Killing a bare PID
  orphans wrapper children that hold the caller's pipes open, hanging any
  `$(omarchyvm …)` capture forever. Group-kill reaps the whole tree; found
  the hard way, covered by `tests/install-flow.sh`.
- **`genisoimage` over `mtools`.** The manual's own recipe; one fewer
  dependency class, `xorriso` as fallback.
- **No daemon, no config file, no database.** Session resources live in
  memory, state is files in `~/.cache/omarchyvm/`, one VM at a time behind a
  `flock` — the same contract as the rest of this repo's tooling.

## Requirements

Arch Linux (or derivative) / NixOS · `qemu-desktop` · `edk2-ovmf` ·
`cdrtools` (or `libisoburn`) · `curl` · `openssh` · `openssl` · `python` ·
KVM recommended (`/dev/kvm`, else software emulation). ~15 GB free cache.

```bash
omarchyvm --check-deps     # verify
omarchyvm --install-deps   # install on Arch (sudo)
```

## Full command reference

```
omarchyvm                  menu (installs on first run)
omarchyvm --rebuild        fresh unattended install, re-cache the base
omarchyvm                  run ephemeral (changes discarded)
omarchyvm --persist        run persistent (changes saved)
omarchyvm --iso VER|URL|PATH
omarchyvm --user/--password/--hostname/--timezone/--keymap
omarchyvm --list / --storage / --clean (keeps the ISO)
omarchyvm --ssh / --install-ssh-alias / --check-deps / --install-deps
omarchyvm --build-cidata-only   (build + validate cidata, exit; used by tests)
```

Make equivalents: `dev-omarchy{,-persist,-rebuild,-list,-clean,-setup,-storage,-ssh,-install-ssh-alias}`
(`DRY_RUN=1` previews). Defaults: `OMARCHY_VM_MEMORY=8G`, `OMARCHY_VM_CPUS=4`.

## Verification

```bash
Scripts/omarchyvm/tests/cidata.sh        # schema, hashing, key collection
Scripts/omarchyvm/tests/install-flow.sh  # hostfwd failure, SSH timeout, no partial snapshots
Scripts/omarchyvm/tests/menu.sh          # surfaces, resources, make targets, recovery
```

Plus `bash -n`, `shellcheck` (zero findings), `shfmt`, and the repo
pre-commit hook. Fixtures are hermetic (fake QEMU/SSH/ISO) and live on real
disk (`~/.cache/omarchyvm-tests`, never tmpfs). What the suite deliberately
does *not* do is a full 6 GB install per run — that path is exercised by hand
(`make dev-omarchy-rebuild`: ISO + cidata attached, installer ran wizardless,
SSH came up, base cached).

## Non-goals

- Encrypted unattended installs (impossible without a human at boot).
- Fleet provisioning at scale (use the Proxmox/Packer flow from the manual).
- Replacing `omarchy-iso`'s CI harness (different job: machines, not eyeballs).

## Compatibility note

`user_configuration.json` tracks the installer's archinstall schema
(currently `"version": "3.0.9"`). When the ISO side changes it, bump
`OMARCHY_ISO_VERSION` and `build_cidata` together — `Scripts/omarchyvm/AGENTS.md`
records the procedure, and `cidata.sh` pins the fields that must survive.
