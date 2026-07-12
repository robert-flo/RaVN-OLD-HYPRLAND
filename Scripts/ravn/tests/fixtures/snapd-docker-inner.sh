#!/usr/bin/env bash
set -euo pipefail
root=$(mktemp -d)
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
state_file="${RAVN_SNAPD_PKGS_STATE:?}"
case "${1:-}" in
  -Q) grep -qxF "$2" "$state_file" ;;
  -S) for arg in "$@"; do [[ $arg == -* ]] && continue; grep -qxF "$arg" "$state_file" || printf '%s\n' "$arg" >> "$state_file"; done ;;
  *) exit 2 ;;
esac
EOF
cat > "$fake_bin/systemctl" << 'EOF'
#!/usr/bin/env bash
state_file="${RAVN_SNAPD_SVCS_STATE:?}"
_svc() { local svc=""; for arg in "$@"; do [[ $arg == -* ]] && continue; svc="$arg"; done; printf '%s\n' "$svc"; }
_is_enabled() { grep -qxF "$1=enabled" "$state_file"; }
_is_active()  { grep -qxF "$1=active"  "$state_file"; }
_set()        { printf '%s=%s\n' "$1" "$2" >> "$state_file"; }
_unset() { local tmp; tmp=$(mktemp); grep -vxF -e "$1=enabled" -e "$1=active" "$state_file" > "$tmp" || true; mv "$tmp" "$state_file"; }
case "${1:-}" in
  is-enabled) _is_enabled "$(_svc "$@")" ;;
  is-active)  _is_active  "$(_svc "$@")" ;;
  enable)     _set "$(_svc "$@")" enabled; [[ $* == *--now* ]] && _set "$(_svc "$@")" active ;;
  disable)    _unset "$(_svc "$@")" ;;
  *) exit 2 ;;
esac
EOF
cat > "$fake_bin/ln" << 'EOF'
#!/usr/bin/env bash
printf 'present\n' > "${RAVN_SNAPD_LINK_STATE:?}"
EOF
cat > "$fake_bin/rm" << 'EOF'
#!/usr/bin/env bash
[[ ${1:-} == -f ]] && shift
[[ ${1:-} == /snap ]] && printf 'absent\n' > "${RAVN_SNAPD_LINK_STATE:?}"
EOF
chmod +x "$fake_bin"/*
export PATH="$fake_bin:$PATH" RAVN_SNAPD_PKGS_STATE="$state_pkgs" RAVN_SNAPD_SVCS_STATE="$state_svcs" RAVN_SNAPD_LINK_STATE="$state_link"
printf 'absent\n' > "$state_link"
: > "$state_pkgs"
: > "$state_svcs"
# shellcheck disable=SC1090
source "$RAVN_TASK"
_symlink_correct() {
  [[ "$(cat "${RAVN_SNAPD_LINK_STATE:?}")" == present ]]
}
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
printf 'PASS: snapd Docker lifecycle\n'
