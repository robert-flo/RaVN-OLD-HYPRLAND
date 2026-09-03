# OmarchyVM — Unattended Omarchy in QEMU/KVM

Installs Omarchy with nobody at the keyboard and runs the installed system
from a cached snapshot. It follows the official
[unattended installs](https://omarchy.org/manual/unattended-installs/) flow:
the script synthesizes the installer's own configuration files, masters them
onto a second drive labeled `cidata`, boots the Omarchy ISO alongside it, and
the installer skips the wizard, installs, and reboots into the finished
system on its own. SSH works immediately because `cidata`'s `authorized_keys`
makes the installer enable `sshd`.

**Supported hosts:** Arch Linux, Arch-based distros, NixOS.

## Hardware Requirements

- **CPU:** x86_64 with virtualization (Intel VT-x / AMD-V, enabled in BIOS)
- **Memory:** 16GB+ recommended on the host (VM uses 8GB by default)
- **Disk:** ~15GB free in `$XDG_CACHE_HOME` (7.5GB ISO + 40GB sparse disk + snapshot)
- **Firmware:** `edk2-ovmf` (UEFI boot, like real Omarchy hardware)

## Quick Start

```bash
Scripts/omarchyvm/omarchyvm.sh          # menu; installs on first run
make dev-omarchy-rebuild                # or: fresh unattended install directly
```

First run downloads the Omarchy ISO (~7GB, cached), builds `cidata`, boots
the installer, and polls SSH until the installed system answers. When SSH is
up the guest is powered off and the disk is cached as `omarchy-base.qcow2`.
Subsequent runs boot an overlay of that snapshot in seconds.

Default guest credentials: `arch / arch` (override with `--user`,
`--password`, or `OMARCHY_USER` / `OMARCHY_PASSWORD`). Your `~/.ssh/*.pub`
keys are installed automatically, so `ssh omarchyvm` needs no password.

## Usage

### Interactive menu

```
1  Run installed system (ephemeral)
2  Run installed system (persistent)
3  Rebuild base (unattended install)
4  Show VM storage usage
5  Clean VM cache
6  List snapshots
7  Configure RAM and CPU
8  Show OmarchyVM usage
9  Connect to VM via SSH
10 Install SSH alias
q  Exit
```

### Basic Commands

```bash
omarchyvm --rebuild                     # fresh unattended install
omarchyvm                               # run ephemeral (discards changes)
omarchyvm --persist                     # run persistent (saves changes)
omarchyvm --iso 4.0.2                   # pin ISO version
omarchyvm --iso https://.../omarchy-x.iso
omarchyvm --iso /path/to/omarchy.iso    # local ISO, skips download
omarchyvm --user alice --hostname vm1   # custom identity
omarchyvm --ssh                         # SSH into the running VM
```

### Make interface

```bash
make dev-omarchy                 # run ephemeral
make dev-omarchy-persist         # run persistent
make dev-omarchy-rebuild         # fresh unattended install
make dev-omarchy-list            # list snapshots
make dev-omarchy-clean           # clean cache (keeps ISO)
make dev-omarchy-setup           # check/install dependencies
make dev-omarchy-storage         # disk usage
make dev-omarchy-ssh             # SSH into the running VM
make dev-omarchy-install-ssh-alias
```

### Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `OMARCHY_ISO_VERSION` | `4.0.2` | ISO version for the default URL |
| `OMARCHY_ISO_URL` | `https://iso.omarchy.org/omarchy-4.0.2.iso` | Full URL override |
| `OMARCHY_ISO` | — | Local ISO path (skips download) |
| `OMARCHY_ISO_SHA256` | — | Optional checksum verification |
| `OMARCHY_USER` / `OMARCHY_PASSWORD` | `arch` / `arch` | Guest credentials |
| `OMARCHY_HOSTNAME` | `omarchy-vm` | Guest hostname |
| `OMARCHY_TIMEZONE` | host timezone or `UTC` | Guest timezone |
| `OMARCHY_KEYMAP` | `us` | Guest keyboard layout |
| `OMARCHY_FULL_NAME` / `OMARCHY_EMAIL` | — | Optional git identity in cidata |
| `OMARCHY_SSH_PORT` | `2223` | SSH forward port (auto-fallback if busy) |
| `OMARCHY_DISK_SIZE_GB` | `40` | Installed disk size |
| `OMARCHY_INSTALL_TIMEOUT` | `1800` | Seconds to wait for the install |
| `VM_MEMORY` / `VM_CPUS` | `8G` / `4` | VM resources |

## VM Details

- **Boot:** UEFI (`OVMF_CODE`/`OVMF_VARS`), `q35` machine, `virtio-blk` disk
  (`/dev/vda` — the `disk_config` in `cidata` targets it), `virtio` net/vga.
- **cidata:** ISO mastered with `genisoimage` (or `xorriso`), label `cidata`,
  attached as a second CD-ROM. Contents: `user_configuration.json`
  (archinstall full-disk layout, Limine, btrfs, no encryption),
  `user_credentials.json` (`openssl passwd -6` hash, never plaintext),
  `user_encrypt_installation.txt` (`false`),
  `authorized_keys` (host `~/.ssh/*.pub` + generated guest key),
  optional `user_full_name.txt` / `user_email_address.txt`.
- **SSH port** defaults to `2223` because `2222` is already taken by ravnvm
  and the official `omarchy-iso-boot`; if busy it falls back to the next
  free port automatically.
- **Cache** lives in `~/.cache/omarchyvm/`; `--clean` preserves the ISO.
- **Lock:** one VM at a time per `session.lock`.

## Troubleshooting

### Port in use

If the SSH port is busy you get `Port 2222 in use, using 2223 instead` and
the run continues. To pin one: `OMARCHY_SSH_PORT=2242 omarchyvm`.

### Install times out

The installer needs network (mirrors) and several minutes. Check
`~/.cache/omarchyvm/qemu.log`, raise `OMARCHY_INSTALL_TIMEOUT`, and retry
with `omarchyvm --rebuild`. A failed install never caches a snapshot.

### Encryption

Unattended installs are unencrypted by design: LUKS would stop at the
passphrase prompt on first boot. For an encrypted machine, install
interactively from the ISO instead.

### KVM Not Available

Without `/dev/kvm` the VM falls back to software emulation (slow). Add
yourself to the `kvm` group: `sudo usermod -a -G kvm $USER`, then relogin.

### Clean Start

```bash
omarchyvm --clean     # keeps the 7GB ISO
rm -rf ~/.cache/omarchyvm   # full reset, re-downloads the ISO
```
