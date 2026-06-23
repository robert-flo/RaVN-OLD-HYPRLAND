#!/usr/bin/env bash
# ─── RaVN Task: Custom Neovim Configurations ─────────────────────────────────
# Clones adivim and 2kvim Neovim configurations and generates launchers
# under ~/.local/bin to run them isolated using NVIM_APPNAME.

# shellcheck disable=SC2034,SC2154
PACKAGE="nvim-custom-vims"
DESCRIPTION="Custom Neovim configurations (adivim & 2kvim) with launchers"
CATEGORY="apps"
DEPENDS=()
INTERACTIVE=false

check() {
  # Skip if both configurations are already cloned and launchers are present
  if [[ -d "$HOME/.config/vims/adivim" && -d "$HOME/.config/vims/2kvim" ]] &&
     [[ -x "$HOME/.local/bin/adivim" && -x "$HOME/.local/bin/2kvim" ]]; then
    return 0
  fi
  return 1
}

install() {
  if ((flg_DryRun == 1)); then
    info "Simulación: Saltando clonación de Neovim vims y creación de lanzadores."
    return 0
  fi

  # Asegurar directorios de destino
  mkdir -p "$HOME/.config/vims"
  mkdir -p "$HOME/.local/bin"

  # 1. Clonar o actualizar adivim
  if ! clone_or_update_repo "adivim" "adibhanna/nvim" "$HOME/.config/vims/adivim" "main"; then
    return 1
  fi

  # 2. Clonar o actualizar 2kvim
  if ! clone_or_update_repo "2kvim" "2KAbhishek/nvim2k" "$HOME/.config/vims/2kvim" "main"; then
    return 1
  fi

  # 3. Crear lanzador adivim
  step "Creando lanzador ~/.local/bin/adivim..."
  cat << 'EOF' > "$HOME/.local/bin/adivim"
#!/usr/bin/env bash

export NVIM_APPNAME="vims/adivim"
exec -a "$NVIM_APPNAME" nvim -u "$HOME/.config/vims/adivim/init.lua" "$@"
EOF
  chmod +x "$HOME/.local/bin/adivim"

  # 4. Crear lanzador 2kvim
  step "Creando lanzador ~/.local/bin/2kvim..."
  cat << 'EOF' > "$HOME/.local/bin/2kvim"
#!/usr/bin/env bash

export NVIM_APPNAME="vims/2kvim"
exec -a "$NVIM_APPNAME" nvim -u "$HOME/.config/vims/2kvim/init.lua" "$@"
EOF
  chmod +x "$HOME/.local/bin/2kvim"

  success "Configuraciones y lanzadores de Neovim personalizados listos."
}
