#!/usr/bin/env bash

# =============================================================================
# install_doom_parallel.sh — Instalación de Doom Emacs junto a Vanilla Emacs
# =============================================================================
# 
# CONTEXTO / PROBLEMA:
#   El usuario (ravn) tiene Emacs 30.2 en Arch Linux con una config vanilla
#   en ~/.config/emacs/ (usa Elpaca como package manager). Su Emacs consume
#   ~9 GB de RAM — una cantidad anómala probablemente por LSP, paquetes
#   pesados, o archivos abiertos en configuraciones vanilla que cargan todo
#   eager en vez de lazy.
#
#   Quiere probar Doom Emacs (conocido por ser mucho más ligero gracias a su
#   sistema de lazy-loading) SIN eliminar ni modificar su config vanilla actual.
#   Ambos deben poder lanzarse por separado desde el mismo sistema, con alias
#   y entradas .desktop diferenciadas.
#
# SOLUCIÓN TÉCNICA:
#   Desde Emacs 29+, el flag --init-directory permite apuntar a un directorio
#   de inicialización arbitrario en vez del default ~/.emacs.d/ o ~/.config/emacs/.
#   Esto permite tener configuraciones completamente aisladas:
#
#     ~/.config/emacs/          ← Vanilla existente (intocada)
#     ~/.config/doom-emacs.d/   ← Doom framework (git clone)
#     ~/.config/doom/           ← Doom user config (init.el, config.el, packages.el)
#
#   Doom Emacs NO se instala en ~/.config/emacs/ ni ~/.emacs.d/. Se instala
#   en un directorio separado (~/.config/doom-emacs.d/) y se lanza con:
#     emacs --init-directory ~/.config/doom-emacs.d
#
#   El instalador de Doom (bin/doom install) crea automáticamente la carpeta
#   ~/.config/doom/ con los archivos init.el, config.el y packages.el para
#   que el usuario personalice Doom sin tocar el framework.
#
# ALIAS PROPUESTOS:
#   alias emacs-vanilla='emacs --init-directory ~/.config/emacs'
#   alias emacs-doom='emacs --init-directory ~/.config/doom-emacs.d'
#   alias emacs='emacs --init-directory ~/.config/emacs'  (default = vanilla)
#
# LANZADORES .desktop:
#   Se crean dos entradas en ~/.local/share/applications/:
#     - emacs-vanilla.desktop  → apunta a emacs vanilla
#     - emacs-doom.desktop     → apunta a emacs doom
#   Así aparecen como apps separadas en wofi/rofi/any launcher.
#
# BENEFICIO ESPERADO:
#   Doom Emacs lazy-loada módulos y paquetes, arranca en ~0.5s y reduce el
#   consumo de RAM drásticamente (de ~9 GB a ~500 MB-1 GB dependiendo de
#   módulos activados).
#
# REFERENCIAS:
#   - Doom Emacs: https://github.com/doomemacs/doomemacs
#   - --init-directory: GNU Emacs 29+ (info "(emacs) Initial Options")
# =============================================================================

set -euo pipefail

# ── Colores para output ──────────────────────────────────────────────────────
readonly RESET="\033[0m"
readonly BOLD="\033[1m"
readonly GREEN="\033[32m"
readonly YELLOW="\033[33m"
readonly CYAN="\033[36m"

info()  { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[!]${RESET} $*"; }
step()  { echo -e "${CYAN}[→]${RESET} $*"; }
title() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

# ── Rutas ────────────────────────────────────────────────────────────────────
readonly VANILLA_DIR="${HOME}/.config/emacs"
readonly DOOM_DIR="${HOME}/.config/doom-emacs.d"
readonly DOOM_CONFIG_DIR="${HOME}/.config/doom"
readonly DOOM_BIN="${DOOM_DIR}/bin/doom"
readonly DOOM_REPO="https://github.com/doomemacs/doomemacs"

# ── Pre-flight checks ────────────────────────────────────────────────────────

title "Verificando requisitos"

# Emacs debe estar instalado
if ! command -v emacs &>/dev/null; then
  echo "ERROR: emacs no está instalado. Instálalo primero con:"
  echo "  sudo pacman -S emacs"
  exit 1
fi

EMACS_VER=$(emacs --version | head -1 | grep -oP '[\d.]+' | head -1)
info "Emacs encontrado: v${EMACS_VER}"

# Necesitamos Emacs >= 29 para --init-directory
if [[ $(echo "${EMACS_VER}" | cut -d. -f1) -lt 29 ]]; then
  echo "ERROR: Se necesita Emacs >= 29 para --init-directory (tienes ${EMACS_VER})"
  exit 1
fi

# La config vanilla debe existir
if [[ ! -d "${VANILLA_DIR}" ]]; then
  warn "No se encontró config vanilla en ${VANILLA_DIR}"
  warn "Se asume que ~/.config/emacs/ es la config por defecto de Emacs."
fi

# No sobreescribir config Doom existente
if [[ -d "${DOOM_DIR}" ]]; then
  echo "ERROR: Ya existe ${DOOM_DIR}. Si quieres reinstalar, bórralo primero:"
  echo "  rm -rf ${DOOM_DIR} ${DOOM_CONFIG_DIR}"
  exit 1
fi

# git es necesario
if ! command -v git &>/dev/null; then
  echo "ERROR: git no está instalado."
  exit 1
fi

info "Todos los requisitos cumplidos."

# ── Instalación ──────────────────────────────────────────────────────────────

title "Clonando Doom Emacs en ${DOOM_DIR}"

step "Clonando repositorio (depth=1)..."
git clone --depth 1 "${DOOM_REPO}" "${DOOM_DIR}"
info "Doom Emacs clonado."

title "Ejecutando doom install"

step "Corriendo ${DOOM_BIN} install..."
echo -e "${YELLOW}│${RESET}"
echo -e "${YELLOW}│   El instalador de Doom te pedirá confirmación para crear${RESET}"
echo -e "${YELLOW}│   ~/.config/doom/ (init.el, config.el, packages.el).${RESET}"
echo -e "${YELLOW}│   Responde 'yes' para continuar.${RESET}"
echo -e "${YELLOW}│${RESET}"
sleep 2

"${DOOM_BIN}" install
info "Doom Emacs instalado correctamente."

# ── Alias en .bashrc / .zshrc ───────────────────────────────────────────────

title "Configurando alias en el shell"

ALIAS_BLOCK=$(cat <<-ALIASES

# ---- Emacs: vanilla vs doom (parallel configs) ----
alias emacs-vanilla='emacs --init-directory ${VANILLA_DIR}'
alias emacs-doom='emacs --init-directory ${DOOM_DIR}'
# Por defecto, 'emacs' abre la config vanilla actual.
# Cambia la siguiente línea por emacs-doom si quieres que doom sea el default.
alias emacs='emacs --init-directory ${VANILLA_DIR}'
ALIASES
)

# Detectar shell preferida
SHELL_RC=""
if [[ -n "${ZSH_VERSION:-}" || "${SHELL}" == */zsh ]]; then
  SHELL_RC="${HOME}/.zshrc"
elif [[ -n "${BASH_VERSION:-}" || "${SHELL}" == */bash ]]; then
  SHELL_RC="${HOME}/.bashrc"
else
  SHELL_RC="${HOME}/.bashrc"
fi

if [[ -f "${SHELL_RC}" ]]; then
  if grep -q "emacs-vanilla\|emacs-doom" "${SHELL_RC}" 2>/dev/null; then
    warn "Ya hay alias de emacs-vanilla/doom en ${SHELL_RC}. Omitiendo."
  else
    echo "${ALIAS_BLOCK}" >> "${SHELL_RC}"
    info "Alias añadidos a ${SHELL_RC}"
  fi
else
  echo "${ALIAS_BLOCK}" > "${SHELL_RC}"
  info "Creado ${SHELL_RC} con alias."
fi

# ── .desktop entries ─────────────────────────────────────────────────────────

title "Creando lanzadores .desktop"

APPS_DIR="${HOME}/.local/share/applications"
mkdir -p "${APPS_DIR}"

create_desktop() {
  local name="$1"
  local exec_cmd="$2"
  local icon="$3"
  local comment="$4"
  local file="${APPS_DIR}/${name}.desktop"

  cat > "${file}" <<-DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=${name}
Comment=${comment}
Exec=${exec_cmd}
Icon=${icon}
Terminal=false
Categories=Development;TextEditor;
DESKTOP

  chmod +x "${file}"
  info "Creado ${file}"
}

create_desktop \
  "Emacs (Vanilla)" \
  "emacs --init-directory ${VANILLA_DIR}" \
  "emacs" \
  "GNU Emacs con configuración vanilla (~/.config/emacs/)"

create_desktop \
  "Emacs (Doom)" \
  "emacs --init-directory ${DOOM_DIR}" \
  "emacs" \
  "GNU Emacs con Doom Emacs (~/.config/doom-emacs.d/)"

# ── Resumen final ────────────────────────────────────────────────────────────

title "Instalación completada"

cat <<-SUMMARY

  ${BOLD}Resumen:${RESET}

  Vanilla Emacs mantiene su config en:
    ${VANILLA_DIR}

  Doom Emacs se instaló en:
    ${DOOM_DIR}
    ${DOOM_CONFIG_DIR}  (tu config personal de Doom)

  ${BOLD}Comandos disponibles:${RESET}
    emacs            → Vanilla (default)
    emacs-vanilla    → Vanilla
    emacs-doom       → Doom Emacs

  ${BOLD}Lanzadores .desktop:${RESET}
    ~/.local/share/applications/Emacs (Vanilla).desktop
    ~/.local/share/applications/Emacs (Doom).desktop

  ${YELLOW}⚠  Recarga tu shell: source ${SHELL_RC}${RESET}
  ${YELLOW}⚠  Edita Doom: emacs-doom &  luego SPACE h f p (doom/reload)${RESET}

SUMMARY
