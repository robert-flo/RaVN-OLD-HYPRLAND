# Purpose

Modular bootstrap framework (RaVN Framework v1) that replaces monolithic installer scripts with convention-driven, auto-discovered task modules. Orchestrates final system configuration and application setup through a lifecycle pipeline.

# Ownership

Owned by the RaVN installer pipeline. Called by `install.sh` as a replacement for `install_fnl.sh` + `install_custom.sh` during the final configuration phase.

# Local Contracts

- **Shebang**: All scripts use `#!/usr/bin/env bash`.
- **Module contract**: Every task under `tasks/` must define `PACKAGE` and `install()`. Optional: `DESCRIPTION`, `CATEGORY`, `DEPENDS`, `INTERACTIVE`, `before()`, `check()`, `after()`, `cleanup()`. Defaults are provided by `framework/package.sh`.
- **Discovery**: Modules are auto-discovered via `find tasks/ -name "*.sh" | sort`. No hardcoded arrays or registration functions.
- **Naming**: Category directories and files both use numeric prefixes for ordering (e.g., `00-core/01-omarchy.sh`). Categories sort first, then files within each category.
- **Dependency ordering**: `00-core/` runs before `10-apps/` by design. Modules in `10-apps/` that require `omarchy-npx-install` (codex, copilot, ghui, opencode, playwright) depend on `00-core/01-omarchy.sh` completing first.
- **Omarchy channel**: `00-core/00-omarchy-repo.sh` pins the `[omarchy]` repository to the `edge` channel and is idempotent — it skips when the correct block is already present in `/etc/pacman.conf`. It does not replace the existing `pacman.conf` or the system mirrorlist. The repository is configured early (before `install_pkg.sh`) so that Omarchy packages can be resolved during the main install phase.
- **Shared helpers**: `lib/omarchy.sh` contains `setup_omarchy_repo()` and `omarchy_repo_is_configured()` used by both the early repo task and the full `00-core/01-omarchy.sh` task.
- **Lifecycle order**: `before → check → install → after → cleanup`. The `check()` function returns 0 to skip, 1 to proceed.
- **Interactive modules**: Set `INTERACTIVE=true` in the module header. The pipeline prompts for confirmation — modules must not prompt themselves.
- **Logging**: Per-package logs go to `cache/logs/<package>.log`.
- **State**: `cache/state/` is reserved for future persistent state via `state_get`/`state_set`.
- **Runtime library**: `global_fn.sh` is symlinked from the parent `Scripts/` directory and provides logging, spinners, counters, retry, download, and git helpers.
- **Counters**: Modules must not call `count_ok`/`count_fail`/`count_skip` directly. The pipeline handles counter increments based on lifecycle outcomes.
- **Shell Quality Gate**: **Obligatorio** ejecutar `shellcheck` (y `shfmt`) en **todos** los archivos `.sh` antes de hacer commit. El pre-commit hook bloquea cualquier warning de shellcheck. No se permiten excepciones sin justificación explícita.

# Work Guidance

## Key files

| File | Role |
|---|---|
| `setup.sh` | Thin entrypoint — sources global_fn.sh, loads framework, calls main() |
| `global_fn.sh` | Symlink → `../global_fn.sh` (runtime library) |
| `framework/package.sh` | Default module contract (lifecycle stubs) |
| `framework/discover.sh` | `discover_tasks()` — find-based module discovery |
| `framework/pipeline.sh` | `run_task()` + `run_pipeline()` — lifecycle orchestration |
| `framework/hooks.sh` | `hook_defined()` + `run_hook()` — optional hook detection |
| `framework/state.sh` | `state_get/set/has` — key-value state (skeleton) |
| `framework/retry.sh` | Compatibility layer verifying `retry()` availability |

## Subdirectories

- `tasks/00-core/` — Core integrations (Omarchy, RaVN repo sync). Runs first.
- `tasks/10-apps/` — Application configs and CLI tools (Spicetify, Dotbare, TUI CLIs via npx)
- `tasks/20-shell/` — Shell environment modules (reserved)
- `tasks/30-system/` — System tweaks (firewall, SSH agent, SSH config). Runs last.
- `config/` — Configuration files (`.conf` format)
- `cache/logs/` — Per-package log output (gitignored)
- `cache/state/` — Persistent state data (gitignored)
- `docs/` — Documentation

## Adding a task module

1. Create `tasks/<category>/<NN>-<name>.sh` with `#!/usr/bin/env bash`.
2. Define `PACKAGE`, `DESCRIPTION`, and at minimum `check()` + `install()`.
3. The framework discovers it on next run. No registration or list updates needed.
4. Update this AGENTS.md only if adding a new category directory.

## Testing Tasks in Isolation (Recommended)

**IMPORTANTE:** Todas las tareas nuevas o modificadas deben probarse en un entorno aislado con Docker antes de ser consideradas listas.

### Script de pruebas

El script `test-task.sh` permite validar cualquier tarea de forma reproducible y segura.

**Ubicación:** `Scripts/ravn/test-task.sh`

### Comandos de uso

```bash
# Probar TODAS las tareas
./test-task.sh --all

# Probar una tarea por nombre de PACKAGE o archivo
./test-task.sh hermes
./test-task.sh 25-hermes

# Probar todas las tareas de una categoría
./test-task.sh 00-core
./test-task.sh 10-apps
./test-task.sh 30-system

# Probar varias tareas a la vez
./test-task.sh hermes codex grok playwright-cli

# Ejecutar en modo simulación (dry-run)
./test-task.sh hermes --dry-run

# Mantener el contenedor para depuración
./test-task.sh hermes --keep
```

### Flujo recomendado al crear una nueva tarea

1. Crea el archivo siguiendo la convención: `tasks/<categoría>/<NN>-<nombre>.sh`
2. Implementa al menos `PACKAGE`, `check()` e `install()`
3. Ejecuta la prueba aislada:
   ```bash
   ./test-task.sh <nombre-de-la-tarea>
   ```
4. Confirma que aparece `✓ PASÓ`
5. Si falla, usa `--keep` para inspeccionar el contenedor

### Cómo funciona internamente

- Levanta un contenedor limpio de `archlinux:latest`
- Copia la tarea dentro del contenedor
- Ejecuta `install()` de la tarea
- Verifica que `check()` retorne éxito después de la instalación
- Reporta resultados claros (PASÓ / FALLÓ)

Este enfoque fue validado exitosamente con el módulo `25-hermes.sh`.

### Beneficios

- Pruebas 100% aisladas (no modifica el sistema del desarrollador)
- Fácil de usar al agregar tareas nuevas
- Soporta pruebas masivas (`--all`) o selectivas
- Consistente con el método usado para validar Hermes


# Verification

**Obligatorio antes de cualquier commit:**

```bash
# 1. Verificación de sintaxis
find Scripts/ravn -name "*.sh" -exec bash -n {} \;

# 2. Shellcheck + shfmt (pre-commit hook)
shellcheck Scripts/ravn/**/*.sh
shfmt -d Scripts/ravn

# 3. Dry-run del pipeline
flg_DryRun=1 bash Scripts/ravn/setup.sh

# 4. Pruebas aisladas de tareas (recomendado)
./test-task.sh --all
```


