#!/usr/bin/env bash
# shellcheck disable=SC1091

#|---/ /+-----------------------------------------------+---/ /|#
#|--/ /-| Script de limpieza de pruebas para VMs de RaVN|--/ /-|#
#||-/ /--| Antigravity AI                                |-/ /--|#
#|/ /---+-----------------------------------------------+/ /---|#
#
# Ejemplos de uso:
#   1. Limpieza interactiva estándar (solo componentes core):
#      $ ./clean_test.sh
#
#   2. Limpieza completa interactiva (incluye apps opcionales y dotbare):
#      $ ./clean_test.sh --all
#
#   3. Simulación de limpieza estándar (dry-run):
#      $ ./clean_test.sh --dry-run
#
#   4. Simulación de limpieza completa (dry-run + all):
#      $ ./clean_test.sh -d -a
#
#   5. Limpieza automática completa (sin confirmación, útil en CI/VMs):
#      $ ./clean_test.sh --yes --all

scrDir=$(dirname "$(realpath "$0")")

# Cargar funciones globales si están disponibles
if [[ -f "${scrDir}/global_fn.sh" ]]; then
  source "${scrDir}/global_fn.sh"
else
  # Fallbacks para estilo visual y logging estándar
  _BOLD="" _DIM="" _UNDERLINE="" _RED="" _GREEN="" _YELLOW=""
  _BLUE="" _MAGENTA="" _CYAN="" _RESET=""
  if [[ -t 1 ]]; then
    _BOLD="$(tput bold 2> /dev/null || printf '')"
    _DIM="$(tput dim 2> /dev/null || printf '')"
    _RED="$(tput setaf 1 2> /dev/null || printf '')"
    _GREEN="$(tput setaf 2 2> /dev/null || printf '')"
    _YELLOW="$(tput setaf 3 2> /dev/null || printf '')"
    _BLUE="$(tput setaf 4 2> /dev/null || printf '')"
    _CYAN="$(tput setaf 6 2> /dev/null || printf '')"
    _RESET="$(tput sgr0 2> /dev/null || printf '')"
  fi
  info() { printf '%s\n' "  ${_BOLD}${_CYAN}▸${_RESET} $*"; }
  success() { printf '%s\n' "  ${_GREEN}✓${_RESET} $*"; }
  warn_msg() { printf '%s\n' "  ${_YELLOW}⚠${_RESET} $*" >&2; }
  error_msg() {
                printf '%s\n' "  ${_RED}✗${_RESET} $*" >&2
                                                              exit 1
  }
  step() { printf '%s\n' "${_BOLD}${_BLUE}==>${_RESET}${_BOLD} $*${_RESET}"; }
fi

flg_DryRun=0
flg_Yes=0
flg_All=0

# Parsear argumentos de la línea de comandos
while [[ $# -gt 0 ]]; do
  case $1 in
    -d | --dry-run)
      flg_DryRun=1
      shift
      ;;
    -y | --yes)
      flg_Yes=1
      shift
      ;;
    -a | --all)
      flg_All=1
      shift
      ;;
    -h | --help)
      echo "Uso: $0 [opciones]"
      echo "Opciones:"
      echo "  -d, --dry-run   Ejecuta en modo simulación (muestra lo que se borraría sin borrarlo)"
      echo "  -y, --yes       Omite la confirmación interactiva (útil para automatización)"
      echo "  -a, --all       Elimina también componentes opcionales, binarios de aplicaciones y dotbare"
      echo "  -h, --help      Muestra esta ayuda"
      exit 0
      ;;
    *)
      echo "Opción desconocida: $1" >&2
      exit 1
      ;;
  esac
done

# Advertencia e interactividad
if ((flg_DryRun == 0))   && ((flg_Yes == 0)); then
  warn_msg "Este script es ALTAMENTE DESTRUCTIVO y está diseñado únicamente para VMs de prueba."
  if ((flg_All == 1)); then
    warn_msg "Con el flag --all, también se borrarán componentes adicionales de Omarchy, nvim-Lazyman, Mimo/OpenCode y el repositorio bare de dotbare (~/.cfg)."
  fi
  warn_msg "Borrará todos los archivos listados en restore_cfg.psv y todo lo relacionado con hyde/ravn en ~/.local, ~/.cache y ~/.config."
  printf " %s¿Deseas continuar? Escribe 'YES' para confirmar: %s" "${_BOLD}${_RED}" "${_RESET}"
  read -r user_confirm
  if [[ $user_confirm != "YES" ]]; then
    error_msg "Operación cancelada por el usuario."
  fi
fi

# 1. Procesar restore_cfg.psv
psv_file="${scrDir}/restore_cfg.psv"
if [[ ! -f $psv_file ]]; then
  error_msg "No se encontró restore_cfg.psv en ${psv_file}"
fi

if ((flg_DryRun == 1)); then
  step "SIMULACIÓN: Analizando archivos en restore_cfg.psv..."
else
  step "Eliminando archivos/directorios de restore_cfg.psv..."
fi

while read -r line; do
  # Omitir comentarios, líneas vacías o líneas que no tengan 4 columnas
  if [[ $line =~ ^[[:space:]]*# ]] || (($( awk -F '|' '{print NF}' <<< "$line") != 4)); then
    continue
  fi

  pth=$(awk -F '|' '{print $2}' <<< "$line") || true
  pth=$(eval echo "$pth") || true
  cfg=$(awk -F '|' '{print $3}' <<< "$line") || true

  # Separar por espacios cada elemento y procesar
  echo "$cfg" | xargs -n 1 | while read -r item; do
    if [[ -n $pth && -n $item ]]; then
      target_path="${pth}/${item}"
      if [[ -e $target_path || -L $target_path ]]; then
        if ((flg_DryRun == 1)); then
          info "[SIMULACIÓN] Borraría tracked item: ${target_path}"
        else
          info "Borrando tracked item: ${target_path}"
          rm -rf "${target_path}"
        fi
      fi
    fi
  done || true
done < "$psv_file"

# 2. Eliminar todo lo relacionado con hyde y ravn en ~/.local, ~/.cache y ~/.config
if ((flg_DryRun == 1)); then
  step "SIMULACIÓN: Buscando archivos relacionados con 'hyde' y 'ravn' en directorios del usuario..."
else
  step "Borrando archivos relacionados con 'hyde' y 'ravn' en ~/.config, ~/.local, ~/.cache..."
fi

find_paths=()
[[ -d $HOME/.config ]] && find_paths+=("$HOME/.config")
[[ -d $HOME/.local ]] && find_paths+=("$HOME/.local")
[[ -d $HOME/.cache ]] && find_paths+=("$HOME/.cache")

if ((${#find_paths[@]} > 0)); then
  find "${find_paths[@]}" -depth \( -iname "*hyde*" -o -iname "*ravn*" \) -print0 2> /dev/null | while IFS= read -r -d '' match_path; do
    # Seguridad: garantizar que la ruta está estrictamente dentro de los directorios del usuario y no en el repo de trabajo
    if [[ $match_path == "$HOME/.config"* || $match_path == "$HOME/.local"* || $match_path == "$HOME/.cache"* ]]; then
      if [[ $match_path != *"/Work/RaVN"* ]]; then
        if ((flg_DryRun == 1)); then
          info "[SIMULACIÓN] Borraría related path: ${match_path}"
        else
          info "Borrando related path: ${match_path}"
          rm -rf "${match_path}"
        fi
      fi
    fi
  done || true
fi

# 3. Eliminar cualquier archivo que tenga correspondencia en Configs/ del repositorio
if ((flg_DryRun == 1)); then
  step "SIMULACIÓN: Buscando archivos individuales instalados desde Configs/..."
else
  step "Borrando archivos individuales instalados desde Configs/..."
fi

cfg_dir="${cloneDir:-$(dirname "$scrDir")}/Configs"
if [[ -d $cfg_dir ]]; then
  # Buscar solo archivos y enlaces simbólicos en Configs/
  find "$cfg_dir" -type f -o -type l 2> /dev/null | while IFS= read -r src_path; do
    # Calcular ruta relativa
    rel_path="${src_path#"$cfg_dir/"}"

    # Ignorar documentación o archivos AGENTS.md
    if [[ $rel_path == *"AGENTS.md" ]]; then
      continue
    fi

    target_path="${HOME}/${rel_path}"
    if [[ -f $target_path || -L $target_path ]]; then
      if ((flg_DryRun == 1)); then
        info "[SIMULACIÓN] Borraría config file: ${target_path}"
      else
        info "Borrando config file: ${target_path}"
        rm -f "${target_path}"
      fi
    fi
  done || true
fi

# 4. Eliminar componentes opcionales, repositorios adicionales y wrappers de binarios si se solicita --all
if ((flg_All == 1)); then
  if ((flg_DryRun == 1)); then
    step "SIMULACIÓN: Buscando archivos y componentes opcionales (--all)..."
  else
    step "Borrando archivos y componentes opcionales (--all)..."
  fi

  extra_paths=()

  # Binarios de aplicaciones y wrappers
  for bin in agent agy codex copilot ghui grok lazyman mimo mimocode opencode pi playwright-cli; do
    extra_paths+=("$HOME/.local/bin/$bin")
  done

  # Directorios de share, state, config y cache adicionales
  extra_paths+=(
    "$HOME/.local/share/omarchy"
    "$HOME/.local/share/mimocode"
    "$HOME/.local/share/opencode"
    "$HOME/.local/state/mimocode"
    "$HOME/.local/state/nvim-Lazyman"
    "$HOME/.local/state/spicetify"
    "$HOME/.config/nvim-Lazyman"
    "$HOME/.config/mimocode"
    "$HOME/.config/opencode"
    "$HOME/.config/dotbare"
    "$HOME/.config/github-copilot"
    "$HOME/.config/autostart/walker.desktop"
    "$HOME/.config/cfg_backups"
    "$HOME/.cache/mimocode"
    "$HOME/.cache/nvim-Lazyman"
    "$HOME/.cache/opencode"
    "$HOME/.cache/elephant"
    "${DOTBARE_DIR:-$HOME/.cfg}"
    "$HOME/.oh-my-zsh/custom/plugins/dotbare"
  )

  for pth in "${extra_paths[@]}"; do
    if [[ -e $pth || -L $pth ]]; then
      if ((flg_DryRun == 1)); then
        info "[SIMULACIÓN] Borraría extra item: ${pth}"
      else
        info "Borrando extra item: ${pth}"
        rm -rf "${pth}"
      fi
    fi
  done
fi

if ((flg_DryRun == 1)); then
  success "Simulación completada con éxito."
else
  success "Limpieza completada con éxito."
fi
