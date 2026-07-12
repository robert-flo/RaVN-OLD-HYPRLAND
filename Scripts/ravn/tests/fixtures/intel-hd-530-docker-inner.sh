#!/usr/bin/env bash
set -euo pipefail

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
fake_bin="$root/bin"
state="$root/pkgs"
mkdir -p "$fake_bin"
cat > "$fake_bin/sudo" << 'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
cat > "$fake_bin/pacman" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
state_file="${RAVN_INTEL_PKGS_STATE:?}"
_last_pkg() {
  local pkg=""
  for arg in "$@"; do
    [[ $arg == -* ]] && continue
    pkg="$arg"
  done
  printf '%s\n' "$pkg"
}
case "${1:-}" in
  -Q)
    grep -qxF "$2" "$state_file"
    ;;
  -S)
    for arg in "$@"; do
      [[ $arg == -* ]] && continue
      grep -qxF "$arg" "$state_file" || printf '%s\n' "$arg" >> "$state_file"
    done
    ;;
  -Rns)
    pkg=$(_last_pkg "$@")
    tmp=$(mktemp)
    grep -vxF "$pkg" "$state_file" > "$tmp" || true
    mv "$tmp" "$state_file"
    ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fake_bin"/*
export PATH="$fake_bin:$PATH" RAVN_INTEL_PKGS_STATE="$state"
: > "$state"
# shellcheck disable=SC1090
source "$RAVN_TASK"

# ─── Docker lifecycle: package-behavior evidence ─────────────────────────────
# NOTE: This test validates pacman command convergence in a container.
# It does NOT validate real Intel HD 530 hardware — that requires a
# physical Skylake host with the GPU present.

admin_plan
admin_apply
admin_verify
admin_apply
admin_verify
admin_rollback
admin_verify_reset
admin_reset
admin_verify_reset
admin_apply
admin_verify

printf 'PASS: Intel HD 530 Docker lifecycle\n'
