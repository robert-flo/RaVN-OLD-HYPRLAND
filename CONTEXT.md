# RaVN Context

## Terms

- **User-only restoration**: The `install.sh -o` (or compatible `-ro`) workflow. It overwrites managed resources under `$HOME` without invoking sudo and omits privileged-capable phases.
- **Full restoration**: The existing `install.sh -r` workflow. It may restore system resources and acquire sudo when required.
