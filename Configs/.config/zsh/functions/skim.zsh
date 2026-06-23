# ═══════════════════════════════════════════════════════════════
# 🔍 SKIM CONFIGURATION FOR ZSH
# ═══════════════════════════════════════════════════════════════
#
# Beneficios de esta integración en Zsh:
# Al importar /usr/share/skim/key-bindings.zsh, obtienes soporte nativo
# e inmediato en Zsh para:
#
# - Ctrl-T: Buscar archivos interactivamente y pegarlos en la línea de comandos.
# - Alt-C: Buscar directorios interactivamente y hacer cd a ellos de forma instantánea.
# - Ctrl-R: Buscar de forma interactiva en el historial de comandos usando skim.
# - ** + Tab: Completado dinámico por defecto de skim.
#
# ═══════════════════════════════════════════════════════════════

# 1. Definir variables y alias por defecto (Equivalente a skimDefault en Nix)
export SKIM_DEFAULT_COMMAND="rg --files --hidden"
alias sk="sk --cmd 'rg --files --hidden'"

# 2. Equivalente a skimCd en Nix
# Si se ejecuta directamente, nos cambiará al directorio seleccionado.
# Si se usa en un pipe o subshell, imprimirá la selección.
sk-cd() {
  local dir
  # Utiliza fd para listar los directorios excluyendo .git de forma recursiva
  dir=$(fd --type d --hidden --exclude .git . 2>/dev/null | sk \
    --preview "eza --icons --git --color always -T -L 3 {} | head -200" \
    --exact "$@")

  if [[ -n "$dir" ]]; then
    # Si la salida estándar es una terminal interactiva, hacemos cd directamente
    if [[ -t 1 ]]; then
      cd "$dir" || return 1
    else
      # De lo contrario, imprimimos la ruta (comportamiento de tubería)
      echo "$dir"
    fi
  fi
}

# 3. Habilitar atajos e integración de Skim en Zsh
# El paquete de Arch Linux incluye el script oficial de atajos y completado
if [[ -f /usr/share/skim/key-bindings.zsh ]]; then
  # shellcheck disable=SC1091
  source /usr/share/skim/key-bindings.zsh
fi
