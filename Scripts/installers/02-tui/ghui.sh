PACKAGE="ghui"
CHECK="ghui"

install() {
  local npx_installer="${HOME}/.local/share/omarchy/bin/omarchy-npx-install"
  if [[ -x $npx_installer ]]; then
    "$npx_installer" "@kitlangton/ghui" "ghui"
  else
    echo "Error: omarchy-npx-install not found at $npx_installer" >&2
    return 1
  fi
}
