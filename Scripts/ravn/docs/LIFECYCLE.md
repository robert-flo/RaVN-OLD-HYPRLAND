# RaVN Framework v1 — Task Lifecycle

Each task module goes through a well-defined lifecycle managed by the framework pipeline.

## Lifecycle Phases

```
┌─────────┐    ┌─────────┐    ┌───────────┐    ┌─────────┐    ┌───────────┐
│ before() │───▶│ check() │───▶│ install() │───▶│ after() │───▶│ cleanup() │
└─────────┘    └─────────┘    └───────────┘    └─────────┘    └───────────┘
                    │                                               ▲
                    │ returns 0                                     │
                    └── SKIP ── count_skip ─────────────────────────┘
```

### `before()`
**Optional.** Runs before the check phase. Use for:
- Creating required directories
- Fetching prerequisite keys or data
- Validating environment conditions

### `check()`
**Required semantics.** Determines whether the task should run:
- Return `0` → package is already installed/configured → **skip**
- Return `1` → package needs installation → **proceed**

### `install()`
**Required.** The main installation logic. This is where the actual work happens.

### `after()`
**Optional.** Post-installation configuration. Use for:
- Setting default configurations
- Printing usage instructions
- Linking configuration files

### `cleanup()`
**Optional.** Always runs, even on failure. Use for:
- Removing temporary files
- Restoring modified state

## Interactive Modules

Set `INTERACTIVE=true` in the module header. The framework will:
1. Prompt the user for confirmation before running
2. Skip gracefully if the user declines

The interactive prompt logic lives entirely in the framework — not in the module.

## Dry-Run Mode

When `flg_DryRun=1`, the pipeline skips execution and logs the skip. Individual modules do not need to handle dry-run logic.
