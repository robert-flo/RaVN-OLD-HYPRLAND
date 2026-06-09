#!/bin/bash
# shellcheck disable=SC1091
#|---/ /+--------------------------------------------+---/ /|#
#|--/ /-| Script to sync/diff dotfiles safely        |--/ /-|#
#|--/ /-| Roberto Flores                             |--/ /-|#
#|/ /---+--------------------------------------------+/ /---|#

scrDir=$(dirname "$(realpath "$0")")
if ! source "${scrDir}/global_fn.sh"; then
  echo "Error: unable to source global_fn.sh..."
  exit 1
fi

DOTBARE_DIR="${DOTBARE_DIR:-$HOME/.cfg}"
CfgDir="${cloneDir}/Configs"

if [[ ! -d $DOTBARE_DIR ]]; then
  print_log -err "El repositorio dotbare no existe en $DOTBARE_DIR. Inicialízalo primero."
  exit 1
fi

# Detectar si meld está instalado
has_meld=0
if command -v meld >/dev/null 2>&1; then
  has_meld=1
fi

show_menu() {
  local rel_path=$1
  local repo_file=$2
  local active_file=$3

  while true; do
    echo "------------------------------------------------------------"
    print_log -y "[DIFERENCIA]" -b " :: " "$rel_path"
    echo "------------------------------------------------------------"
    echo "Selecciona una opción:"
    echo "  [d] Ver diff rápido en terminal"
    if (( has_meld == 1 )); then
      echo "  [m] Comparar/fusionar con Meld (Gráfico)"
    fi
    echo "  [r] Guardar cambio local en el repositorio (Exportar)"
    echo "  [h] Restaurar versión del repositorio al $HOME (Importar)"
    echo "  [s] Omitir este archivo"
    echo "  [q] Salir"
    echo -n "Opción: "
    read -r opt < /dev/tty

    case "$opt" in
      d|D)
        git diff --no-index "$repo_file" "$active_file"
        ;;
      m|M)
        if (( has_meld == 1 )); then
          print_log -g "[meld]" -b " :: " "Abriendo Meld para $rel_path..."
          meld "$repo_file" "$active_file" &
        else
          print_log -err "Meld no está instalado en el sistema."
        fi
        ;;
      r|R)
        print_log -g "[sync]" -b " :: " "Copiando a repositorio: $rel_path"
        mkdir -p "$(dirname "$repo_file")"
        cp -f "$active_file" "$repo_file"
        break
        ;;
      h|H)
        print_log -g "[sync]" -b " :: " "Restaurando a $HOME: $rel_path"
        mkdir -p "$(dirname "$active_file")"
        cp -f "$repo_file" "$active_file"
        break
        ;;
      s|S)
        break
        ;;
      q|Q)
        return 1
        ;;
      *)
        echo "Opción no válida."
        ;;
    esac
  done
  return 0
}

# Preguntar si se desea comparar el directorio .config en Meld directamente
if (( has_meld == 1 )); then
  print_log -g "[sync]" -b " :: " "¿Deseas comparar el directorio .config del repositorio con tu ~/.config en Meld? (y/N)"
  read -r ans < /dev/tty
  if [[ $ans == [Yy] ]]; then
    print_log -g "[meld]" -b " :: " "Abriendo comparación de directorios..."
    meld "$CfgDir/.config" "$HOME/.config" &
    exit 0
  fi
fi

print_log -g "[sync-back]" -b " :: " "Escaneando cambios de dotfiles..."
diff_found=0

# Obtener todos los archivos rastreados en el repositorio bare
while read -r rel_path; do
  [[ -z $rel_path ]] && continue
  active_file="${HOME}/${rel_path}"
  repo_file="${CfgDir}/${rel_path}"

  if [[ -f $active_file ]]; then
    if [[ ! -e $repo_file ]]; then
      # Archivo nuevo no presente en el repositorio
      echo "------------------------------------------------------------"
      print_log -y "[NUEVO]" -b " :: " "$rel_path (No existe en el repositorio)"
      echo "------------------------------------------------------------"
      echo "  [r] Copiar al repositorio"
      echo "  [s] Omitir"
      echo -n "Opción: "
      read -r opt < /dev/tty
      if [[ $opt == [Rr] ]]; then
        mkdir -p "$(dirname "$repo_file")"
        cp "$active_file" "$repo_file"
        print_log -g "[sync]" -b " :: " "Copiado a Configs: $rel_path"
      fi
      diff_found=1
    else
      # Ambos existen, comparar contenido
      if ! diff -q "$repo_file" "$active_file" &>/dev/null; then
        diff_found=1
        if ! show_menu "$rel_path" "$repo_file" "$active_file"; then
          print_log -warn "Sincronización abortada por el usuario."
          exit 0
        fi
      fi
    fi
  fi
done < <(git --git-dir="$DOTBARE_DIR" ls-files)

if (( diff_found == 0 )); then
  print_log -g "[sync-back]" -b " :: " "Todos los archivos rastreados están sincronizados con el repositorio."
else
  print_log -g "[sync-back]" -b " :: " "Escaneo e interacción completados."
fi

