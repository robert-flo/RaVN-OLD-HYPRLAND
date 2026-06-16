# Purpose

RavnVM is a streamlined development tool that provisions a QEMU/KVM virtual machine (NixOS-based) for testing RaVN branches and commits. Supports Arch Linux and NixOS host systems with AMD/Intel GPU passthrough.

# Ownership

Standalone contributor tool. Not invoked by the main installer pipeline.

# Local Contracts

- **Entry point**: `ravnvm.sh` is the single CLI script. It handles VM creation, startup, snapshot, and teardown.
- **Nix environment**: `default.nix` declares the Nix shell with QEMU, OVMF, and supporting dependencies.
- **Documentation**: `README.md` covers hardware requirements, quick start, environment variables, and GPU troubleshooting.
- **Host requirements**: x86_64 CPU with KVM support, 4 GB+ RAM, Mesa-compatible GPU (AMD or Intel preferred).

# Work Guidance

- All user-facing usage docs belong in `README.md`, not in code comments.
- Environment variables (`RAVN_VM_*`) control VM memory, CPU count, and branch selection — document any new ones in `README.md`.

# Verification

# Child DOX Index

This directory has no child boundaries.
