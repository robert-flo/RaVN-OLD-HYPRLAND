# Terminal Output Style Guide
> Reglas de estilo para la salida en terminal de los targets `.mk`.
> Objetivo: moderna, limpia, sin ruido corporativo.

---

## Principios

- **Sin pasos numerados** — "1. Analyzing..." es ruido. El contenido habla solo.
- **Sin cajas `═══` dobles** en targets de rutina. Solo se aceptan en `help`.
- **Sin separadores `────` entre cada paso** — solo uno bajo el header.
- **Footer compacto** — una línea `✓ done` con hints inline, no una caja.
- **Hints inline** — separados con `·`, minúsculas, sin "Quick Actions:".
- **Todo lowercase** en headers de terminal (emojis permitidos).

---

## Colores disponibles (Makefile raíz)

```makefile
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
PURPLE := \033[0;35m
CYAN   := \033[0;36m
DIM    := \033[2m      # texto tenue — hints, info secundaria
BOLD   := \033[1m      # énfasis
NC     := \033[0m      # reset
```

| Color    | Uso                                      |
|----------|------------------------------------------|
| `CYAN`   | Headers, separadores, nombres de targets |
| `GREEN`  | Éxito, `✓`                               |
| `YELLOW` | Advertencias, `⚠`                        |
| `RED`    | Errores, acciones destructivas           |
| `DIM`    | Hints, información secundaria            |
| `BOLD`   | Énfasis ocasional                        |

---

## Patrón: Header

Una sola línea con emoji + nombre del target + contexto, seguida de un
separador fino `─` (U+2500, thin horizontal). Solo visible fuera de `EMBEDDED`.

```makefile
ifndef EMBEDDED
	@printf "\n"
	@printf "$(CYAN)🔤 target-name · contexto$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
endif
```

**Salida:**
```
🔤 target-name · contexto
────────────────────────────────────────────────────────────────────────────────
```

### ❌ Evitar (estilo antiguo)
```
═════════════════════════════════════════════════════════════════════════════════
             🔤 Verbose Title Here
═════════════════════════════════════════════════════════════════════════════════
```

---

## Patrón: Contenido

- Indentado con 2 espacios.
- Sin etiquetas de paso ("1. Doing X:", "2. Running Y:").
- Sin separadores `────` entre pasos intermedios.
- Advertencias en `YELLOW` con `⚠`.
- Info neutra sin color extra o en `DIM`.

```makefile
	@printf "  descripción breve de lo que hace\n"
	@printf "$(YELLOW)  ⚠  advertencia si aplica$(NC)\n"
```

---

## Patrón: Footer

El `✓ done` solo aparece fuera de `EMBEDDED`. El bloque **Quick Actions**
siempre se muestra — incluye header, separador fino en `DIM`, y cada línea
con formato **`• descripción: make cmd`** (descripción primero, comando en `BLUE`).

```makefile
ifndef EMBEDDED
	@printf "\n$(GREEN)  ✓ done$(NC)\n"
endif
	@printf "\n$(YELLOW)📋 Quick Actions:$(NC)\n"
	@printf "$(DIM)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  • descripción breve de lo que hace: $(BLUE)make next-cmd$(NC)\n"
	@printf "  • descripción breve de lo que hace: $(BLUE)make other-cmd$(NC)\n\n"
```

**Salida:**
```
  ✓ done

📋 Quick Actions:
────────────────────────────────────────────────────────────────────────────────
  • descripción breve de lo que hace: make next-cmd
  • descripción breve de lo que hace: make other-cmd
```
_(descripción en blanco, comando en azul)_

### Reglas del bloque Quick Actions

- Separador `────` siempre en `$(DIM)` — no en `$(CYAN)`
- Formato de cada línea: `"  • descripción: $(BLUE)make cmd$(NC)\n"`
- Descripción primero, comando al final (igual que `help-aliases`)
- Incluir solo los 2–3 comandos más relevantes como siguiente paso
- Dentro de bloques shell (`if/else`): usar `printf` sin `@`

### ❌ Evitar (estilo antiguo)
```
════════════════════════════════════════════════════════════════════════════════
  ✅ Operation completed successfully
════════════════════════════════════════════════════════════════════════════════

📋 Quick Actions:
────────────────────────────────────────────────────────────────────────────────
• Do something:    make next-cmd
```

---

## Patrón: DRY_RUN

Declarar en cada `.mk` que tenga comandos reales. Variables exportadas para
que funcionen en subshells.

```makefile
DRY_RUN ?= 0
export DRY_RUN
ifeq ($(DRY_RUN),1)
  EXEC = echo "  ▶ [dry-run]"
else
  EXEC =
endif
```

### Qué targets necesitan DRY_RUN

Solo los targets que **modifican el sistema o lanzan procesos** necesitan DRY_RUN.
Los targets **read-only** (búsquedas, listados, análisis) no lo necesitan.

Documentar en el header del `.mk` qué targets lo soportan y cuáles son read-only:

```makefile
# 🧪 Dry Run (preview without executing):
#    make sys-apply   DRY_RUN=1   · skip nixos-rebuild switch
#    make sys-gc      DRY_RUN=1   · skip nix-collect-garbage
#    (sys-check, sys-build are read-only)
```

Criterios:
- ✅ Necesita DRY_RUN: `sudo`, builds, `nix-collect-garbage`, shells interactivos, VMs
- ✗ No necesita: `find`, `ls`, `nix search`, `nix path-info`, `git log`, listados

### Uso en comandos simples

```makefile
@$(EXEC) sudo algún-comando --con-flags
```

### Uso en bloques shell (para comandos dentro de `if/else`)

```bash
if [ "$$DRY_RUN" = "1" ]; then \
    printf "  ▶ [dry-run] algún-comando\n"; \
else \
    algún-comando; \
fi; \
```

---

## Patrón: EMBEDDED guard

Envolver header y footer en `ifndef EMBEDDED` para evitar output duplicado
cuando un target is llamado como dependencia de otro.

```makefile
mi-target:
ifndef EMBEDDED
	# header
endif
	# lógica real
ifndef EMBEDDED
	# footer
endif
```
