#!/usr/bin/env bash

# ==============================================================================
# Obtención de metadatos del repositorio Git de RaVN
# ==============================================================================
RAVN_CLONE_PATH=$(git rev-parse --show-toplevel)
RAVN_BRANCH=$(git rev-parse --abbrev-ref HEAD)
RAVN_REMOTE=$(git config --get remote.origin.url)
RAVN_VERSION=$(git describe --tags --always)
RAVN_COMMIT_HASH=$(git rev-parse HEAD)
RAVN_VERSION_COMMIT_MSG=$(git log -1 --pretty=%B)
RAVN_VERSION_LAST_CHECKED=$(date +%Y-%m-%d\ %H:%M:%S\ %z)

# ==============================================================================
# Función para generar las notas de versión con los cambios desde la última etiqueta
# ==============================================================================
generate_release_notes() {
  local latest_tag
  local commits

  latest_tag=$(git describe --tags --abbrev=0 2>/dev/null)

  if [[ -z "$latest_tag" ]]; then
    echo "No release tags found"
    return
  fi

  echo "=== Changes since $latest_tag ==="

  commits=$(git log --oneline --pretty=format:"• %s" "$latest_tag"..HEAD 2>/dev/null)

  if [[ -z "$commits" ]]; then
    echo "No commits since last release"
    return
  fi

  echo "$commits"
}

# ==============================================================================
# Mostrar información detallada de la versión de RaVN en la consola
# ==============================================================================
echo "RaVN Dotfiles by Roberto Flores $RAVN_VERSION built from branch $RAVN_BRANCH at commit ${RAVN_COMMIT_HASH:0:12} ($RAVN_VERSION_COMMIT_MSG)"
echo "Date: $RAVN_VERSION_LAST_CHECKED"
echo "Repository: $RAVN_CLONE_PATH"
echo "Remote: $RAVN_REMOTE"
echo ""

# ==============================================================================
# Procesamiento de parámetros y almacenamiento opcional en caché de estado
# ==============================================================================
if [[ "$1" == "--cache" ]]; then
  state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ravn"
  mkdir -p "$state_dir"
  version_file="$state_dir/version"

  RAVN_RELEASE_NOTES=$(generate_release_notes)

  cat >"$version_file" <<EOL
RAVN_CLONE_PATH='$RAVN_CLONE_PATH'
RAVN_BRANCH='$RAVN_BRANCH'
RAVN_REMOTE='$RAVN_REMOTE'
RAVN_VERSION='$RAVN_VERSION'
RAVN_VERSION_LAST_CHECKED='$RAVN_VERSION_LAST_CHECKED'
RAVN_VERSION_COMMIT_MSG='$RAVN_VERSION_COMMIT_MSG'
RAVN_COMMIT_HASH='$RAVN_COMMIT_HASH'
RAVN_RELEASE_NOTES='$RAVN_RELEASE_NOTES'
EOL

  echo -e "Version cache output to $version_file\n"

elif [[ "$1" == "--release-notes" ]]; then
  generate_release_notes

fi

