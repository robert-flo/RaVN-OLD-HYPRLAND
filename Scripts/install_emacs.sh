#!/usr/bin/env bash
#|---/ /+---------------------------+---/ /|#
#|--/ /-| Studium Emacs bootstrap   |--/ /-|#
#|-/ /--| deps, launcher, elpaca     |-/ /--|#
#|/ /---+---------------------------+/ /---|#

scrDir="$(dirname "$(realpath "$0")")"
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
  echo "Error: unable to source global_fn.sh..." >&2
  exit 1
fi

NIXOS_EMACS_SRC="${NIXOS_EMACS_SRC:-${HOME}/Work/nixos-config/master/dotfiles/emacs}"
EMACS_DIR="${confDir}/emacs"
EMACS_INIT="${EMACS_DIR}/init.el"
EMACS_BOOTSTRAP="${EMACS_DIR}/bootstrap.el"
EMACS_AUR_PKGS=(epub-thumbnailer)
LOCAL_BIN="${HOME}/.local/bin"

sync_emacs_config_from_nixos() {
  if [[ ! -d "${NIXOS_EMACS_SRC}" ]]; then
    info "Fuente nixos-config no encontrada en ${NIXOS_EMACS_SRC}; usando Configs del repo."
    return 0
  fi

  if [[ ! -f "${EMACS_INIT}" ]]; then
    step "Sincronizando Studium Emacs desde nixos-config"
    mkdir -p "${EMACS_DIR}"
    if (( flg_DryRun == 1 )); then
      print_log -y "[EMACS] " -b " :: " "Simulación: rsync ${NIXOS_EMACS_SRC}/ -> ${EMACS_DIR}/"
      return 0
    fi
    rsync -a --delete \
      --exclude '.git/' \
      --exclude 'elpaca/' \
      --exclude 'etc/' \
      --exclude '.local/' \
      "${NIXOS_EMACS_SRC}/" "${EMACS_DIR}/"
    count_ok
  fi
}

install_emacs_launcher() {
  local src_go="${cloneDir}/Configs/.local/bin/emacs-launcher.go"
  local src_bin="${cloneDir}/Configs/.local/bin/emacs-launcher"
  local dst_bin="${LOCAL_BIN}/emacs-launcher"

  mkdir -p "${LOCAL_BIN}"

  if [[ -f "${src_go}" ]]; then
    cp -f "${src_go}" "${LOCAL_BIN}/emacs-launcher.go"
  fi

  if command -v go &>/dev/null && [[ -f "${src_go}" ]]; then
    if run_with_status "Compilando emacs-launcher" go build -o "${dst_bin}" "${src_go}"; then
      count_ok
      return 0
    fi
    warn_msg "Falló la compilación de emacs-launcher; usando binario precompilado si existe."
  fi

  if [[ -f "${src_bin}" ]]; then
    cp -f "${src_bin}" "${dst_bin}"
    chmod +x "${dst_bin}"
    info "emacs-launcher instalado desde binario precompilado."
    count_ok
    return 0
  fi

  warn_msg "No se encontró emacs-launcher para instalar."
  count_skip
}

install_emacs_helpers() {
  local helper src
  for helper in emacs-mailto emacs-daemon-start; do
    src="${cloneDir}/Configs/.local/bin/${helper}"
    if [[ -f "${src}" ]]; then
      cp -f "${src}" "${LOCAL_BIN}/${helper}"
      chmod +x "${LOCAL_BIN}/${helper}"
    fi
  done
}

enable_emacs_service() {
  local unit_src="${cloneDir}/Configs/.config/systemd/user/emacs.service"
  local unit_dst="${confDir}/systemd/user/emacs.service"

  if [[ ! -f "${unit_src}" ]]; then
    warn_msg "No se encontró ${unit_src}"
    count_skip
    return 0
  fi

  mkdir -p "${confDir}/systemd/user"
  cp -f "${unit_src}" "${unit_dst}"

  if [[ ${flg_DryRun:-0} -eq 1 ]]; then
    print_log -y "[EMACS] " -b " :: " "Simulación: systemctl --user enable --now emacs.service"
    count_skip
    return 0
  fi

  systemctl --user daemon-reload
  if systemctl --user enable --now emacs.service 2>/dev/null; then
    success "Servicio emacs.service habilitado."
    count_ok
  else
    warn_msg "No se pudo habilitar emacs.service (puede requerir sesión gráfica activa)."
    count_skip
  fi
}

bootstrap_elpaca() {
  if [[ ! -f "${EMACS_BOOTSTRAP}" ]]; then
    warn_msg "No se encontró ${EMACS_BOOTSTRAP}"
    count_skip
    return 0
  fi

  if [[ -d "${EMACS_DIR}/elpaca/sources/elpa" ]]; then
    info "elpaca ya está bootstrapped."
    count_skip
    return 0
  fi

  if run_with_status "Bootstrapping elpaca" \
    emacs --batch -l "${EMACS_BOOTSTRAP}"; then
    success "Bootstrap de elpaca completado."
    count_ok
  else
    warn_msg "Bootstrap batch falló; el daemon instalará paquetes en el primer arranque."
    count_skip
  fi
}

setup_emacs() {
  if ! pkg_installed emacs-wayland && ! pkg_installed emacs; then
    warn_msg "emacs-wayland no está instalado; omitiendo configuración de Emacs."
    count_skip
    return 0
  fi

  step "Configurando Studium Emacs"
  sync_emacs_config_from_nixos

  if [[ ! -f "${EMACS_INIT}" ]]; then
    warn_msg "No se encontró ${EMACS_INIT}. Ejecuta restore_cfg antes de bootstrap de Emacs."
    count_skip
    return 0
  fi

  if chk_list "aurhlpr" "${aurList[@]}"; then
    local missing_aur=()
    local pkg
    for pkg in "${EMACS_AUR_PKGS[@]}"; do
      if ! pkg_installed "${pkg}"; then
        missing_aur+=("${pkg}")
      fi
    done

    if ((${#missing_aur[@]} > 0)); then
      if run_with_status "Instalando dependencias AUR de Emacs (${missing_aur[*]})" \
        "${aurhlpr}" -S --needed --noconfirm "${missing_aur[@]}"; then
        count_ok
      else
        warn_msg "No se pudieron instalar dependencias AUR opcionales: ${missing_aur[*]}"
        count_skip
      fi
    else
      info "Dependencias AUR de Emacs ya instaladas."
      count_skip
    fi
  else
    warn_msg "No se encontró ayudante AUR; omitiendo paquetes AUR de Emacs."
    count_skip
  fi

  if [[ ${flg_DryRun:-0} -eq 1 ]]; then
    print_log -y "[EMACS] " -b " :: " "Simulación: se omitirían launcher, servicio y bootstrap"
    count_skip
    return 0
  fi

  install_emacs_launcher
  install_emacs_helpers
  bootstrap_elpaca
  enable_emacs_service
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  setup_emacs
fi