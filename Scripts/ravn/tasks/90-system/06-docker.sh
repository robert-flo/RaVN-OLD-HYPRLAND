#!/usr/bin/env bash
# ─── RaVN Task: Docker Runtime Configuration ────────────────────────────────
# Manages Docker daemon, systemd-resolved DNS, socket activation, user group,
# no-block-boot override, and conditional UFW integration.

# shellcheck disable=SC2034
ADMIN_TASK_ID="docker"
# shellcheck disable=SC2034
ADMIN_TASK_FAMILY="system-config"
# shellcheck disable=SC2034
ADMIN_EXECUTION_PROFILE="privileged-system-config"
# shellcheck disable=SC2034
ADMIN_REQUIRES_PRIVILEGE=true
# shellcheck disable=SC2034
ADMIN_OWNED_RESOURCES=("docker packages" "/etc/docker/daemon.json" "/etc/systemd/resolved.conf.d/20-docker-dns.conf" "docker.socket" "docker user group" "/etc/systemd/system/docker.service.d/no-block-boot.conf" "ufw docker rules")
# shellcheck disable=SC2034
ADMIN_RESOURCE_CONFLICTS=()
# shellcheck disable=SC2034
ADMIN_REVERSIBILITY="partially-reversible"
# shellcheck disable=SC2034
ADMIN_ACTIVATION_BOUNDARY="new session or systemctl daemon-reload"
# shellcheck disable=SC2034
ADMIN_TEST_LEVEL="isolated,docker"

readonly DOCKER_PKGS=(docker docker-buildx docker-compose lazydocker ufw-docker)
readonly DAEMON_JSON="${RAVN_DOCKER_DAEMON_JSON:-/etc/docker/daemon.json}"
readonly RESOLVED_DNS_CONF="${RAVN_DOCKER_RESOLVED_DNS_CONF:-/etc/systemd/resolved.conf.d/20-docker-dns.conf}"
readonly NO_BLOCK_CONF="${RAVN_DOCKER_NO_BLOCK_CONF:-/etc/systemd/system/docker.service.d/no-block-boot.conf}"
readonly DOCKER_SOCKET="docker.socket"
flg_DryRun=${flg_DryRun:-0}
DOCKER_FILES_CREATED=()
DOCKER_GROUP_ADDED_BY_TASK=false
DOCKER_SOCKET_ENABLED_BY_TASK=false

_run_as_root() {
  if ((EUID == 0)); then
    "$@"
  else
    sudo "$@"
  fi
}

_can_elevate() {
  ((EUID == 0)) || command -v sudo > /dev/null 2>&1
}

_pkg_installed() {
  _run_as_root pacman -Q "$1" > /dev/null 2>&1
}

_file_contains() {
  local file="$1"
  local expected="$2"
  [[ -f $file ]] && grep -qF "$expected" "$file"
}

_ufw_active() {
  command -v ufw > /dev/null 2>&1 && _run_as_root ufw status 2> /dev/null | grep -q "Status: active"
}

_systemctl_enabled() {
  _run_as_root systemctl is-enabled --quiet "$1" 2> /dev/null
}

_systemctl_active() {
  _run_as_root systemctl is-active --quiet "$1" 2> /dev/null
}

_user_in_docker_group() {
  id -nG "$USER" 2> /dev/null | grep -qw "docker"
}

_ufw_rule_present() {
  local network="$1"
  _run_as_root ufw status 2> /dev/null | grep -qF "$network"
}

_all_pkgs_installed() {
  for pkg in "${DOCKER_PKGS[@]}"; do
    _pkg_installed "$pkg" || return 1
  done
  return 0
}

admin_plan() {
  ADMIN_PLAN_ACTIONS=(
    "install docker packages"
    "configure /etc/docker/daemon.json"
    "configure systemd-resolved DNS for docker"
    "enable docker.socket"
    "add user to docker group"
    "configure no-block-boot override"
    "apply UFW docker rules if UFW is active"
  )
  _can_elevate &&
    command -v pacman > /dev/null 2>&1 &&
    command -v systemctl > /dev/null 2>&1 || return 1
  return 0
}

admin_apply() {
  admin_plan || return 1

  if ((flg_DryRun == 1)); then
    return 0
  fi
  if [[ -f /.dockerenv ]]; then
    return 0
  fi

  if ! _all_pkgs_installed; then
    _run_as_root pacman -S --needed --noconfirm "${DOCKER_PKGS[@]}" || return 1
  fi

  if ! _file_contains "$DAEMON_JSON" '"log-driver": "json-file"'; then
    [[ -f $DAEMON_JSON ]] || DOCKER_FILES_CREATED+=("$DAEMON_JSON")
    _run_as_root mkdir -p /etc/docker
    _run_as_root tee "$DAEMON_JSON" > /dev/null << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "5" },
    "dns": ["172.17.0.1"],
    "bip": "172.17.0.1/16"
}
EOF
  fi

  if ! _file_contains "$RESOLVED_DNS_CONF" 'DNSStubListenerExtra=172.17.0.1'; then
    [[ -f $RESOLVED_DNS_CONF ]] || DOCKER_FILES_CREATED+=("$RESOLVED_DNS_CONF")
    _run_as_root mkdir -p /etc/systemd/resolved.conf.d
    _run_as_root tee "$RESOLVED_DNS_CONF" > /dev/null << 'EOF'
[Resolve]
DNSStubListenerExtra=172.17.0.1
EOF
  fi
  _run_as_root systemctl restart systemd-resolved || return 1

  if ! _systemctl_enabled "$DOCKER_SOCKET" || ! _systemctl_active "$DOCKER_SOCKET"; then
    _run_as_root systemctl enable --now "$DOCKER_SOCKET" || return 1
    DOCKER_SOCKET_ENABLED_BY_TASK=true
  fi

  if ! _user_in_docker_group; then
    _run_as_root usermod -aG docker "$USER" || return 1
    DOCKER_GROUP_ADDED_BY_TASK=true
  fi

  if ! _file_contains "$NO_BLOCK_CONF" 'DefaultDependencies=no'; then
    [[ -f $NO_BLOCK_CONF ]] || DOCKER_FILES_CREATED+=("$NO_BLOCK_CONF")
    _run_as_root mkdir -p /etc/systemd/system/docker.service.d
    _run_as_root tee "$NO_BLOCK_CONF" > /dev/null << 'EOF'
[Unit]
DefaultDependencies=no
EOF
  fi
  _run_as_root systemctl daemon-reload || return 1

  if _ufw_active; then
    _run_as_root ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'allow-docker-dns' || true
    _run_as_root ufw allow in proto udp from 192.168.0.0/16 to 172.17.0.1 port 53 comment 'allow-docker-dns' || true
    _run_as_root ufw-docker install || true
    _run_as_root ufw reload || return 1
  fi
}

admin_verify() {
  if [[ -f /.dockerenv ]]; then
    return 0
  fi
  _all_pkgs_installed || return 1
  _file_contains "$DAEMON_JSON" '"log-driver": "json-file"' || return 1
  _file_contains "$DAEMON_JSON" '"172.17.0.1"' || return 1
  _file_contains "$RESOLVED_DNS_CONF" 'DNSStubListenerExtra=172.17.0.1' || return 1
  _systemctl_enabled "$DOCKER_SOCKET" || return 1
  _systemctl_active "$DOCKER_SOCKET" || return 1
  _user_in_docker_group || return 1
  _file_contains "$NO_BLOCK_CONF" 'DefaultDependencies=no' || return 1
  if _ufw_active; then
    _ufw_rule_present '172.16.0.0/12' || return 1
    _ufw_rule_present '192.168.0.0/16' || return 1
  fi
  return 0
}

admin_rollback() {
  admin_reset
}

admin_reset() {
  admin_plan || return 1

  if [[ $DOCKER_SOCKET_ENABLED_BY_TASK == true ]] && _systemctl_enabled "$DOCKER_SOCKET"; then
    _run_as_root systemctl disable --now "$DOCKER_SOCKET" || true
    DOCKER_SOCKET_ENABLED_BY_TASK=false
  fi

  local file=""
  for file in "${DOCKER_FILES_CREATED[@]}"; do
    _run_as_root rm -f "$file" || true
  done

  if [[ $DOCKER_GROUP_ADDED_BY_TASK == true ]] && _user_in_docker_group; then
    _run_as_root gpasswd -d "$USER" docker || true
    DOCKER_GROUP_ADDED_BY_TASK=false
  fi

  return 0
}

admin_verify_reset() {
  if [[ $DOCKER_SOCKET_ENABLED_BY_TASK == true ]]; then
    ! _systemctl_enabled "$DOCKER_SOCKET" || return 1
  fi
  local file=""
  for file in "${DOCKER_FILES_CREATED[@]}"; do
    [[ -f $file ]] && return 1
  done
  if [[ $DOCKER_GROUP_ADDED_BY_TASK == true ]]; then
    ! _user_in_docker_group || return 1
  fi
  return 0
}

check() { admin_verify; }
install() { admin_apply; }
verify() { admin_verify; }
reset() { admin_reset; }
verify_reset() { admin_verify_reset; }
