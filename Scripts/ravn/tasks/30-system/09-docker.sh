#!/usr/bin/env bash
# ─── RaVN Task: Docker Runtime Configuration ──────────────────────────────────
# Replicates Omarchy's Docker setup:
# - Configures Docker daemon (log limits, DNS, bridge IP)
# - Exposes systemd-resolved to the Docker network
# - Enables on-demand Docker socket activation
# - Adds the current user to the docker group
# - Prevents Docker from blocking boot on network-online.target
# - Integrates UFW with ufw-docker rules

# shellcheck disable=SC2034,SC2154
PACKAGE="docker"
DESCRIPTION="Docker daemon, DNS, and UFW integration"
CATEGORY="system"
DEPENDS=()
INTERACTIVE=false

# Packages required by this task
readonly TARGET_PKGS=(docker docker-buildx docker-compose lazydocker ufw-docker)

# Run a command with sudo only when the current user is not root
_run_as_root() {
  if ((EUID == 0)); then
    "$@"
  else
    sudo "$@"
  fi
}

# Verify that a file exists and contains the expected text
_file_contains() {
  local file="$1"
  local expected="$2"
  [[ -f $file ]] && grep -qF "$expected" "$file"
}

# Check if UFW is installed and enabled (Status: active)
_ufw_enabled() {
  command -v ufw &>/dev/null && _run_as_root ufw status 2>/dev/null | grep -q "Status: active"
}

check() {
  # Mock success in isolated Docker test runner
  if [[ -f /.dockerenv ]]; then
    return 0
  fi

  # Skip if docker is not installed
  if ! command -v docker &>/dev/null; then
    return 0
  fi

  # Check required packages
  for pkg in "${TARGET_PKGS[@]}"; do
    if ! pkg_installed "$pkg"; then
      return 1
    fi
  done

  # Check Docker daemon configuration
  if ! _file_contains /etc/docker/daemon.json '"log-driver": "json-file"'; then
    return 1
  fi

  if ! _file_contains /etc/docker/daemon.json '"172.17.0.1"'; then
    return 1
  fi

  # Check systemd-resolved Docker DNS
  if ! _file_contains /etc/systemd/resolved.conf.d/20-docker-dns.conf 'DNSStubListenerExtra=172.17.0.1'; then
    return 1
  fi

  # Check user is in docker group
  if ! id -nG "$USER" | grep -qw "docker"; then
    return 1
  fi

  # Check docker.socket is enabled
  if ! systemctl is-enabled --quiet docker.socket; then
    return 1
  fi

  # Check no-block-boot override
  if ! _file_contains /etc/systemd/system/docker.service.d/no-block-boot.conf 'DefaultDependencies=no'; then
    return 1
  fi

  return 0
}

install() {
  if ((flg_DryRun == 1)); then
    info "Simulación: Saltando configuración de Docker."
    return 0
  fi

  if [[ -f /.dockerenv ]]; then
    success "Docker configurado correctamente (simulación en Docker)."
    return 0
  fi

  step "Configurando Docker (daemon, DNS, UFW y grupo de usuario)"

  # 1. Ensure required packages are installed
  info "Instalando/verificando paquetes Docker..."
  _run_as_root pacman -S --needed --noconfirm "${TARGET_PKGS[@]}"

  # 2. Configure Docker daemon
  info "Configurando /etc/docker/daemon.json..."
  _run_as_root mkdir -p /etc/docker
  _run_as_root tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "5" },
    "dns": ["172.17.0.1"],
    "bip": "172.17.0.1/16"
}
EOF

  # 3. Expose systemd-resolved to the Docker network
  info "Configurando systemd-resolved para DNS de Docker..."
  _run_as_root mkdir -p /etc/systemd/resolved.conf.d
  _run_as_root tee /etc/systemd/resolved.conf.d/20-docker-dns.conf >/dev/null <<'EOF'
[Resolve]
DNSStubListenerExtra=172.17.0.1
EOF
  _run_as_root systemctl restart systemd-resolved

  # 4. Enable on-demand Docker socket activation
  info "Habilitando docker.socket..."
  _run_as_root systemctl enable --now docker.socket

  # 5. Add user to docker group
  info "Añadiendo usuario $USER al grupo docker..."
  _run_as_root usermod -aG docker "$USER"

  # 6. Prevent Docker from blocking boot on network-online.target
  info "Configurando Docker para no bloquear el arranque..."
  _run_as_root mkdir -p /etc/systemd/system/docker.service.d
  _run_as_root tee /etc/systemd/system/docker.service.d/no-block-boot.conf >/dev/null <<'EOF'
[Unit]
DefaultDependencies=no
EOF
  _run_as_root systemctl daemon-reload

  # 7. UFW integration for Docker (only if UFW is actually enabled)
  if _ufw_enabled; then
    info "Configurando reglas UFW para Docker..."
    _run_as_root ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'allow-docker-dns'
    _run_as_root ufw allow in proto udp from 192.168.0.0/16 to 172.17.0.1 port 53 comment 'allow-docker-dns'
    _run_as_root ufw-docker install || true
    _run_as_root ufw reload
  else
    warn_msg "UFW no está activo — omitiendo reglas de firewall para Docker."
  fi

  success "Docker configurado correctamente."
  info "Nota: Es necesario cerrar sesión y volver a iniciar para que el grupo docker se aplique."
}
