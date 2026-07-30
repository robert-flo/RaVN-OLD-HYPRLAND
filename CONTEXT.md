# RaVN Context

## Terms

- **User-only restoration**: The `install.sh -o` (or compatible `-ro`) workflow. It overwrites managed resources under `$HOME` without invoking sudo and omits privileged-capable phases.
- **Full restoration**: The existing `install.sh -r` workflow. It may restore system resources and acquire sudo when required.
- **Batch clone**: One `git-bare-clone` invocation that processes one or more destination groups. Each group maps a worktrees path to a list of repositories; existing repositories are skipped, while real clone failures stop the batch.
