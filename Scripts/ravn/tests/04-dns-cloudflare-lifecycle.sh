#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
root=$(mktemp -d "${TMPDIR:-/tmp}/ravn-dns-cloudflare-test.XXXXXX")
trap 'rm -rf "$root"' EXIT

fake_bin="$root/bin"
mkdir -p "$fake_bin" "$root/etc/NetworkManager/conf.d" "$root/etc/NetworkManager/dispatcher.d" "$root/etc/systemd/system" "$root/usr/local/bin" "$root/sysctl.d"
: > "$root/packages"
: > "$root/services"
: > "$root/iptables"

cat > "$fake_bin/pacman" << 'EOF'
#!/usr/bin/env bash
state=${RAVN_DNS_PACKAGES:?}
case ${1:-} in
  -Q) grep -qxF "$2" "$state" ;;
  -S) for arg in "$@"; do [[ $arg == -* ]] || grep -qxF "$arg" "$state" || printf '%s\n' "$arg" >> "$state"; done ;;
  *) exit 2 ;;
esac
EOF
cat > "$fake_bin/systemctl" << 'EOF'
#!/usr/bin/env bash
state=${RAVN_DNS_SERVICES:?}
unit="${@: -1}"
case ${1:-} in
  is-enabled) grep -qxF "$unit=enabled" "$state" ;;
  is-active) grep -qxF "$unit=active" "$state" ;;
  enable)
    printf '%s\n' "$unit=enabled" >> "$state"
    if [[ $* == *--now* ]]; then
      printf '%s\n' "$unit=active" >> "$state"
    fi
    ;;
  restart|daemon-reload) : ;;
  *) : ;;
esac
EOF
cat > "$fake_bin/iptables" << 'EOF'
#!/usr/bin/env bash
state=${RAVN_DNS_IPTABLES:?}
server=""
for arg in "$@"; do [[ $arg == 179.* ]] && server=$arg; done
case ${1:-} in
  -C) grep -qxF "$server" "$state" ;;
  -I) grep -qxF "$server" "$state" || printf '%s\n' "$server" >> "$state" ;;
  -L) cat "$state" ;;
esac
EOF
cat > "$fake_bin/tee" << 'EOF'
#!/usr/bin/env bash
target=${!#}
mkdir -p "$(dirname "$target")"
cat > "$target"
EOF
cat > "$fake_bin/sudo" << 'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
cat > "$fake_bin/readlink" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' /run/systemd/resolve/stub-resolv.conf
EOF
chmod +x "$fake_bin"/*

export PATH="$fake_bin:$PATH"
export RAVN_DNS_PACKAGES="$root/packages" RAVN_DNS_SERVICES="$root/services" RAVN_DNS_IPTABLES="$root/iptables"
export RAVN_DNS_RESOLVED_CONF="$root/etc/systemd/resolved.conf"
export RAVN_DNS_NM_CONF="$root/etc/NetworkManager/conf.d/30-dns-cloudflare.conf"
export RAVN_DNS_DISPATCHER="$root/etc/NetworkManager/dispatcher.d/force-cloudflare-dns"
export RAVN_DNS_BBR_CONF="$root/sysctl.d/99-bbr.conf"
export RAVN_DNS_OVERRIDE_SCRIPT="$root/usr/local/bin/force-dns-override.sh"
export RAVN_DNS_OVERRIDE_SERVICE="$root/etc/systemd/system/force-dns-override.service"
export RAVN_DNS_RESOLV_LINK="$root/etc/resolv.conf"
export RAVN_DNS_BACKUP_DIR="$root/backup"
export RAVN_DNS_UFW_RULES="$root/etc/ufw/before.rules"

# shellcheck disable=SC1091
source "$RAVN_DIR/tasks/90-system/04-dns-cloudflare.sh"
admin_plan
admin_apply
admin_verify
admin_apply
admin_verify
admin_reset
admin_verify_reset
admin_apply
admin_verify
printf 'PASS: dns-cloudflare administrative lifecycle\n'
