PACKAGE="pi"
CHECK="pi"

install() {
  local npx_installer="${HOME}/.local/share/omarchy/bin/omarchy-npx-install"
  if [[ -x $npx_installer ]]; then
    "$npx_installer" "@earendil-works/pi-coding-agent" "pi"
  else
    echo "Error: omarchy-npx-install not found at $npx_installer" >&2
    return 1
  fi
}
