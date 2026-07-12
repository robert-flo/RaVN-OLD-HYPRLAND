#!/usr/bin/env bash
# ─── RaVN Task: Cloudflare DNS and BBR ──────────────────────────────────────
# Configures systemd-resolved, NetworkManager, BBR, DNS blocking, and tools.

# shellcheck disable=SC2034
ADMIN_TASK_ID="dns-cloudflare"
# shellcheck disable=SC2034
ADMIN_TASK_FAMILY="system-config"
# shellcheck disable=SC2034
ADMIN_EXECUTION_PROFILE="privileged-system-config"
# shellcheck disable=SC2034
ADMIN_REQUIRES_PRIVILEGE=true
# shellcheck disable=SC2034
ADMIN_OWNED_RESOURCES=("Cloudflare system DNS" "NetworkManager Cloudflare DNS" "BBR sysctl configuration" "force-dns-override service" "ISP DNS firewall rules" "mtr speedtest-cli knot-dns")
# shellcheck disable=SC2034
ADMIN_RESOURCE_CONFLICTS=()
# shellcheck disable=SC2034
ADMIN_REVERSIBILITY="partially-reversible"
# shellcheck disable=SC2034
ADMIN_ACTIVATION_BOUNDARY="network restart or new session"
# shellcheck disable=SC2034
ADMIN_TEST_LEVEL="isolated,docker"

readonly DNS_PACKAGES=(mtr speedtest-cli knot-dns)
readonly DNS_SERVERS="1.1.1.1 1.0.0.1 9.9.9.9"
readonly DNS_ISP_SERVERS=(179.51.50.203 179.51.50.202)
readonly RESOLVED_CONF="${RAVN_DNS_RESOLVED_CONF:-/etc/systemd/resolved.conf}"
readonly NM_CONF="${RAVN_DNS_NM_CONF:-/etc/NetworkManager/conf.d/30-dns-cloudflare.conf}"
readonly DISPATCHER="${RAVN_DNS_DISPATCHER:-/etc/NetworkManager/dispatcher.d/force-cloudflare-dns}"
readonly BBR_CONF="${RAVN_DNS_BBR_CONF:-/etc/sysctl.d/99-bbr.conf}"
readonly OVERRIDE_SCRIPT="${RAVN_DNS_OVERRIDE_SCRIPT:-/usr/local/bin/force-dns-override.sh}"
readonly OVERRIDE_SERVICE="${RAVN_DNS_OVERRIDE_SERVICE:-/etc/systemd/system/force-dns-override.service}"
readonly RESOLV_LINK="${RAVN_DNS_RESOLV_LINK:-/etc/resolv.conf}"
readonly RESOLV_TARGET="/run/systemd/resolve/stub-resolv.conf"
readonly UFW_RULES="${RAVN_DNS_UFW_RULES:-/etc/ufw/before.rules}"
readonly BACKUP_DIR="${RAVN_DNS_BACKUP_DIR:-/var/lib/ravn/dns-cloudflare-backup}"
DNS_FILES_CREATED=()

_run_as_root() {
  if ((EUID == 0)); then
    "$@"
  else
    sudo "$@"
  fi
}

_pkg_installed() { _run_as_root pacman -Q "$1" > /dev/null 2>&1; }
_file_contains() { [[ -f $1 ]] && grep -qF "$2" "$1"; }
_service_enabled() { _run_as_root systemctl is-enabled --quiet "$1" 2> /dev/null; }
_service_active() { _run_as_root systemctl is-active --quiet "$1" 2> /dev/null; }

_all_packages_installed() {
  local package=""
  for package in "${DNS_PACKAGES[@]}"; do
    _pkg_installed "$package" || return 1
  done
}

_firewall_rule_present() {
  local server="$1"
  if command -v ufw > /dev/null 2>&1 && _service_active ufw; then
    _run_as_root ufw status 2> /dev/null | grep -q "$server"
  else
    _run_as_root iptables -L OUTPUT -n 2> /dev/null | grep -q "$server"
  fi
}

_write_file() {
  local file="$1"
  local directory
  directory=$(dirname "$file")
  _run_as_root mkdir -p "$directory" || return 1
  _run_as_root tee "$file" > /dev/null
}

_ensure_ufw_rules() {
  local server=""
  [[ -f $UFW_RULES ]] || return 0
  for server in "${DNS_ISP_SERVERS[@]}"; do
    if ! _file_contains "$UFW_RULES" "$server"; then
      {
        printf '%s\n' "# RaVN DNS Cloudflare: block ISP DNS $server"
        printf '%s\n' "-A ufw-before-output -d $server -p udp --dport 53 -j REJECT"
        printf '%s\n' "-A ufw-before-output -d $server -p tcp --dport 53 -j REJECT"
        printf '%s\n' "-A ufw-before-output -d $server -j REJECT"
      } | _run_as_root tee -a "$UFW_RULES" > /dev/null || return 1
    fi
  done
}

admin_plan() {
  ADMIN_PLAN_ACTIONS=(
    "install DNS diagnostic packages"
    "configure systemd-resolved and NetworkManager for Cloudflare DNS"
    "configure BBR kernel networking"
    "enable force-dns-override.service"
    "block ISP DNS servers"
  )
  command -v pacman > /dev/null 2>&1 &&
    command -v systemctl > /dev/null 2>&1 &&
    command -v iptables > /dev/null 2>&1
}

admin_apply() {
  local package=""
  admin_plan || return 1

  if ! _all_packages_installed; then
    _run_as_root pacman -S --needed --noconfirm "${DNS_PACKAGES[@]}" || return 1
  fi

  _run_as_root mkdir -p "$BACKUP_DIR" || return 1
  if [[ -f $RESOLVED_CONF && ! -f $BACKUP_DIR/resolved.conf ]]; then
    _run_as_root cp -p "$RESOLVED_CONF" "$BACKUP_DIR/resolved.conf" || return 1
  fi
  _write_file "$RESOLVED_CONF" << 'EOF' || return 1
[Resolve]
DNS=1.1.1.1 1.0.0.1 9.9.9.9
FallbackDNS=8.8.8.8 8.8.4.4
DNSOverTLS=yes
DNSSEC=allow-downgrade
LLMNR=no
MulticastDNS=no
Cache=yes
CacheFromLocalhost=no
DNSStubListener=yes
ReadEtcHosts=yes
Domains=~.
DNSDefaultRoute=yes
EOF

  if [[ $(readlink -f "$RESOLV_LINK" 2> /dev/null) != "$RESOLV_TARGET" ]]; then
    _run_as_root ln -sf "$RESOLV_TARGET" "$RESOLV_LINK" || return 1
  fi

  [[ -f $NM_CONF ]] || DNS_FILES_CREATED+=("$NM_CONF")
  _write_file "$NM_CONF" << 'EOF' || return 1
[main]
dns=default

[connection]
ipv4.dns=1.1.1.1,1.0.0.1,9.9.9.9
ipv4.ignore-auto-dns=true
wifi.powersave=2
ethernet.cloned-mac-address=preserve
EOF

  [[ -f $DISPATCHER ]] || DNS_FILES_CREATED+=("$DISPATCHER")
  _write_file "$DISPATCHER" << 'EOF' || return 1
#!/usr/bin/env bash
INTERFACE="$1"
ACTION="$2"
if [[ $INTERFACE == enp0s31f6 && $ACTION == up ]]; then
  /usr/bin/resolvectl dns "$INTERFACE" 1.1.1.1 1.0.0.1 9.9.9.9
  /usr/bin/resolvectl domain "$INTERFACE" '~.'
  /usr/bin/resolvectl dnsovertls "$INTERFACE" yes
fi
EOF
  _run_as_root chmod +x "$DISPATCHER" || return 1

  if command -v nmcli > /dev/null 2>&1; then
    local connection=""
    while IFS= read -r connection; do
      [[ -n $connection ]] || continue
      nmcli connection modify "$connection" ipv4.ignore-auto-dns yes || true
      nmcli connection modify "$connection" ipv4.dns "$DNS_SERVERS" || true
    done < <(nmcli -t -f NAME connection show --active 2> /dev/null || true)
  fi

  [[ -f $BBR_CONF ]] || DNS_FILES_CREATED+=("$BBR_CONF")
  _write_file "$BBR_CONF" << 'EOF' || return 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
EOF

  [[ -f $OVERRIDE_SCRIPT ]] || DNS_FILES_CREATED+=("$OVERRIDE_SCRIPT")
  _write_file "$OVERRIDE_SCRIPT" << 'EOF' || return 1
#!/usr/bin/env bash
sleep 3
if /usr/bin/resolvectl status enp0s31f6 &>/dev/null; then
  /usr/bin/resolvectl dns enp0s31f6 1.1.1.1 1.0.0.1 9.9.9.9
  /usr/bin/resolvectl domain enp0s31f6 '~.'
  /usr/bin/resolvectl dnsovertls enp0s31f6 yes
fi
for server in 179.51.50.203 179.51.50.202; do
  /usr/bin/iptables -C OUTPUT -d "$server" -j REJECT &>/dev/null || /usr/bin/iptables -I OUTPUT -d "$server" -j REJECT || true
done
EOF
  _run_as_root chmod +x "$OVERRIDE_SCRIPT" || return 1

  [[ -f $OVERRIDE_SERVICE ]] || DNS_FILES_CREATED+=("$OVERRIDE_SERVICE")
  _write_file "$OVERRIDE_SERVICE" << 'EOF' || return 1
[Unit]
Description=Force Cloudflare DNS on network interface
After=network-online.target systemd-resolved.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/force-dns-override.sh

[Install]
WantedBy=multi-user.target
EOF

  _run_as_root systemctl daemon-reload || return 1
  _run_as_root systemctl enable force-dns-override.service || return 1
  _run_as_root systemctl enable --now systemd-resolved || return 1
  _run_as_root systemctl restart systemd-resolved || return 1

  if command -v sysctl > /dev/null 2>&1; then
    _run_as_root sysctl --system > /dev/null 2>&1 || true
  fi
  if command -v NetworkManager > /dev/null 2>&1 || command -v nmcli > /dev/null 2>&1; then
    _run_as_root systemctl restart NetworkManager || true
  fi

  for package in "${DNS_ISP_SERVERS[@]}"; do
    _run_as_root iptables -C OUTPUT -d "$package" -j REJECT > /dev/null 2>&1 ||
      _run_as_root iptables -I OUTPUT -d "$package" -j REJECT || return 1
  done
  if [[ -f $UFW_RULES ]]; then
    _ensure_ufw_rules || return 1
    if command -v ufw > /dev/null 2>&1 && _service_active ufw; then
      _run_as_root ufw reload || return 1
    fi
  fi
}

admin_verify() {
  local server=""
  _all_packages_installed || return 1
  _file_contains "$RESOLVED_CONF" "DNS=$DNS_SERVERS" || return 1
  _file_contains "$NM_CONF" "ipv4.ignore-auto-dns=true" || return 1
  [[ -x $DISPATCHER ]] || return 1
  _file_contains "$BBR_CONF" "net.ipv4.tcp_congestion_control = bbr" || return 1
  [[ -x $OVERRIDE_SCRIPT && -f $OVERRIDE_SERVICE ]] || return 1
  _service_enabled force-dns-override.service || return 1
  for server in "${DNS_ISP_SERVERS[@]}"; do
    _firewall_rule_present "$server" || return 1
  done
}

admin_rollback() { admin_reset; }

admin_reset() {
  admin_plan || return 1
  _run_as_root systemctl disable --now force-dns-override.service > /dev/null 2>&1 || true
  local file=""
  for file in "${DNS_FILES_CREATED[@]}"; do
    _run_as_root rm -f "$file" || true
  done
  if [[ -f $BACKUP_DIR/resolved.conf ]]; then
    _run_as_root cp -p "$BACKUP_DIR/resolved.conf" "$RESOLVED_CONF" || true
  fi
  return 0
}

admin_verify_reset() {
  local file=""
  for file in "${DNS_FILES_CREATED[@]}"; do
    [[ -e $file ]] && return 1
  done
  return 0
}

check() { admin_verify; }
install() { admin_apply; }
verify() { admin_verify; }
reset() { admin_reset; }
verify_reset() { admin_verify_reset; }
