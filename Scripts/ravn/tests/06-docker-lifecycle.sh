#!/usr/bin/env bash
set -uo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
root=$(mktemp -d "${TMPDIR:-/tmp}/ravn-docker-test.XXXXXX")
trap 'rm -rf "$root"' EXIT

fake_bin="$root/bin"
state_pkgs="$root/pkgs"
state_svcs="$root/svcs"
state_ufw="$root/ufw"
state_user="$root/user"
state_files="$root/files"
mkdir -p "$fake_bin" "$state_files"

cat > "$fake_bin/sudo" << 'EOF'
#!/usr/bin/env bash
exec "$@"
EOF

cat > "$fake_bin/pacman" << 'EOF'
#!/usr/bin/env bash
state_file="${RAVN_DOCKER_PKGS_STATE:?}"
case "${1:-}" in
  -Q) grep -qxF "$2" "$state_file" ;;
  -S) [[ ${RAVN_DOCKER_SCENARIO:-active} != apply-failure ]] || exit 1
      for arg in "$@"; do [[ $arg == -* ]] && continue; grep -qxF "$arg" "$state_file" || printf '%s\n' "$arg" >> "$state_file"; done ;;
  *) exit 2 ;;
esac
EOF

cat > "$fake_bin/systemctl" << 'EOF'
#!/usr/bin/env bash
state_file="${RAVN_DOCKER_SVCS_STATE:?}"
_svc() { local svc=""; for arg in "$@"; do [[ $arg == -* ]] && continue; svc="$arg"; done; printf '%s\n' "$svc"; }
_is_enabled() { grep -qxF "$1=enabled" "$state_file"; }
_is_active()  { grep -qxF "$1=active" "$state_file"; }
_set()        { printf '%s=%s\n' "$1" "$2" >> "$state_file"; }
_unset() { local tmp; tmp=$(mktemp); grep -vxF "$1=enabled" "$state_file" > "$tmp" || true; mv "$tmp" "$state_file"; }
case "${1:-}" in
  is-enabled) _is_enabled "$(_svc "$@")" ;;
  is-active)  _is_active "$(_svc "$@")" ;;
  enable)     [[ ${RAVN_DOCKER_SCENARIO:-active} != apply-failure ]] || exit 1; _set "$(_svc "$@")" enabled; [[ $* == *--now* ]] && _set "$(_svc "$@")" active ;;
  restart|daemon-reload) : ;;
  disable)    _unset "$(_svc "$@")" ;;
  *) exit 2 ;;
esac
EOF

cat > "$fake_bin/tee" << 'EOF'
#!/usr/bin/env bash
[[ ${RAVN_DOCKER_SCENARIO:-active} != apply-failure ]] || exit 1
target="${RAVN_DOCKER_FILES_DIR:?}/$(basename "${!#}")"
mkdir -p "$(dirname "$target")" || true
cat >> "$target"
EOF

cat > "$fake_bin/mkdir" << 'EOF'
#!/usr/bin/env bash
:
EOF

cat > "$fake_bin/id" << 'EOF'
#!/usr/bin/env bash
[[ -f ${RAVN_DOCKER_USER_STATE:?} ]] && cat "$RAVN_DOCKER_USER_STATE"
EOF

cat > "$fake_bin/usermod" << 'EOF'
#!/usr/bin/env bash
[[ ${RAVN_DOCKER_SCENARIO:-active} != apply-failure ]] || exit 1
printf 'docker\n' > "${RAVN_DOCKER_USER_STATE:?}"
EOF

cat > "$fake_bin/gpasswd" << 'EOF'
#!/usr/bin/env bash
: > "${RAVN_DOCKER_USER_STATE:?}"
EOF

cat > "$fake_bin/ufw" << 'EOF'
#!/usr/bin/env bash
state_file="${RAVN_DOCKER_UFW_STATE:?}"
case "${1:-}" in
  status) cat "$state_file" ;;
  allow) printf '%s\n' "$*" >> "$state_file" ;;
  *) exit 2 ;;
esac
EOF

cat > "$fake_bin/ufw-docker" << 'EOF'
#!/usr/bin/env bash
:
EOF

cat > "$fake_bin/rm" << 'EOF'
#!/usr/bin/env bash
while [[ ${1:-} == -* ]]; do shift; done
target="${RAVN_DOCKER_FILES_DIR:?}/$(basename "${1:-}")"
[ -f "$target" ] && : > "$target"
EOF

chmod +x "$fake_bin"/*

export PATH="$fake_bin:$PATH"
export RAVN_DOCKER_PKGS_STATE="$state_pkgs"
export RAVN_DOCKER_SVCS_STATE="$state_svcs"
export RAVN_DOCKER_UFW_STATE="$state_ufw"
export RAVN_DOCKER_USER_STATE="$state_user"
export RAVN_DOCKER_FILES_DIR="$state_files"
: > "$state_pkgs"
: > "$state_svcs"
printf 'Status: inactive\n' > "$state_ufw"
: > "$state_user"
# shellcheck disable=SC1090,SC1091
source "$RAVN_DIR/tasks/90-system/06-docker.sh"

_file_contains() {
  local file="$1"
  local expected="$2"
  local name
  name=$(basename "$file")
  [[ -f $state_files/$name ]] && grep -qF "$expected" "$state_files/$name"
}

_ufw_active() {
  [[ ${RAVN_DOCKER_UFW_SCENARIO:-inactive} == active ]]
}

_user_in_docker_group() {
  grep -qw "docker" "$RAVN_DOCKER_USER_STATE" 2> /dev/null
}

# ─── Happy path ──────────────────────────────────────────────────────────────
admin_plan
admin_apply
admin_verify
admin_apply
admin_verify

# ─── Dry-run leaves the desired state unchanged -----------------------------
: > "$state_pkgs"
: > "$state_svcs"
rm -rf "${state_files:?}"/*
: > "$state_user"
# shellcheck disable=SC2034
flg_DryRun=1
admin_apply
[[ ! -s $state_pkgs && ! -s $state_svcs && ! -s $state_user ]] || {
  printf 'FAIL: dry-run changed Docker state\n' >&2
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

# ─── Already-satisfied state ────────────────────────────────────────────────
if ! admin_apply; then
  printf 'FAIL: apply returned non-zero on already-satisfied state\n' >&2
  exit 1
fi
admin_verify

# ─── Apply failure ───────────────────────────────────────────────────────────
: > "$state_pkgs"
: > "$state_svcs"
rm -rf "${state_files:?}"/*
: > "$state_user"
export RAVN_DOCKER_SCENARIO=apply-failure
if admin_apply; then
  printf 'FAIL: apply failure unexpectedly passed\n' >&2
  exit 1
fi

# ─── UFW integration when active ────────────────────────────────────────────
export RAVN_DOCKER_SCENARIO=active
export RAVN_DOCKER_UFW_SCENARIO=active
printf 'Status: active\n' > "$state_ufw"
: > "$state_pkgs"
: > "$state_svcs"
rm -rf "${state_files:?}"/*
: > "$state_user"
admin_apply
admin_verify

# ─── Reset with everything applied ──────────────────────────────────────────
admin_reset
admin_verify_reset

printf 'PASS: docker administrative lifecycle\n'
