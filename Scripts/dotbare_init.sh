#!/usr/bin/env bash
# shellcheck disable=SC1091
#|---/ /+--------------------------------------------+---/ /|#
#|--/ /-| Script to initialize dotbare tracking      |--/ /-|#
#||-/ /--| Roberto Flores                             |-/ /--|#
#|/ /---+--------------------------------------------+/ /---|#

scrDir=$(dirname "$(realpath "$0")")
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

DOTBARE_DIR="${DOTBARE_DIR:-$HOME/.cfg}"
DOTBARE_TREE="${DOTBARE_TREE:-$HOME}"
# Asegurar la existencia del archivo de rutas en el $HOME del usuario
track_file_home="$HOME/.config/dotbare/tracked_paths.lst"
track_file_repo="$scrDir/../Configs/.config/dotbare/tracked_paths.lst"

if [[ ! -f $track_file_home ]]; then
  if [[ -f $track_file_repo ]]; then
    mkdir -p "$(dirname "$track_file_home")"
    cp "$track_file_repo" "$track_file_home"
  else
    mkdir -p "$(dirname "$track_file_home")"
    cat << EOF > "$track_file_home"
# Rutas a rastrear por dotbare
~/.config/zsh/.zshrc
~/.config/zsh/user.zsh
~/.config/zsh/prompt.zsh
~/.config/zsh/plugin.zsh
~/.config/kitty/kitty.conf
~/.config/hypr/userprefs.conf
EOF
  fi
fi

# Inicializar el repositorio bare si no existe
if [[ ! -d $DOTBARE_DIR ]]; then
  print_log -g "[dotbare]" -b " :: " "Inicializando repositorio bare en $DOTBARE_DIR..."
  git init --bare "$DOTBARE_DIR"
else
  print_log -g "[dotbare]" -b " :: " "Repositorio bare ya existe en $DOTBARE_DIR."
fi

# Configurar el repositorio bare para trabajar con $HOME
print_log -g "[dotbare]" -b " :: " "Configurando work-tree y ocultando archivos no rastreados..."
git --git-dir="$DOTBARE_DIR" --work-tree="$DOTBARE_TREE" config --local status.showUntrackedFiles no
git --git-dir="$DOTBARE_DIR" --work-tree="$DOTBARE_TREE" config --local core.worktree "$DOTBARE_TREE"

# Registrar los archivos con listado en tracked_paths.lst
print_log -g "[dotbare]" -b " :: " "Registrando archivos personales desde tracked_paths.lst..."
while read -r line || [[ -n $line ]]; do
  # Omitir líneas vacías y comentarios
  [[ -z $line ]] && continue
  [[ $line =~ ^[[:space:]]*# ]] && continue

  # Resolver la ruta expandiendo variables y tilde
  resolved_path=$(eval "echo $line")
  rel_path="${resolved_path#"$DOTBARE_TREE"/}"

  if [[ -e $resolved_path ]]; then
    if [[ -d $resolved_path ]]; then
      # Si es un directorio, agregar sus archivos recursivamente
      if git --git-dir="$DOTBARE_DIR" --work-tree="$DOTBARE_TREE" add "$resolved_path" 2> /dev/null; then
        print_log -g "[track]" -b " :: " "$rel_path/ (directorio)"
      fi
    else
      # Si es un archivo individual
      if git --git-dir="$DOTBARE_DIR" --work-tree="$DOTBARE_TREE" add "$resolved_path" 2> /dev/null; then
        print_log -g "[track]" -b " :: " "$rel_path"
      else
        print_log -err "No se pudo registrar: $rel_path"
      fi
    fi
  else
    print_log -warn "Ruta no encontrada para rastreo: $resolved_path"
  fi
done < "$track_file_home"

# Crear un commit inicial si hay cambios preparados en el índice
if ! git --git-dir="$DOTBARE_DIR" --work-tree="$DOTBARE_TREE" diff --cached --quiet; then
  print_log -g "[dotbare]" -b " :: " "Creando commit de las rutas rastreadas..."
  git --git-dir="$DOTBARE_DIR" --work-tree="$DOTBARE_TREE" commit -m "Initial commit of tracked paths" > /dev/null
fi

print_log -g "[dotbare]" -b " :: " "Rastreo selectivo configurado con éxito."
