PACKAGE="playwright-cli"
CHECK="playwright-cli"

install() {
  local npx_installer="${HOME}/.local/share/omarchy/bin/omarchy-npx-install"
  if [[ -x $npx_installer ]]; then
    "$npx_installer" "playwright" "playwright-cli"
  else
    echo "Error: omarchy-npx-install not found at $npx_installer" >&2
    return 1
  fi
}
