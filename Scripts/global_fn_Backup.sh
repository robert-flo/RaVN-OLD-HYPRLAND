#!/usr/bin/env bash
#|---/ /+------------------+---/ /|#
#|--/ /-| Global functions |--/ /-|#
#|-/ /--| Roberto Flores   |-/ /--|#
#|/ /---+------------------+/ /---|#

set -e

scrDir="$(dirname "$(realpath "$0")")"
cloneDir="$(dirname "${scrDir}")" # fallback, we will use CLONE_DIR now
cloneDir="${CLONE_DIR:-${cloneDir}}"
confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/ravn"
aurList=("yay" "paru")
shlList=("zsh" "fish")
pacmanCmd=${cloneDir}/Configs/.local/lib/hyde/pm.sh

export cloneDir
export confDir
export cacheDir
export aurList
export shlList

# Verifica si un paquete específico está instalado en el sistema usando pacman.
# Parámetros:
#   $1 : Nombre del paquete a comprobar (PkgIn).
# Retorno:
#   Retorna 0 si el paquete está instalado en el sistema, o 1 en caso contrario.
pkg_installed() {
  local PkgIn=$1

  if pacman -Q "${PkgIn}" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Busca cuál de los paquetes de una lista está instalado en el sistema.
# Parámetros:
#   $1    : Nombre de la variable dinámica a la que se le asignará el paquete encontrado.
#   $2... : Lista de nombres de paquetes a verificar.
# Funcionamiento:
#   Itera sobre la lista de paquetes provistos. Si detecta que alguno está instalado (mediante
#   pkg_installed), guarda el nombre del paquete en la variable dinámica especificada en el
#   primer argumento, exporta dicha variable globalmente en el entorno y retorna 0.
#   Si ninguno de los paquetes de la lista está instalado, retorna 1.
chk_list() {
  vrType="$1"
  local inList=("${@:2}")
  for pkg in "${inList[@]}"; do
    if pkg_installed "${pkg}"; then
      printf -v "${vrType}" "%s" "${pkg}"
      # shellcheck disable=SC2163 # dynamic variable
      export "${vrType}" # export the variable // reference of the variable
      return 0
    fi
  done
  # print_log -sec "install" -warn "no package found in the list..." "${inList[@]}"
  return 1
}

pkg_available() {
  local PkgIn=$1

  if ${pacmanCmd} query "${PkgIn}" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

aur_available() {
  local PkgIn=$1

  # shellcheck disable=SC2154
  if ${pacmanCmd} info "${PkgIn}" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Detecta adaptadores de gráficos (GPU) de Nvidia en el sistema.
# Opciones:
#   --verbose : Imprime en consola todas las GPUs detectadas con su índice.
#   --drivers : Mapea los códigos de GPU detectados contra la base de datos nvidia-db
#               para sugerir/imprimir los controladores Nvidia correspondientes.
#   Sin opción: Retorna 0 (éxito) si se detecta alguna GPU Nvidia, o 1 en caso contrario.
nvidia_detect() {
  readarray -t dGPU < <(lspci -k | grep -E "(VGA|3D)" | awk -F ': ' '{print $NF}')
  if [ "${1}" == "--verbose" ]; then
    for indx in "${!dGPU[@]}"; do
      echo -e "\033[0;32m[gpu$indx]\033[0m detected :: ${dGPU[indx]}"
    done
    return 0
  fi
  if [ "${1}" == "--drivers" ]; then
    while read -r -d ' ' nvcode; do
      awk -F '|' -v nvc="${nvcode}" 'substr(nvc,1,length($3)) == $3 {split(FILENAME,driver,"/"); print driver[length(driver)],"\nnvidia-utils"}' "${scrDir}"/nvidia-db/nvidia*dkms
    done <<<"${dGPU[@]}"
    return 0
  fi
  if grep -iq nvidia <<<"${dGPU[@]}"; then
    return 0
  else
    return 1
  fi
}

# Temporizador interactivo para lecturas de teclado con cuenta regresiva.
# Parámetros:
#   $1 : Tiempo de espera máximo en segundos (timsec).
#   $2 : Mensaje descriptivo a mostrar en la consola (msg).
# Funcionamiento:
#   Desactiva temporalmente el modo de salida por error (set +e) para evitar que falle el script
#   en caso de timeout. Realiza una cuenta regresiva actualizando la línea actual en consola (\r).
#   Si se pulsa cualquier tecla, detiene la espera inmediatamente. Finalmente exporta la variable
#   PROMPT_INPUT con el carácter ingresado y reestablece el modo seguro (set -e).
prompt_timer() {
  set +e
  unset PROMPT_INPUT
  local timsec=$1
  local msg=$2
  local use_tty=0
  if [[ -t 0 ]] && { true </dev/tty; } 2>/dev/null; then
    use_tty=1
  fi
  while [[ ${timsec} -ge 0 ]]; do
    echo -ne "\r :: ${msg} (${timsec}s) : "
    if ((use_tty)); then
      read -rt 1 -n 1 PROMPT_INPUT </dev/tty && break
    else
      read -rt 1 -n 1 PROMPT_INPUT && break
    fi
    ((timsec--))
  done
  export PROMPT_INPUT
  echo ""
  set -e
}
print_log() {
  local executable="${0##*/}"
  local logFile="${cacheDir}/logs/${RAVN_LOG}/${executable}.log"
  mkdir -p "$(dirname "${logFile}")"
  local section=${log_section:-}
  {
    [ -n "${section}" ] && echo -ne "\e[32m[$section] \e[0m"
    while (("$#")); do
      case "$1" in
      -r | +r)
        echo -ne "\e[31m$2\e[0m"
        shift 2
        ;; # Red
      -g | +g)
        echo -ne "\e[32m$2\e[0m"
        shift 2
        ;; # Green
      -y | +y)
        echo -ne "\e[33m$2\e[0m"
        shift 2
        ;; # Yellow
      -b | +b)
        echo -ne "\e[34m$2\e[0m"
        shift 2
        ;; # Blue
      -m | +m)
        echo -ne "\e[35m$2\e[0m"
        shift 2
        ;; # Magenta
      -c | +c)
        echo -ne "\e[36m$2\e[0m"
        shift 2
        ;; # Cyan
      -wt | +w)
        echo -ne "\e[37m$2\e[0m"
        shift 2
        ;; # White
      -n | +n)
        echo -ne "\e[96m$2\e[0m"
        shift 2
        ;; # Neon
      -stat)
        echo -ne "\e[30;46m $2 \e[0m :: "
        shift 2
        ;; # status
      -crit)
        echo -ne "\e[97;41m $2 \e[0m :: "
        shift 2
        ;; # critical
      -warn)
        echo -ne "WARNING :: \e[30;43m $2 \e[0m :: "
        shift 2
        ;; # warning
      +)
        echo -ne "\e[38;5;$2m$3\e[0m"
        shift 3
        ;; # Set color manually
      -sec)
        echo -ne "\e[32m[$2] \e[0m"
        shift 2
        ;; # section use for logs
      -err)
        echo -ne "ERROR :: \e[4;31m$2 \e[0m"
        shift 2
        ;; #error
      *)
        echo -ne "$1"
        shift
        ;;
      esac
    done
    echo ""
  } | if [ -n "${RAVN_LOG}" ]; then
    tee >(sed 's/\x1b\[[0-9;]*m//g' >>"${logFile}")
  else
    cat
  fi
}

# ==============================================================================
# Utilidades Profesionales de Instalación (Inspirado en Grok, Starship, Homebrew)
# ==============================================================================

# ─── Constantes de color con tput (degradación graceful) ─────────────────────
# Usa tput para portabilidad; si no hay terminal, degrada a string vacío.
# Referencia: https://github.com/starship/starship/blob/master/install/install.sh
if [[ -t 1 ]]; then
  _BOLD="$(tput bold 2>/dev/null || printf '')"
  _DIM="$(tput dim 2>/dev/null || printf '')"
  _UNDERLINE="$(tput smul 2>/dev/null || printf '')"
  _RED="$(tput setaf 1 2>/dev/null || printf '')"
  _GREEN="$(tput setaf 2 2>/dev/null || printf '')"
  _YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
  _BLUE="$(tput setaf 4 2>/dev/null || printf '')"
  _MAGENTA="$(tput setaf 5 2>/dev/null || printf '')"
  _CYAN="$(tput setaf 6 2>/dev/null || printf '')"
  _RESET="$(tput sgr0 2>/dev/null || printf '')"
else
  _BOLD="" _DIM="" _UNDERLINE="" _RED="" _GREEN="" _YELLOW=""
  _BLUE="" _MAGENTA="" _CYAN="" _RESET=""
fi

# ─── Funciones de logging con iconos Unicode ─────────────────────────────────
# Patrón Starship: funciones semánticas con indicadores visuales claros.
info() { printf '%s\n' "  ${_BOLD}${_CYAN}▸${_RESET} $*"; }
success() { printf '%s\n' "  ${_GREEN}✓${_RESET} $*"; }
warn_msg() { printf '%s\n' "  ${_YELLOW}⚠${_RESET} $*" >&2; }
error_msg() { printf '%s\n' "  ${_RED}✗${_RESET} $*" >&2; }
step() { printf '%s\n' "${_BOLD}${_BLUE}==>${_RESET}${_BOLD} $*${_RESET}"; }

# ─── Spinner animado con caracteres braille ──────────────────────────────────
# Muestra una animación mientras un proceso se ejecuta en segundo plano.
# Uso: long_command & spin $! "Mensaje de operación..."
# Al terminar, muestra ✓ (éxito) o ✗ (fallo) según el exit code.
spin() {
  local pid=$1 msg="${2:-Working...}"
  local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0

  # Si no hay terminal interactiva, solo esperar sin animación
  if [[ ! -t 1 ]]; then
    wait "$pid" 2>/dev/null
    return $?
  fi

  # Ocultar cursor durante la animación
  tput civis 2>/dev/null || true

  while kill -0 "$pid" 2>/dev/null; do
    local char="${spinstr:$i:1}"
    printf "\r  ${_CYAN}%s${_RESET} %s" "$char" "$msg"
    i=$(((i + 1) % ${#spinstr}))
    sleep 0.08
  done

  # Restaurar cursor
  tput cnorm 2>/dev/null || true

  wait "$pid" 2>/dev/null
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    printf "\r  ${_GREEN}✓${_RESET} %s\n" "$msg"
  else
    printf "\r  ${_RED}✗${_RESET} %s\n" "$msg"
  fi
  return $exit_code
}

# ─── Ejecutar con indicador de estado ────────────────────────────────────────
# Ejecuta un comando con spinner animado. Respeta el modo dry-run.
# Si el comando usa sudo, pre-valida las credenciales antes de backgroundear
# para evitar que el spinner sobreescriba el prompt de contraseña.
# Uso: run_with_status "Sincronizando pacman" sudo pacman -Fy
run_with_status() {
  local msg="$1"
  shift

  if [[ ${flg_DryRun:-0} -eq 1 ]]; then
    printf "  ${_YELLOW}⊘${_RESET} ${_DIM}%s (dry-run)${_RESET}\n" "$msg"
    return 0
  fi

  # Pre-cachar credenciales de sudo antes de backgroundear el proceso,
  # para que el prompt de contraseña no pelee con el spinner.
  if [[ "$1" == "sudo" ]]; then
    sudo -v 2>/dev/null || true
  fi

  "$@" &>/dev/null &
  spin $! "$msg"
}

# ─── Retry con backoff exponencial ───────────────────────────────────────────
# Patrón Homebrew: reintenta un comando N veces, duplicando la pausa cada vez.
# Uso: retry 3 git clone https://github.com/...
retry() {
  local max_tries="$1" n="$1" pause=2
  shift

  if "$@"; then
    return 0
  fi

  while ((--n > 0)); do
    warn_msg "Reintentando en ${pause}s (${n} intentos restantes): $*"
    sleep "$pause"
    ((pause *= 2))
    if "$@"; then
      return 0
    fi
  done

  error_msg "Falló después de ${max_tries} intentos: $*"
  return 1
}

# ─── Abstracción de descarga curl/wget ───────────────────────────────────────
# Patrón Grok: detecta automáticamente el downloader disponible y abstrae
# las diferencias de interfaz entre curl y wget.
# Uso: download_file "https://url" "/path/to/output"
#      download_file "https://url"  # stdout
download_file() {
  local url="$1" output="${2:-}"

  if command -v curl &>/dev/null; then
    if [[ -n "$output" ]]; then
      curl -fsSL -o "$output" "$url"
    else
      curl -fsSL "$url"
    fi
  elif command -v wget &>/dev/null; then
    if [[ -n "$output" ]]; then
      wget -q -O "$output" "$url"
    else
      wget -q -O - "$url"
    fi
  else
    error_msg "Se requiere curl o wget, pero ninguno está instalado"
    return 1
  fi
}

# ─── Descarga silenciosa con spinner braille ─────────────────────────────────
# Descarga un archivo desde una URL mostrando el spinner braille de estado.
# Uso: download_with_spinner "https://url" "/path/to/output" ["Mensaje del spinner"]
#
# Ejemplos:
#   # Uso estándar (mostrará "Descargando...")
#   download_with_spinner "https://url-del-archivo" "/ruta/salida"
#
#   # Uso con mensaje personalizado
#   download_with_spinner "https://url-del-archivo" "/ruta/salida" "Descargando recursos gráficos..."
download_with_spinner() {
  local url="$1" output="$2" msg="${3:-Descargando...}"

  download_file "$url" "$output" &>/dev/null &
  spin $! "$msg"
}

# ─── Clonar o actualizar un repositorio Git ──────────────────────────────────
# Función genérica que unifica la lógica duplicada de clone/update.
# Soporta: detección de repo existente, cambio de remote URL, retry automático.
# Uso: clone_or_update_repo "NOMBRE" "user/repo" "/path/dest" "branch" [ssh]
clone_or_update_repo() {
  local name="$1"
  local repo="$2"
  local dest="$3"
  local ref="${4:-master}"
  local prefer_ssh="${5:-}" # Pasa "ssh" para preferir SSH si hay llaves

  local remote_url="https://github.com/${repo}.git"

  # Determinar URL de remote (SSH si se solicita y hay llaves autorizadas)
  if [[ "$prefer_ssh" == "ssh" ]]; then
    if { [[ -f "$HOME/.ssh/id_ed25519" ]] || [[ -f "$HOME/.ssh/id_rsa" ]]; } && ssh -T -o ConnectTimeout=3 -o BatchMode=yes git@github.com 2>&1 | grep -q "successfully authenticated"; then
      remote_url="git@github.com:${repo}.git"
      info "Llave SSH autorizada detectada. Usando protocolo SSH para ${name}."
    else
      if [[ -f "$HOME/.ssh/id_ed25519" || -f "$HOME/.ssh/id_rsa" ]]; then
        warn_msg "Llave SSH detectada pero no autorizada en GitHub. Usando protocolo HTTPS para ${name}."
      fi
    fi
  fi

  if [[ ${flg_DryRun:-0} -eq 1 ]]; then
    printf "  ${_YELLOW}⊘${_RESET} ${_DIM}Clonar/actualizar ${name} (dry-run)${_RESET}\n"
    return 0
  fi

  if [[ -d "${dest}/.git" ]]; then
    info "Actualizando ${name} existente..."
    git -C "$dest" remote set-url origin "$remote_url" &>/dev/null || true
    if retry 3 git -C "$dest" fetch origin "$ref" &>/dev/null &&
      git -C "$dest" checkout "$ref" &>/dev/null &&
      git -C "$dest" reset --hard "origin/${ref}" &>/dev/null; then
      success "${name} sincronizado en la rama ${ref}."
    else
      error_msg "No se pudo sincronizar ${name}."
      return 1
    fi
  else
    info "Clonando ${name} desde: ${remote_url}"
    if retry 3 git clone "$remote_url" "$dest" &>/dev/null; then
      git -C "$dest" fetch origin "$ref" &>/dev/null &&
        git -C "$dest" checkout "$ref" &>/dev/null

      # Post-clone: cambiar a SSH si aplica
      if [[ "$prefer_ssh" == "ssh" ]] && [[ "$remote_url" == git@* ]]; then
        git -C "$dest" remote set-url origin "$remote_url"
      fi
      success "${name} sincronizado en la rama ${ref}."
    else
      error_msg "No se pudo clonar ${name}."
      return 1
    fi
  fi
}

# ─── Contadores de instalación ───────────────────────────────────────────────
# Llevar registro del estado de cada operación para el resumen final.
_install_ok=0
_install_fail=0
_install_skip=0
_install_ok_list=()
_install_fail_list=()
_install_skip_list=()

count_ok() {
  ((_install_ok++)) || true
  if [[ -n ${1:-} ]]; then
    _install_ok_list+=("$1")
  fi
}
count_fail() {
  ((_install_fail++)) || true
  if [[ -n ${1:-} ]]; then
    _install_fail_list+=("$1")
  fi
}
count_skip() {
  ((_install_skip++)) || true
  if [[ -n ${1:-} ]]; then
    _install_skip_list+=("$1")
  fi
}

print_item_list() {
  local prefix="$1"
  shift
  local items=("$@")
  local total_items=${#items[@]}
  if ((total_items == 0)); then
    return
  fi

  if ((total_items <= 5)); then
    local list_str=""
    local item
    for item in "${items[@]}"; do
      if [[ -z $list_str ]]; then
        list_str="$item"
      else
        list_str="$list_str, $item"
      fi
    done
    printf "%s %s\n" "$prefix" "$list_str"
  else
    printf "%s\n" "$prefix"
    local indent="      "
    printf "%s%s" "$indent" "${items[0]}"
    local i
    for ((i = 1; i < total_items; i++)); do
      if ((i % 4 == 0)); then
        printf ",\n%s%s" "$indent" "${items[i]}"
      else
        printf ", %s" "${items[i]}"
      fi
    done
    printf "\n"
  fi
}

# ─── Resumen final tipo dashboard ────────────────────────────────────────────
# Imprime un resumen visual con bordes Unicode y colores.
# Calcula dinámicamente el ancho del box para centrar el título.
print_summary() {
  local label="${1:-Installation}"
  local total=$((_install_ok + _install_fail + _install_skip))

  # Ancho fijo del contenido interior (39 caracteres visibles)
  local w=39
  local title="RaVN ${label} Summary"
  local title_len=${#title}
  local pad_left=$(((w - title_len) / 2))
  local pad_right=$((w - title_len - pad_left))
  local border
  border=$(printf '─%.0s' $(seq 1 $w))

  echo ""
  echo "  ${_DIM}┌${border}┐${_RESET}"
  printf "  ${_DIM}│${_RESET}${_BOLD}%*s%s%*s${_RESET}${_DIM}│${_RESET}\n" "$pad_left" "" "$title" "$pad_right" ""
  echo "  ${_DIM}├${border}┤${_RESET}"
  printf "  ${_DIM}│${_RESET}  ${_GREEN}✓${_RESET} Exitosos:%25s ${_DIM}│${_RESET}\n" "$_install_ok"
  printf "  ${_DIM}│${_RESET}  ${_RED}✗${_RESET} Fallidos:%25s ${_DIM}│${_RESET}\n" "$_install_fail"
  printf "  ${_DIM}│${_RESET}  ${_YELLOW}⊘${_RESET} Omitidos:%25s ${_DIM}│${_RESET}\n" "$_install_skip"
  echo "  ${_DIM}├${border}┤${_RESET}"
  printf "  ${_DIM}│${_RESET}  Total:${_BOLD}%30s${_RESET} ${_DIM}│${_RESET}\n" "$total"
  echo "  ${_DIM}└${border}┘${_RESET}"
  echo ""

  if ((total > 0)); then
    echo "  ${_BOLD}Detalles:${_RESET}"
    if ((${#_install_ok_list[@]} > 0)); then
      print_item_list "    ${_GREEN}✓${_RESET} ${_BOLD}Exitosos (${#_install_ok_list[@]}):${_RESET}" "${_install_ok_list[@]}"
    fi
    if ((${#_install_fail_list[@]} > 0)); then
      print_item_list "    ${_RED}✗${_RESET} ${_BOLD}Fallidos (${#_install_fail_list[@]}):${_RESET}" "${_install_fail_list[@]}"
    fi
    if ((${#_install_skip_list[@]} > 0)); then
      print_item_list "    ${_YELLOW}⊘${_RESET} ${_BOLD}Omitidos (${#_install_skip_list[@]}):${_RESET}" "${_install_skip_list[@]}"
    fi
    echo ""
  fi
}
