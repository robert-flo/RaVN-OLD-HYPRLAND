#!/usr/bin/env bash
# ─── RaVN Task: Aggressive Cloudflare DNS & BBR ──────────────────────────────
# Configures aggressive Cloudflare DNS via systemd-resolved,
# sets NetworkManager to use system DNS and ignore DHCP DNS,
# configures kernel network optimizations (TCP/BBR),
# blocks ISP DNS servers in the firewall,
# and installs mtr/speedtest-cli/knot-dns.
#
# Adopted from NixOS configuration & setup-dns-cloudflare (3).sh

# shellcheck disable=SC2034,SC2154
PACKAGE="dns-cloudflare"
DESCRIPTION="Configure aggressive Cloudflare DNS, systemd-resolved, and kernel optimizations"
CATEGORY="system"
DEPENDS=()
INTERACTIVE=false

# ── benchmark DNS por DoT (puerto 853) ────────────────────────────────────────
dot_latency() {
  local server="$1"
  local label="$2"
  local domain="github.com"

  if ! command -v kdig &> /dev/null; then
    echo -e "    ${_YELLOW}${label}:${_RESET} kdig no disponible"
    return
  fi

  local start end ms output
  start=$(date +%s%3N)
  output=$(kdig +tls "@${server}" "$domain" 2>&1)
  end=$(date +%s%3N)

  if echo "$output" | grep -q "NOERROR"; then
    ms=$((end - start))
    echo -e "    ${_GREEN}${label}:${_RESET} ${_BOLD}${ms} ms${_RESET} (DoT/853)"
  else
    echo -e "    ${_YELLOW}${label}:${_RESET} timeout o error"
  fi
}

check() {
  # 1. Check resolved.conf DNS settings
  if [[ ! -f /etc/systemd/resolved.conf ]] || ! grep -q "DNS=1.1.1.1 1.0.0.1 9.9.9.9" /etc/systemd/resolved.conf; then
    return 1
  fi

  # 2. Check NetworkManager dispatcher script
  if [[ ! -x /etc/NetworkManager/dispatcher.d/force-cloudflare-dns ]]; then
    return 1
  fi

  # 3. Check NetworkManager global config drop-in
  if [[ ! -f /etc/NetworkManager/conf.d/30-dns-cloudflare.conf ]]; then
    return 1
  fi

  # 4. Check sysctl BBR configuration
  if [[ ! -f /etc/sysctl.d/99-bbr.conf ]] || ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.d/99-bbr.conf; then
    return 1
  fi

  # 5. Check systemd service exists and is enabled
  if ! systemctl is-enabled --quiet force-dns-override.service &> /dev/null; then
    return 1
  fi

  # 6. Check firewall rules (UFW or raw iptables)
  if command -v ufw &> /dev/null && systemctl is-active --quiet ufw; then
    if ! sudo ufw status | grep -q "179.51.50.203"; then
      return 1
    fi
  else
    if ! sudo iptables -L OUTPUT -n | grep -q "179.51.50.203"; then
      return 1
    fi
  fi

  # 7. Check if required packages are installed
  if ! pkg_installed mtr || ! pkg_installed speedtest-cli || ! pkg_installed knot-dns; then
    return 1
  fi

  return 0
}

install() {
  if ((flg_DryRun == 1)); then
    info "Simulación: Saltando la instalación de la configuración de DNS Cloudflare y BBR."
    return 0
  fi

  # Instalar dependencias si faltan
  local pkgs_to_install=()
  for pkg in mtr speedtest-cli knot-dns; do
    if ! pkg_installed "$pkg"; then
      pkgs_to_install+=("$pkg")
    fi
  done

  if ((${#pkgs_to_install[@]} > 0)); then
    info "Instalando paquetes requeridos: ${pkgs_to_install[*]}"
    if ! sudo pacman -S --noconfirm "${pkgs_to_install[@]}"; then
      warn_msg "No se pudieron instalar algunos paquetes (${pkgs_to_install[*]})."
    fi
  fi

  # 1. Configurar systemd-resolved
  step "Configurando systemd-resolved"
  local resolved_conf="/etc/systemd/resolved.conf"
  if [[ ! -f "${resolved_conf}.bak" ]]; then
    sudo cp "$resolved_conf" "${resolved_conf}.bak"
  fi

  cat << 'EOF' | sudo tee "$resolved_conf" > /dev/null
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

  if [[ $(readlink -f /etc/resolv.conf) != "/run/systemd/resolve/stub-resolv.conf" ]]; then
    info "Creando enlace simbólico para /etc/resolv.conf -> systemd-resolved..."
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  fi

  sudo systemctl daemon-reload
  sudo systemctl enable --now systemd-resolved
  sudo systemctl restart systemd-resolved

  # 2. Configurar NetworkManager
  step "Configurando NetworkManager"
  sudo mkdir -p /etc/NetworkManager/conf.d
  cat << 'EOF' | sudo tee /etc/NetworkManager/conf.d/30-dns-cloudflare.conf > /dev/null
[main]
dns=default

[connection]
ipv4.dns=1.1.1.1,1.0.0.1,9.9.9.9
ipv4.ignore-auto-dns=true
wifi.powersave=2
ethernet.cloned-mac-address=preserve
EOF

  # Dispatcher script
  sudo mkdir -p /etc/NetworkManager/dispatcher.d
  cat << 'EOF' | sudo tee /etc/NetworkManager/dispatcher.d/force-cloudflare-dns > /dev/null
#!/usr/bin/env bash
# Runs on every network state change

INTERFACE="$1"
ACTION="$2"

# Only act on ethernet interface when it comes up
if [[ $INTERFACE == "enp0s31f6" && $ACTION == "up" ]]; then
  # Force Cloudflare DNS
  /usr/bin/resolvectl dns "$INTERFACE" 1.1.1.1 1.0.0.1 9.9.9.9
  /usr/bin/resolvectl domain "$INTERFACE" '~.'
  /usr/bin/resolvectl dnsovertls "$INTERFACE" yes

  # Log for debugging
  echo "$(date): Forced DNS on $INTERFACE" >> /var/log/dns-override.log
  /usr/bin/resolvectl status "$INTERFACE" >> /var/log/dns-override.log
fi
EOF

  sudo chmod +x /etc/NetworkManager/dispatcher.d/force-cloudflare-dns

  # Modificar conexiones activas en caliente
  local conn_list
  if conn_list=$(nmcli -t -f NAME connection show --active 2> /dev/null); then
    while read -r conn; do
      if [[ -n $conn ]]; then
        nmcli connection modify "$conn" ipv4.ignore-auto-dns yes
        nmcli connection modify "$conn" ipv4.dns "1.1.1.1 1.0.0.1 9.9.9.9"
      fi
    done <<< "$conn_list"
  fi

  sudo systemctl restart NetworkManager

  # 3. Optimizaciones del Kernel (sysctl/BBR)
  step "Configurando optimizaciones de Kernel (sysctl/BBR)"
  cat << 'EOF' | sudo tee /etc/sysctl.d/99-bbr.conf > /dev/null
# ──── TCP Buffer Sizes ───────────────────────────────────────────
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# ──── BBR Congestion Control ─────────────────────────────────────
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# ──── Latency Reduction ─────────────────────────────────────────
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0

# Optimizaciones para alta latencia
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1

# ──── TCP Timeouts ─────────────────────────────────────────────
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
EOF

  sudo sysctl --system &> /dev/null

  # 4. Servicio de arranque force-dns-override
  step "Creando servicio systemd force-dns-override"
  cat << 'EOF' | sudo tee /usr/local/bin/force-dns-override.sh > /dev/null
#!/usr/bin/env bash
# Wait for network to be ready
sleep 3

# Force DNS on ethernet interface if active
if /usr/bin/resolvectl status enp0s31f6 &>/dev/null; then
  /usr/bin/resolvectl dns enp0s31f6 1.1.1.1 1.0.0.1 9.9.9.9
  /usr/bin/resolvectl domain enp0s31f6 '~.'
  /usr/bin/resolvectl dnsovertls enp0s31f6 yes
fi

# Apply firewall rules to reject any DNS queries to ISP servers (if not already applied in OUTPUT)
/usr/bin/iptables -C OUTPUT -d 179.51.50.203 -p udp --dport 53 -j REJECT &>/dev/null || /usr/bin/iptables -I OUTPUT -d 179.51.50.203 -p udp --dport 53 -j REJECT || true
/usr/bin/iptables -C OUTPUT -d 179.51.50.203 -p tcp --dport 53 -j REJECT &>/dev/null || /usr/bin/iptables -I OUTPUT -d 179.51.50.203 -p tcp --dport 53 -j REJECT || true
/usr/bin/iptables -C OUTPUT -d 179.51.50.202 -p udp --dport 53 -j REJECT &>/dev/null || /usr/bin/iptables -I OUTPUT -d 179.51.50.202 -p udp --dport 53 -j REJECT || true
/usr/bin/iptables -C OUTPUT -d 179.51.50.202 -p tcp --dport 53 -j REJECT &>/dev/null || /usr/bin/iptables -I OUTPUT -d 179.51.50.202 -p tcp --dport 53 -j REJECT || true
/usr/bin/iptables -C OUTPUT -d 179.51.50.203 -j REJECT &>/dev/null || /usr/bin/iptables -I OUTPUT -d 179.51.50.203 -j REJECT || true
/usr/bin/iptables -C OUTPUT -d 179.51.50.202 -j REJECT &>/dev/null || /usr/bin/iptables -I OUTPUT -d 179.51.50.202 -j REJECT || true

# Log applied settings
echo "=== DNS Override Applied ===" > /var/log/dns-override.log
date >> /var/log/dns-override.log
if /usr/bin/resolvectl status enp0s31f6 &>/dev/null; then
  /usr/bin/resolvectl status enp0s31f6 >> /var/log/dns-override.log
fi

# Verify firewall rules are active
echo "=== Firewall Rules ===" >> /var/log/dns-override.log
/usr/bin/iptables -L OUTPUT -n | grep 179.51 >> /var/log/dns-override.log || echo "No firewall rules found" >> /var/log/dns-override.log
EOF

  sudo chmod +x /usr/local/bin/force-dns-override.sh

  cat << 'EOF' | sudo tee /etc/systemd/system/force-dns-override.service > /dev/null
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

  sudo systemctl daemon-reload
  sudo systemctl enable force-dns-override.service

  # 5. Integración con UFW para bloqueos
  if [[ -f /etc/ufw/before.rules ]]; then
    step "Configurando bloqueos de DNS ISP en UFW"
    if ! grep -q "179.51.50.203" /etc/ufw/before.rules; then
      info "Insertando reglas en /etc/ufw/before.rules..."
      sudo sed -i '/-A ufw-before-output -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT/a \
# Block ISP DNS\n-A ufw-before-output -d 179.51.50.203 -p udp --dport 53 -j REJECT\n-A ufw-before-output -d 179.51.50.203 -p tcp --dport 53 -j REJECT\n-A ufw-before-output -d 179.51.50.202 -p udp --dport 53 -j REJECT\n-A ufw-before-output -d 179.51.50.202 -p tcp --dport 53 -j REJECT\n-A ufw-before-output -d 179.51.50.203 -j REJECT\n-A ufw-before-output -d 179.51.50.202 -j REJECT' /etc/ufw/before.rules

      if systemctl is-active --quiet ufw; then
        sudo ufw reload
      fi
    fi
  fi

  # Aplicar en caliente para la sesión actual
  info "Aplicando reglas de bloqueo en caliente..."
  sudo iptables -C OUTPUT -d 179.51.50.203 -p udp --dport 53 -j REJECT &> /dev/null || sudo iptables -I OUTPUT -d 179.51.50.203 -p udp --dport 53 -j REJECT
  sudo iptables -C OUTPUT -d 179.51.50.203 -p tcp --dport 53 -j REJECT &> /dev/null || sudo iptables -I OUTPUT -d 179.51.50.203 -p tcp --dport 53 -j REJECT
  sudo iptables -C OUTPUT -d 179.51.50.202 -p udp --dport 53 -j REJECT &> /dev/null || sudo iptables -I OUTPUT -d 179.51.50.202 -p udp --dport 53 -j REJECT
  sudo iptables -C OUTPUT -d 179.51.50.202 -p tcp --dport 53 -j REJECT &> /dev/null || sudo iptables -I OUTPUT -d 179.51.50.202 -p tcp --dport 53 -j REJECT
  sudo iptables -C OUTPUT -d 179.51.50.203 -j REJECT &> /dev/null || sudo iptables -I OUTPUT -d 179.51.50.203 -j REJECT
  sudo iptables -C OUTPUT -d 179.51.50.202 -j REJECT &> /dev/null || sudo iptables -I OUTPUT -d 179.51.50.202 -j REJECT

  # Latencia final DoT
  if command -v kdig &> /dev/null; then
    info "Verificando latencias DoT activas:"
    dot_latency "1.1.1.1"     "  cloudflare (1.1.1.1) "
    dot_latency "1.0.0.1"     "  cloudflare (1.0.0.1) "
    dot_latency "9.9.9.9"     "  quad9      (9.9.9.9)  "
    dot_latency "8.8.8.8"     "  google     (8.8.8.8)  "
  fi

  success "DNS Cloudflare agresivo y optimizaciones de red aplicados exitosamente."
}
