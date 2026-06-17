#!/usr/bin/env bash

# Setup working directory and source global functions
scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/global_fn.sh"

# ==============================================================================
# Custom Installers (Option C)
# ==============================================================================

install_mimo() {
  if ! command -v mimo &>/dev/null; then
    step "Instalando MiMoCode..."
    # Descargamos y ejecutamos con el paso de argumentos específico
    curl -fsSL https://mimo.xiaomi.com/install | bash -s -- --no-modify-path
  else
    success "MiMoCode ya está instalado, saltando."
  fi
}

# Ejemplo de otro instalador personalizado:
# install_rust() {
#   if ! command -v rustc &>/dev/null; then
#     step "Instalando Rust..."
#     curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
#   else
#     success "Rust ya está instalado, saltando."
#   fi
# }

# ==============================================================================
# Execution Registry
# ==============================================================================

custom_installers=(
  install_mimo
)

# Loop and run each installer
for installer in "${custom_installers[@]}"; do
  if declare -f "$installer" >/dev/null; then
    $installer
  else
    error_msg "Instalador no definido: $installer"
  fi
done
