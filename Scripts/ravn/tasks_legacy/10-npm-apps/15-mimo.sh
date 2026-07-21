#!/usr/bin/env bash
# ─── RaVN Task: Mimo CLI ────────────────────────────────────────────────────
# Migrated from installers/02-tui/mimo.sh

# shellcheck disable=SC2034
PACKAGE="mimo"
DESCRIPTION="Xiaomi Mimo CLI"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  command -v mimo &>/dev/null
}

install() {
  # -s: Le indica a bash que lea los comandos desde la entrada estándar (la tubería del curl).
  #     Además, habilita la capacidad de pasar argumentos posicionales al script descargado.
  # --: Marca el fin de las opciones de Bash. Todo lo que venga después de --
  #     será ignorado por Bash y se pasará directamente como argumento al script.
  curl -fsSL https://mimo.xiaomi.com/install |
    bash -s -- --no-modify-path
}
