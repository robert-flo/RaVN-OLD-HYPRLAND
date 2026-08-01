#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export RAVN_DIR

fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT

bin_dir="$fixture_dir/bin"
os_release="$fixture_dir/os-release"
mkdir -p "$bin_dir"

for command_name in bash cat clear dirname env find grep mkdir mktemp realpath rm sed sort touch; do
  ln -s "/usr/bin/$command_name" "$bin_dir/$command_name"
done

cat > "$os_release" << 'EOF'
ID=arch
ID_LIKE=arch
EOF

for command_name in git curl gum; do
  printf "#!/usr/bin/env bash\nif [[ -n \${GUM_LOG:-} ]]; then printf 'invoked\\n' >> \"\$GUM_LOG\"; fi\nif [[ \$1 == choose ]]; then printf 'q  Exit\\n'; fi\n" > "$bin_dir/$command_name"
  chmod +x "$bin_dir/$command_name"
done

run_entrypoint() {
  local input="$1"
  local ui="${2:-gum}"
  printf '%b' "$input" | script -qefc \
    "env PATH='$bin_dir' RAVN_OS_RELEASE_FILE='$os_release' RAVN_UI='$ui' '$RAVN_DIR/setup.sh'" \
    /dev/null
}

supported_output=$(run_entrypoint 'q\n' auto)
grep -q 'RaVN Task Runner' <<< "$supported_output"
grep -q 'Choose an action' <<< "$supported_output"

cat > "$os_release" << 'EOF'
ID=ubuntu
ID_LIKE=debian
EOF
unsupported_output=$(run_entrypoint 'q\n' auto || true)
grep -q 'Unsupported operating system' <<< "$unsupported_output"
if grep -q 'Choose an action' <<< "$unsupported_output"; then
  printf 'FAIL: unsupported systems opened the menu\n' >&2
  exit 1
fi

cat > "$os_release" << 'EOF'
ID=arch
ID_LIKE=arch
EOF
rm "$bin_dir/gum"
printf "#!/usr/bin/env bash\ntouch \"\$BIN_DIR/gum\"\n" > "$bin_dir/sudo"
chmod +x "$bin_dir/sudo"
install_output=$(BIN_DIR="$bin_dir" run_entrypoint 'q\n' auto)
grep -q 'RaVN Task Runner' <<< "$install_output"

rm "$bin_dir/gum"
printf '#!/usr/bin/env bash\nexit 1\n' > "$bin_dir/sudo"
chmod +x "$bin_dir/sudo"
failure_output=$(run_entrypoint 'q\n' auto || true)
grep -q 'Unable to install interactive dependencies' <<< "$failure_output"
if grep -q 'Choose an action' <<< "$failure_output"; then
  printf 'FAIL: package-manager failure opened the menu\n' >&2
  exit 1
fi

invalid_output=$(run_entrypoint 'q\n' invalid || true)
grep -q 'Invalid RAVN_UI value' <<< "$invalid_output"

gum_log="$fixture_dir/gum.log"
no_tty_output=$(printf '\n' | env PATH="$bin_dir" RAVN_OS_RELEASE_FILE="$os_release" RAVN_UI=auto GUM_LOG="$gum_log" "$RAVN_DIR/setup.sh" 2>&1 || true)
grep -q 'No subcommand in non-interactive mode' <<< "$no_tty_output"
[[ ! -e $gum_log ]]

direct_output=$(printf '\n' | env PATH="$bin_dir" RAVN_OS_RELEASE_FILE="$os_release" RAVN_UI=auto GUM_LOG="$gum_log" "$RAVN_DIR/setup.sh" verify missing-task 2>&1 || true)
grep -q 'Task not found' <<< "$direct_output"
[[ ! -e $gum_log ]]

printf 'PASS: executable interactive preflight\n'
