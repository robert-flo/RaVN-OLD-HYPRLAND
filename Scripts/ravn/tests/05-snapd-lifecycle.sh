#!/usr/bin/env bash
set -uo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
root=$(mktemp -d "${TMPDIR:-/tmp}/ravn-snapd-test.XXXXXX")
trap 'rm -rf "$root"' EXIT

fake_bin="$root/bin"
state_pkgs="$root/pkgs"
state_svcs="$root/svcs"
state_link="$root/link"
mkdir -p "$fake_bin"

cat > "$fake_bin/sudo" << 'EOF'
#!/usr/bin/env bash
exec "$@"
EOF

cat > "$fake_bin/pacman" << 'EOF'
#!/usr/bin/env bash
set -uo pipefail
state_file="${RAVN_SNAPD_PKGS_STATE:?}"
case "${1:-}" in
  -Q)
    grep -qxF "$2" "$state_file"
    ;;
  -S)
    [[ ${RAVN_SNAPD_SCENARIO:-active} != apply-failure ]] || exit 1
    for arg in "$@"; do
      [[ $arg == -* ]] && continue
      grep -qxF "$arg" "$state_file" || printf '%s\n' "$arg" >> "$state_file"
    done
    ;;
  *) exit 2 ;;
esac
EOF

cat > "$fake_bin/yay" << 'EOF'
#!/usr/bin/env bash
printf 'yay\n' >> "${RAVN_SNAPD_INSTALLERS_STATE:?}"
exec pacman "$@"
EOF

cat > "$fake_bin/systemctl" << 'EOF'
#!/usr/bin/env bash
set -uo pipefail
state_file="${RAVN_SNAPD_SVCS_STATE:?}"
_svc() {
  local svc=""
  for arg in "$@"; do
    [[ $arg == -* ]] && continue
    svc="$arg"
  done
  printf '%s\n' "$svc"
}
_is_enabled() { grep -qxF "$1=enabled" "$state_file"; }
_is_active()  { grep -qxF "$1=active"  "$state_file"; }
_set()        { printf '%s=%s\n' "$1" "$2" >> "$state_file"; }
_unset() {
  local tmp
  tmp=$(mktemp)
  grep -vxF -e "$1=enabled" -e "$1=active" "$state_file" > "$tmp" || true
  mv "$tmp" "$state_file"
}

case "${1:-}" in
  is-enabled)
    _is_enabled "$(_svc "$@")"
    ;;
  is-active)
    _is_active "$(_svc "$@")"
    ;;
  enable)
    [[ ${RAVN_SNAPD_SCENARIO:-active} != apply-failure ]] || exit 1
    _set "$(_svc "$@")" enabled
    if [[ $* == *--now* ]]; then
      _set "$(_svc "$@")" active
    fi
    ;;
  disable)
    _unset "$(_svc "$@")"
    ;;
  *) exit 2 ;;
esac
EOF

cat > "$fake_bin/ln" << 'EOF'
#!/usr/bin/env bash
[[ ${RAVN_SNAPD_SCENARIO:-active} != apply-failure ]] || exit 1
printf 'present\n' > "${RAVN_SNAPD_LINK_STATE:?}"
EOF

cat > "$fake_bin/rm" << 'EOF'
#!/usr/bin/env bash
[[ ${1:-} == -f ]] && shift
[[ ${1:-} == /snap ]] && printf 'absent\n' > "${RAVN_SNAPD_LINK_STATE:?}"
EOF

chmod +x "$fake_bin"/*

export PATH="$fake_bin:$PATH"
export RAVN_SNAPD_PKGS_STATE="$state_pkgs"
export RAVN_SNAPD_SVCS_STATE="$state_svcs"
export RAVN_SNAPD_LINK_STATE="$state_link"
export RAVN_SNAPD_INSTALLERS_STATE="$root/installers"
printf 'absent\n' > "$state_link"
: > "$state_pkgs"
: > "$state_svcs"
: > "$RAVN_SNAPD_INSTALLERS_STATE"
# shellcheck disable=SC1090,SC1091
source "$RAVN_DIR/tasks/90-system/05-snapd.sh"

# Override symlink check - the real [[ -L /snap ]] can't be faked as it's a
# shell builtin. Symlink creation/removal is verified in the Docker test.
_symlink_correct() {
  [[ "$(cat "${RAVN_SNAPD_LINK_STATE:?}")" == present ]]
}

# --- Happy path --------------------------------------------------------------
admin_plan
admin_apply
admin_verify

# --- AUR installer path ------------------------------------------------------
grep -qxF yay "$RAVN_SNAPD_INSTALLERS_STATE" || {
  printf 'FAIL: yay installer path was not used\n' >&2
  exit 1
}
admin_apply
admin_verify

# --- Dry-run leaves the desired state unchanged -----------------------------
: > "$state_pkgs"
: > "$state_svcs"
printf 'absent\n' > "$state_link"
flg_DryRun=1
admin_apply
[[ ! -s $state_pkgs && ! -s $state_svcs ]] || {
  printf 'FAIL: dry-run changed snapd state\n' >&2
  exit 1
}
# shellcheck disable=SC2034
flg_DryRun=0
admin_rollback
admin_verify_reset
admin_reset
admin_verify_reset
admin_apply
admin_verify

# --- Already-satisfied state -------------------------------------------------
if ! admin_apply; then
  printf 'FAIL: apply returned non-zero on already-satisfied state\n' >&2
  exit 1
fi
admin_verify

# --- Apply failure -----------------------------------------------------------
: > "$state_pkgs"
: > "$state_svcs"
printf 'absent\n' > "$state_link"
export RAVN_SNAPD_SCENARIO=apply-failure
if admin_apply; then
  printf 'FAIL: systemctl enable failure unexpectedly passed\n' >&2
  exit 1
fi

# --- Reset with nothing applied ----------------------------------------------
export RAVN_SNAPD_SCENARIO=active
printf 'absent\n' > "$state_link"
: > "$state_pkgs"
: > "$state_svcs"
printf '%s\n' snapd > "$state_pkgs"
admin_reset
admin_verify_reset

# --- Services already disabled, symlink absent -------------------------------
admin_reset
admin_verify_reset

printf 'PASS: snapd administrative lifecycle\n'
