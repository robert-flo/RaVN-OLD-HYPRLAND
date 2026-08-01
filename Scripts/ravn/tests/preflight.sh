#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT

os_release="$fixture_dir/os-release"
bin_dir="$fixture_dir/bin"
mkdir -p "$bin_dir"
cat > "$os_release" << 'EOF'
ID=arch
ID_LIKE=arch
EOF

for command_name in git curl gum; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bin_dir/$command_name"
  chmod +x "$bin_dir/$command_name"
done

ln -s "$RAVN_DIR/global_fn.sh" "$fixture_dir/global_fn.sh"
ln -s "$RAVN_DIR/framework" "$fixture_dir/framework"
sed '/^main "\$@"/d' "${RAVN_DIR}/setup.sh" > "$fixture_dir/setup.sh"
# shellcheck disable=SC1090,SC1091
source "$fixture_dir/setup.sh"

PATH="$bin_dir:$PATH"
export PATH RAVN_OS_RELEASE_FILE="$os_release" RAVN_UI=bash
ravn_validate_interactive_dependencies
[[ ${RAVN_UI_EFFECTIVE:-} == bash ]]

cat > "$os_release" << 'EOF'
ID=ubuntu
ID_LIKE=debian
EOF
if ravn_validate_interactive_dependencies > "$fixture_dir/unsupported.log" 2>&1; then
  printf 'FAIL: non-Arch preflight was accepted\n' >&2
  exit 1
fi
grep -q 'Unsupported operating system' "$fixture_dir/unsupported.log"

cat > "$os_release" << 'EOF'
ID=arch
ID_LIKE=arch
EOF
RAVN_UI=invalid
if ravn_validate_interactive_dependencies > "$fixture_dir/invalid-ui.log" 2>&1; then
  printf 'FAIL: invalid UI mode was accepted\n' >&2
  exit 1
fi
grep -q 'Invalid RAVN_UI value' "$fixture_dir/invalid-ui.log"

RAVN_UI=bash
rm "$bin_dir/gum"
printf '#!/usr/bin/env bash\nexit 1\n' > "$bin_dir/sudo"
chmod +x "$bin_dir/sudo"
ln -s /bin/bash "$bin_dir/bash"
PATH="$bin_dir"
export PATH
if ravn_validate_interactive_dependencies > "$fixture_dir/install-failure.log" 2>&1; then
  printf 'FAIL: dependency installation failure was accepted\n' >&2
  exit 1
fi
PATH="$bin_dir:/bin"
export PATH
grep -q 'Unable to install interactive dependencies' "$fixture_dir/install-failure.log"

printf 'PASS: interactive dependency preflight\n'
