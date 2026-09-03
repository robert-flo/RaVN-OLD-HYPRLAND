#!/usr/bin/env bash

# shellcheck disable=SC1091
if ! source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..." >&2
    exit 1
fi

# ╭──────────────────────────────────────────────────────────────────────────────╮
# │                                                                              │
# │                OmarchyVM — QEMU/KVM Unattended Installer                     │
# │                                                                              │
# │     Installs Omarchy unattended in a VM via ISO + cidata drive, then        │
# │     runs the installed system from a cached snapshot.                       │
# │                                                                              │
# ╰──────────────────────────────────────────────────────────────────────────────╯
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                        OmarchyVM — Documentation                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# USAGE
#   omarchyvm                 — Validate the environment and open the menu
#   omarchyvm --rebuild       — (Re)install Omarchy unattended into a fresh base snapshot
#   omarchyvm --persist       — Run the installed system with persistent changes
#   omarchyvm --iso 4.0.2     — Use a specific ISO version, URL, or local path
#
# DIRECT OPTIONS
#   --rebuild             — Run the unattended install and cache the base snapshot
#   --persist             — Run with persistent VM changes (default: ephemeral overlay)
#   --iso VER|URL|PATH    — ISO version (4.0.2), full URL, or local .iso path
#   --user NAME           — Guest username (default: arch)
#   --password PASS       — Guest password (default: arch)
#   --hostname NAME       — Guest hostname (default: omarchy-vm)
#   --timezone ZONE       — Guest timezone (default: host timezone or UTC)
#   --keymap LAYOUT       — Guest keyboard layout (default: us)
#   --list                — List cached snapshots
#   --storage             — Show VM storage usage
#   --clean               — Remove cached VM state (preserves the ISO)
#   --check-deps          — Check host dependencies
#   --install-deps        — Install host dependencies on Arch Linux
#   --install-ssh-alias   — Configure the `ssh omarchyvm` host alias
#   --ssh                 — Connect to the running VM via SSH
#   --build-cidata-only   — Build the cidata ISO and exit (testing seam)
#   --help                — Show command help
#
# ENVIRONMENT
#   OMARCHY_ISO_VERSION=4.0.2   ISO version (used when --iso is absent)
#   OMARCHY_ISO_URL=...         Full ISO URL override
#   OMARCHY_ISO=/path/a.iso     Local ISO override (skips download)
#   OMARCHY_ISO_SHA256=...      Expected ISO checksum (optional verification)
#   OMARCHY_USER / OMARCHY_PASSWORD / OMARCHY_HOSTNAME
#   OMARCHY_TIMEZONE / OMARCHY_KEYMAP
#   OMARCHY_FULL_NAME / OMARCHY_EMAIL (optional git identity files)
#   OMARCHY_SSH_PORT=2223       Host SSH forward port (auto-fallback if busy)
#   OMARCHY_DISK_SIZE_GB=40     Installed disk size
#   OMARCHY_INSTALL_TIMEOUT=1800  Seconds to wait for the install to finish
#   VM_MEMORY=8G VM_CPUS=4       VM resources
#
# UNATTENDED INSTALL (https://omarchy.org/manual/unattended-installs/)
#   The installer finds a second drive labeled `cidata` carrying the
#   configurator's own output files, skips the wizard, installs, and reboots
#   into the finished system on its own. SSH works out of the box because the
#   cidata `authorized_keys` makes the installer enable sshd + firewall rule.
#   Caveat: encrypted installs are NOT unattended (LUKS passphrase at boot),
#   so this tool always installs without encryption.

set -e

ACTIVE_QEMU_PID=""
TEMPORARY_PATHS=()
VM_LOCK_FD=""

function kill_vm_process() {
  local pid="$1"

  # QEMU runs under setsid in its own process group, so this also reaps
  # wrapper children (a plain pid kill would orphan them and hang any
  # command substitution waiting on the inherited pipes).
  kill -TERM -- "-$pid" 2> /dev/null || kill "$pid" 2> /dev/null || true
  wait "$pid" 2> /dev/null || true
}

function cleanup_runtime() {
  local temporary_path=""

  if [[ -n $ACTIVE_QEMU_PID ]] && kill -0 "$ACTIVE_QEMU_PID" 2> /dev/null; then
    kill_vm_process "$ACTIVE_QEMU_PID"
  fi
  ACTIVE_QEMU_PID=""

  for temporary_path in "${TEMPORARY_PATHS[@]}"; do
    rm -rf -- "$temporary_path"
  done
  TEMPORARY_PATHS=()
}

function handle_interrupt() {
  print_warn "OmarchyVM interrupted; temporary state was removed safely"
  exit 130
}

function register_temporary_path() {
  TEMPORARY_PATHS+=("$1")
}

function acquire_vm_lock() {
  exec {VM_LOCK_FD}> "$CACHE_DIR/session.lock"
  if ! flock -n "$VM_LOCK_FD"; then
    exec {VM_LOCK_FD}>&-
    VM_LOCK_FD=""
    print_error "Another OmarchyVM session is already active; close it before starting a new VM"
    return 1
  fi
}

function release_vm_lock() {
  if [[ -n $VM_LOCK_FD ]]; then
    flock -u "$VM_LOCK_FD"
    exec {VM_LOCK_FD}>&-
    VM_LOCK_FD=""
  fi
}

trap handle_interrupt INT TERM
trap cleanup_runtime EXIT

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Configuration                                                                │
# └──────────────────────────────────────────────────────────────────────────────┘
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/omarchyvm"
SNAPSHOTS_DIR="$CACHE_DIR/snapshots"
BASE_SNAPSHOT="$SNAPSHOTS_DIR/omarchy-base.qcow2"
SSH_KEY="$CACHE_DIR/id_ed25519"
CIDATA_ISO="$CACHE_DIR/cidata.iso"

OMARCHY_ISO_VERSION="${OMARCHY_ISO_VERSION:-4.0.2}"
OMARCHY_ISO_URL="${OMARCHY_ISO_URL:-https://iso.omarchy.org/omarchy-${OMARCHY_ISO_VERSION}.iso}"
# OMARCHY_ISO (local path) intentionally has no default; resolve_iso_source decides.
OMARCHY_USER="${OMARCHY_USER:-arch}"
OMARCHY_PASSWORD="${OMARCHY_PASSWORD:-arch}"
OMARCHY_HOSTNAME="${OMARCHY_HOSTNAME:-omarchy-vm}"
OMARCHY_KEYMAP="${OMARCHY_KEYMAP:-us}"
OMARCHY_DISK_SIZE_GB="${OMARCHY_DISK_SIZE_GB:-40}"
OMARCHY_INSTALL_TIMEOUT="${OMARCHY_INSTALL_TIMEOUT:-1800}"
if [[ ! $OMARCHY_INSTALL_TIMEOUT =~ ^[0-9]+$ ]]; then
  OMARCHY_INSTALL_TIMEOUT=1800
fi
if [[ ! $OMARCHY_DISK_SIZE_GB =~ ^[0-9]+$ ]]; then
  OMARCHY_DISK_SIZE_GB=40
fi

HOST_TIMEZONE=""
HOST_TIMEZONE=$(timedatectl show -p Timezone --value 2> /dev/null || true)
OMARCHY_TIMEZONE="${OMARCHY_TIMEZONE:-${HOST_TIMEZONE:-UTC}}"

SSH_PORT="${OMARCHY_SSH_PORT:-2223}"
if [[ ! $SSH_PORT =~ ^[0-9]+$ ]]; then
  SSH_PORT=2223
fi
VM_MEMORY="${VM_MEMORY:-8G}"
VM_CPUS="${VM_CPUS:-4}"

OVMF_CODE="${OMARCHY_OVMF_CODE:-}"
OVMF_VARS_TEMPLATE="${OMARCHY_OVMF_VARS_TEMPLATE:-}"

# Required packages for Arch Linux (cdrtools provides genisoimage)
ARCH_PACKAGES=(
  "qemu-desktop"
  "edk2-ovmf"
  "cdrtools"
  "curl"
  "openssh"
  "openssl"
  "python"
)

# Create cache directories
mkdir -p "$CACHE_DIR" "$SNAPSHOTS_DIR"

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Ports                                                                        │
# └──────────────────────────────────────────────────────────────────────────────┘

function is_port_free() {
  local port="$1"
  local listeners=""
  if command -v ss > /dev/null 2>&1; then
    listeners=$(ss -H -tln "sport = :$port" 2> /dev/null || true)
    [[ -z $listeners ]]
  elif command -v netstat > /dev/null 2>&1; then
    listeners=$(netstat -tln 2> /dev/null | grep ":$port " || true)
    [[ -z $listeners ]]
  else
    listeners=$( (echo > /dev/tcp/127.0.0.1/"$port") 2> /dev/null && echo "busy" || true)
    [[ -z $listeners ]]
  fi
}

function ensure_ssh_port_free() {
  local original_port="$SSH_PORT"
  local port="$SSH_PORT"
  local tries=0
  while ((tries < 10)); do
    if is_port_free "$port"; then
      if [[ $port != "$original_port" ]]; then
        print_warn "Port $original_port in use, using $port instead (set OMARCHY_SSH_PORT to override)"
      fi
      SSH_PORT="$port"
      return 0
    fi
    ((port += 1))
    ((tries += 1))
  done
  print_error "No free SSH port found starting from $original_port (tried 10 ports)"
  print_info "Stop the process using $original_port (ss -tlnp | grep $original_port) or set OMARCHY_SSH_PORT to a free port"
  return 1
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Environment & Dependencies                                                   │
# └──────────────────────────────────────────────────────────────────────────────┘

function detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    if [[ $ID == "nixos" ]]; then
      echo "nixos"
    elif [[ $ID == "arch" ]] || [[ ${ID_LIKE:-} == *arch* ]] || command -v pacman > /dev/null 2>&1; then
      echo "arch"
    else
      echo "unknown"
    fi
  elif command -v nixos-version > /dev/null 2>&1; then
    echo "nixos"
  elif command -v pacman > /dev/null 2>&1; then
    echo "arch"
  else
    echo "unknown"
  fi
}

function print_usage() {
  echo "OmarchyVM - Unattended Omarchy installer and VM runner"
  echo "Supports: Arch Linux, Arch-based distros, NixOS"
  echo ""
  echo "Usage: omarchyvm [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --rebuild               (Re)install Omarchy unattended, cache the base snapshot"
  echo "  --persist               Run the installed system with persistent changes"
  echo "  --iso VER|URL|PATH      ISO version (default: $OMARCHY_ISO_VERSION), URL, or local path"
  echo "  --user NAME             Guest username (default: $OMARCHY_USER)"
  echo "  --password PASS         Guest password (default: arch)"
  echo "  --hostname NAME         Guest hostname (default: $OMARCHY_HOSTNAME)"
  echo "  --timezone ZONE         Guest timezone (default: $OMARCHY_TIMEZONE)"
  echo "  --keymap LAYOUT         Guest keyboard layout (default: $OMARCHY_KEYMAP)"
  echo "  --list                  List cached snapshots"
  echo "  --storage               Show VM storage usage"
  echo "  --clean                 Clean snapshots and temporary data (keeps the ISO)"
  echo "  --install-deps          Install required dependencies (Arch only)"
  echo "  --check-deps            Check if dependencies are installed"
  echo "  --install-ssh-alias     Configure the 'ssh omarchyvm' host alias"
  echo "  --ssh                   Connect to the running VM via SSH"
  echo "  --build-cidata-only     Build the cidata ISO and exit"
  echo "  --help                  Show this help"
  echo ""
  echo "Environment Variables:"
  echo "  OMARCHY_ISO_VERSION=4.0.2   ISO version for the default download URL"
  echo "  OMARCHY_ISO_URL=...         Full ISO URL override"
  echo "  OMARCHY_ISO=/path/a.iso     Local ISO override (skips download)"
  echo "  OMARCHY_ISO_SHA256=...      Optional ISO checksum verification"
  echo "  OMARCHY_USER / OMARCHY_PASSWORD / OMARCHY_HOSTNAME"
  echo "  OMARCHY_TIMEZONE / OMARCHY_KEYMAP"
  echo "  OMARCHY_FULL_NAME / OMARCHY_EMAIL (optional, added to cidata)"
  echo "  OMARCHY_SSH_PORT=2223       SSH forward port (auto-fallback if busy)"
  echo "  OMARCHY_DISK_SIZE_GB=40     Installed disk size in GiB"
  echo "  OMARCHY_INSTALL_TIMEOUT=1800  Seconds to wait for the install"
  echo "  VM_MEMORY=8G VM_CPUS=4       VM resources"
  echo ""
  echo "Examples:"
  echo "  omarchyvm                 # Open the menu (installs on first run)"
  echo "  omarchyvm --rebuild       # Fresh unattended install"
  echo "  omarchyvm --persist       # Run with persistent changes"
  echo "  omarchyvm --iso 4.0.2     # Pin the ISO version"
  echo ""
  echo "Notes:"
  echo "  Installs are always unencrypted: LUKS would need a passphrase at"
  echo "  boot and is not unattended (see the Omarchy manual). authorized_keys"
  echo "  is collected from ~/.ssh/*.pub so SSH works without a password."
}

function check_root() {
  if [[ $EUID -eq 0 ]]; then
    print_error "Please don't run this script as root"
    local os
    os=$(detect_os)
    if [[ $os == "arch" ]]; then
      print_info "Use --install-deps to install dependencies with sudo"
    fi
    exit 1
  fi
}

function cidata_builder_available() {
  command -v genisoimage > /dev/null 2>&1 || command -v xorriso > /dev/null 2>&1
}

function check_dependencies() {
  local os
  os=$(detect_os)

  case "$os" in
    "nixos")
      check_nixos_dependencies
      ;;
    "arch")
      check_arch_dependencies
      ;;
    *)
      print_warn "Unsupported OS. This script supports Arch Linux and NixOS."
      check_common_commands
      ;;
  esac
}

function check_common_commands() {
  local missing_commands=()

  for cmd in qemu-system-x86_64 qemu-img curl openssl ssh python3 setsid flock; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
      missing_commands+=("$cmd")
    fi
  done

  if ! cidata_builder_available; then
    missing_commands+=("genisoimage|xorriso")
  fi

  if [[ ! -f $OVMF_CODE ]] && ! find_ovmf_files > /dev/null 2>&1; then
    missing_commands+=("edk2-ovmf")
  fi

  if ((${#missing_commands[@]} > 0)); then
    print_error "Missing required commands: ${missing_commands[*]}"
    print_info "Please ensure qemu, edk2-ovmf, cdrtools (genisoimage), curl, openssh, openssl and python are installed."
    return 1
  fi

  return 0
}

function check_nixos_dependencies() {
  if ! check_common_commands; then
    print_info "On NixOS, use nix-shell -p qemu edk2-ovmf cdrtools curl openssh openssl python3 or add them to configuration.nix."
    return 1
  fi

  if [[ ! -r /dev/kvm ]]; then
    print_warn "KVM not available. VM will run slower."
  fi

  return 0
}

function check_arch_dependencies() {
  local missing_packages=()

  for package in "${ARCH_PACKAGES[@]}"; do
    if ! pacman -Q "$package" &> /dev/null; then
      missing_packages+=("$package")
    fi
  done

  if ((${#missing_packages[@]} > 0)); then
    print_error "Missing required packages: ${missing_packages[*]}"
    read -p "Would you like to install them now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      install_arch_packages "${missing_packages[@]}"
    else
      print_info "Install them manually with: sudo pacman -S ${missing_packages[*]}"
      return 1
    fi
  fi

  if [[ ! -r /dev/kvm ]]; then
    print_warn "KVM not available. VM will run slower."
    print_info "Make sure your user is in the 'kvm' group: sudo usermod -a -G kvm $USER"
  fi

  return 0
}

function install_arch_packages() {
  local packages=("$@")

  print_step "Installing missing packages: ${packages[*]}"
  sudo pacman -Sy
  sudo pacman -S --needed "${packages[@]}"

  if [[ " ${packages[*]} " =~ " qemu-desktop " ]] && getent group kvm > /dev/null; then
    print_step "Adding user to kvm group..."
    sudo usermod -a -G kvm "$USER"
    print_warn "Please logout and login again for group changes to take effect"
  fi

  print_success "Packages installed successfully"
}

function install_all_arch_dependencies() {
  local os
  os=$(detect_os)

  if [[ $os != "arch" ]]; then
    print_error "--install-deps is only supported on Arch Linux"
    print_info "Current OS: $os"
    exit 1
  fi

  print_step "Installing all OmarchyVM dependencies..."
  install_arch_packages "${ARCH_PACKAGES[@]}"
  print_info "You may need to reboot or logout/login for all changes to take effect"
}

function check_deps_only() {
  local os
  os=$(detect_os)
  print_section "Checking OmarchyVM dependencies"
  print_info "Detected OS: $os"

  if check_dependencies; then
    print_success "All dependencies are installed"

    print_section "System Information"
    print_info "CPU cores: $(nproc)"
    print_info "Memory: $(free -h | awk '/^Mem:/ {print $2}' 2> /dev/null || echo "Unknown")"
    print_info "KVM available: $([[ -r /dev/kvm ]] && echo "Yes" || echo "No")"

    if command -v qemu-system-x86_64 > /dev/null 2>&1; then
      print_info "QEMU version: $(qemu-system-x86_64 --version | head -1)"
    fi

    return 0
  else
    return 1
  fi
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ ISO                                                                          │
# └──────────────────────────────────────────────────────────────────────────────┘

# Resolve the ISO source into ISO_PATH (local file) or ISO_URL (download).
ISO_PATH=""
ISO_URL=""

function resolve_iso_source() {
  local source="${1:-}"

  if [[ -n ${OMARCHY_ISO:-} ]]; then
    source="$OMARCHY_ISO"
  fi

  if [[ -z $source ]]; then
    ISO_URL="$OMARCHY_ISO_URL"
    ISO_PATH="$CACHE_DIR/$(basename "$ISO_URL")"
    return 0
  fi

  if [[ -f $source ]]; then
    ISO_PATH="$source"
    ISO_URL=""
    return 0
  fi

  if [[ $source =~ ^https?:// ]]; then
    ISO_URL="$source"
    ISO_PATH="$CACHE_DIR/$(basename "$source")"
    return 0
  fi

  if [[ $source =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    ISO_URL="https://iso.omarchy.org/omarchy-${source}.iso"
    ISO_PATH="$CACHE_DIR/omarchy-${source}.iso"
    return 0
  fi

  print_error "Invalid --iso value: $source (use a version like 4.0.2, an https URL, or a local path)"
  return 1
}

function download_iso() {
  local partial_path=""

  if [[ -z $ISO_URL ]]; then
    if [[ ! -f $ISO_PATH ]]; then
      print_error "Local ISO not found: $ISO_PATH"
      return 1
    fi
    print_info "Using local ISO: $ISO_PATH"
    return 0
  fi

  if [[ -f $ISO_PATH ]]; then
    print_info "Using cached ISO: $ISO_PATH"
  else
    print_step "Downloading Omarchy ISO (~7GB, cached for reuse)..."
    print_info "URL: $ISO_URL"
    partial_path="${ISO_PATH}.part"
    register_temporary_path "$partial_path"
    if ! curl -fL -C - --retry 3 --retry-delay 5 -o "$partial_path" "$ISO_URL"; then
      print_error "ISO download failed"
      return 1
    fi
    mv -- "$partial_path" "$ISO_PATH"
    print_success "ISO downloaded: $ISO_PATH"
  fi

  local iso_size=""
  iso_size=$(stat -c %s "$ISO_PATH" 2> /dev/null || echo "0")
  if ((iso_size < 1073741824)); then
    print_error "ISO looks too small ($iso_size bytes); the download may be an error page"
    print_info "Remove it and retry: rm -f $ISO_PATH"
    return 1
  fi

  if [[ -n ${OMARCHY_ISO_SHA256:-} ]]; then
    print_step "Verifying ISO checksum..."
    local actual=""
    actual=$(sha256sum "$ISO_PATH" | awk '{print $1}')
    if [[ $actual != "$OMARCHY_ISO_SHA256" ]]; then
      print_error "Checksum mismatch for $ISO_PATH"
      return 1
    fi
    print_success "Checksum verified"
  fi

  return 0
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ OVMF (UEFI firmware)                                                         │
# └──────────────────────────────────────────────────────────────────────────────┘

function find_ovmf_files() {
  if [[ -n $OVMF_CODE && -n $OVMF_VARS_TEMPLATE && -f $OVMF_CODE && -f $OVMF_VARS_TEMPLATE ]]; then
    return 0
  fi

  local candidates=(
    "/usr/share/edk2/x64/OVMF_CODE.4m.fd:/usr/share/edk2/x64/OVMF_VARS.4m.fd"
    "/usr/share/ovmf/x64/OVMF_CODE.4m.fd:/usr/share/ovmf/x64/OVMF_VARS.4m.fd"
    "/usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd"
  )
  local pair=""
  local code=""
  local vars=""

  for pair in "${candidates[@]}"; do
    code="${pair%%:*}"
    vars="${pair##*:}"
    if [[ -f $code && -f $vars ]]; then
      OVMF_CODE="$code"
      OVMF_VARS_TEMPLATE="$vars"
      return 0
    fi
  done

  print_error "OVMF firmware not found (install edk2-ovmf)"
  return 1
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ SSH key & cidata                                                             │
# └──────────────────────────────────────────────────────────────────────────────┘

function ensure_ssh_key() {
  if [[ -f $SSH_KEY && -f ${SSH_KEY}.pub ]]; then
    return 0
  fi

  print_step "Generating OmarchyVM SSH key..."
  ssh-keygen -t ed25519 -N "" -q -C "omarchyvm" -f "$SSH_KEY"
  print_success "SSH key ready: $SSH_KEY"
}

# Collect host public keys so the installed system accepts SSH immediately.
function collect_authorized_keys() {
  local output_file="$1"
  local key_file=""
  local collected=0

  : > "$output_file"

  for key_file in "$HOME"/.ssh/*.pub; do
    [[ -f $key_file ]] || continue
    cat "$key_file" >> "$output_file"
    collected=1
  done

  if [[ -f ${SSH_KEY}.pub ]]; then
    if ! grep -qxF -f "${SSH_KEY}.pub" "$output_file" 2> /dev/null; then
      cat "${SSH_KEY}.pub" >> "$output_file"
    fi
    collected=1
  fi

  if [[ -n ${OMARCHY_SSH_KEY:-} && -f $OMARCHY_SSH_KEY ]]; then
    cat "$OMARCHY_SSH_KEY" >> "$output_file"
    collected=1
  fi

  if ((collected == 0)); then
    print_error "No SSH public key found: ~/.ssh/*.pub is empty and no key was generated"
    print_info "Create one with: ssh-keygen -t ed25519"
    return 1
  fi
}

# Build the cidata ISO carrying the configurator's own output files.
# Schema mirrors the official integration harness (omarchy-iso
# test/integration.d/base-test.sh): archinstall disk_config for /dev/vda.
function build_cidata() {
  local cidata_dir="$CACHE_DIR/cidata"
  local password_hash=""
  local disk_bytes=""
  local mib=""
  local gib=""
  local boot_start=""
  local boot_size=""
  local main_start=""
  local main_size=""

  ensure_ssh_key

  rm -rf "$cidata_dir"
  mkdir -p "$cidata_dir"

  password_hash=$(openssl passwd -6 "$OMARCHY_PASSWORD")

  mib=$((1024 * 1024))
  gib=$((1024 * 1024 * 1024))
  disk_bytes=$((OMARCHY_DISK_SIZE_GB * gib))
  boot_start=$mib
  boot_size=$((2 * gib))
  main_start=$((boot_size + boot_start))
  main_size=$((disk_bytes - main_start - mib))

  cat > "$cidata_dir/user_credentials.json" << CREDENTIALS_EOF
{
    "root_enc_password": "$password_hash",
    "users": [
        {
            "enc_password": "$password_hash",
            "groups": [],
            "sudo": true,
            "username": "$OMARCHY_USER"
        }
    ]
}
CREDENTIALS_EOF

  cat > "$cidata_dir/user_configuration.json" << CONFIGURATION_EOF
{
    "app_config": null,
    "archinstall-language": "English",
    "auth_config": {},
    "audio_config": { "audio": "pipewire" },
    "bootloader_config": { "bootloader": "Limine", "uki": false, "removable": false },
    "custom_commands": [],
    "omarchy_install": {
        "mode": "full_disk",
        "defer_provisioning": false,
        "target_mount": "/mnt",
        "boot": {
            "esp_mount": "/boot",
            "esp_path": "/EFI/limine",
            "efi_binary": "limine_x64.efi",
            "enable_fallback": true
        },
        "storage": { "kernel": "linux" }
    },
    "disk_config": {
        "config_type": "default_layout",
        "device_modifications": [
            {
                "device": "/dev/vda",
                "partitions": [
                    {
                        "btrfs": [],
                        "dev_path": null,
                        "flags": [ "boot", "esp" ],
                        "fs_type": "fat32",
                        "mount_options": [],
                        "mountpoint": "/boot",
                        "obj_id": "ea21d3f2-82bb-49cc-ab5d-6f81ae94e18d",
                        "size": { "sector_size": { "unit": "B", "value": 512 }, "unit": "B", "value": $boot_size },
                        "start": { "sector_size": { "unit": "B", "value": 512 }, "unit": "B", "value": $boot_start },
                        "status": "create",
                        "type": "primary"
                    },
                    {
                        "btrfs": [
                            { "mountpoint": "/", "name": "@" },
                            { "mountpoint": "/home", "name": "@home" },
                            { "mountpoint": "/var/log", "name": "@log" },
                            { "mountpoint": "/var/cache/pacman/pkg", "name": "@pkg" }
                        ],
                        "dev_path": null,
                        "flags": [],
                        "fs_type": "btrfs",
                        "mount_options": [ "compress=zstd" ],
                        "mountpoint": null,
                        "obj_id": "8c2c2b92-1070-455d-b76a-56263bab24aa",
                        "size": { "sector_size": { "unit": "B", "value": 512 }, "unit": "B", "value": $main_size },
                        "start": { "sector_size": { "unit": "B", "value": 512 }, "unit": "B", "value": $main_start },
                        "status": "create",
                        "type": "primary"
                    }
                ],
                "wipe": true
            }
        ]
    },
    "hostname": "$OMARCHY_HOSTNAME",
    "kernels": [ "linux" ],
    "network_config": { "type": "iso" },
    "ntp": true,
    "parallel_downloads": 8,
    "script": null,
    "services": [],
    "swap": true,
    "timezone": "$OMARCHY_TIMEZONE",
    "locale_config": { "kb_layout": "$OMARCHY_KEYMAP", "sys_enc": "UTF-8", "sys_lang": "en_US.UTF-8" },
    "mirror_config": {
        "custom_repositories": [],
        "custom_servers": [
            {"url": "https://mirror.omarchy.org/\$repo/os/\$arch"},
            {"url": "https://mirror.rackspace.com/archlinux/\$repo/os/\$arch"},
            {"url": "https://geo.mirror.pkgbuild.com/\$repo/os/\$arch"}
        ],
        "mirror_regions": {},
        "optional_repositories": []
    },
    "packages": [
        "base-devel",
        "git",
        "omarchy-keyring",
        "omarchy-settings",
        "omarchy"
    ],
    "profile_config": { "gfx_driver": null, "greeter": null, "profile": {} },
    "version": "3.0.9"
}
CONFIGURATION_EOF

  if [[ -n ${OMARCHY_FULL_NAME:-} ]]; then
    printf '%s\n' "$OMARCHY_FULL_NAME" > "$cidata_dir/user_full_name.txt"
  fi
  if [[ -n ${OMARCHY_EMAIL:-} ]]; then
    printf '%s\n' "$OMARCHY_EMAIL" > "$cidata_dir/user_email_address.txt"
  fi
  # Unencrypted install by design: LUKS needs a passphrase at boot and is
  # not unattended. The flag file must match the (absent) disk_encryption block.
  printf 'false\n' > "$cidata_dir/user_encrypt_installation.txt"

  if ! collect_authorized_keys "$cidata_dir/authorized_keys"; then
    return 1
  fi

  if ! python3 -c "import json,sys; json.load(open(sys.argv[1])); json.load(open(sys.argv[2]))" \
    "$cidata_dir/user_credentials.json" "$cidata_dir/user_configuration.json"; then
    print_error "Generated cidata JSON is invalid"
    return 1
  fi

  rm -f "$CIDATA_ISO"
  if command -v genisoimage > /dev/null 2>&1; then
    genisoimage -output "$CIDATA_ISO" -volid cidata -joliet -rock "$cidata_dir" > /dev/null
  elif command -v xorriso > /dev/null 2>&1; then
    xorriso -as mkisofs -output "$CIDATA_ISO" -volid cidata -joliet -rock "$cidata_dir" > /dev/null
  else
    print_error "Need genisoimage (cdrtools) or xorriso to build the cidata drive"
    return 1
  fi

  print_success "cidata ready: $CIDATA_ISO (user $OMARCHY_USER, host $OMARCHY_HOSTNAME)"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ QEMU Runtime (UEFI)                                                          │
# └──────────────────────────────────────────────────────────────────────────────┘

function get_qemu_command() {
  if command -v qemu-system-x86_64 > /dev/null 2>&1; then
    echo "qemu-system-x86_64"
  elif [[ -x "/usr/bin/qemu-system-x86_64" ]]; then
    echo "/usr/bin/qemu-system-x86_64"
  else
    echo "qemu-system-x86_64" # fallback
  fi
}

# Shared UEFI machine args. Extra drives (ISO/cidata) are appended by callers.
# Usage: build_machine_args <disk> <ovmf_vars> <array_name>
function build_machine_args() {
  local disk="$1"
  local ovmf_vars="$2"
  local array_name="$3"
  local -n args_ref="$array_name"

  # shellcheck disable=SC2054 # QEMU device properties are comma-separated by design
  args_ref=(
    -cpu host -enable-kvm -machine q35,accel=kvm
    -smp "$VM_CPUS"
    -m "$VM_MEMORY"
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    -drive "if=pflash,format=raw,file=$ovmf_vars"
    -drive "file=$disk,format=qcow2,if=none,id=drive0"
    -device "virtio-blk-pci,drive=drive0,bootindex=1"
    -device virtio-vga
    -display "gtk,gl=on"
    -usb -device usb-tablet
    -device "virtio-net-pci,netdev=net0"
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22"
    -boot "menu=on"
  )

  if [[ ! -r /dev/kvm ]]; then
    args_ref=("${args_ref[@]/-cpu host/-cpu qemu64}")
    args_ref=("${args_ref[@]/-machine q35,accel=kvm/-machine q35}")
  fi

  if [[ -n ${VM_EXTRA_ARGS:-} ]]; then
    # shellcheck disable=SC2086
    read -ra extra_vm_args <<< "$VM_EXTRA_ARGS"
    args_ref+=("${extra_vm_args[@]}")
  fi
}

function run_qemu_background() {
  local qemu_cmd
  qemu_cmd=$(get_qemu_command)

  # setsid gives QEMU its own process group so cleanup can terminate the
  # whole tree (kill -- -PID); --wait keeps $! valid while QEMU runs.
  setsid --wait "$qemu_cmd" "$@" 2> "$CACHE_DIR/qemu.log" &
  ACTIVE_QEMU_PID=$!
  # Detect immediate startup failure (e.g., port already in use)
  sleep 0.5
  if ! kill -0 "$ACTIVE_QEMU_PID" 2> /dev/null; then
    if grep -q "Could not set up host forwarding" "$CACHE_DIR/qemu.log" 2> /dev/null; then
      wait "$ACTIVE_QEMU_PID" 2> /dev/null || true
      ACTIVE_QEMU_PID=""
      print_error "QEMU failed to start: host forwarding for port $SSH_PORT failed (port in use)"
      print_info "Stop the process using that port (ss -tlnp | grep $SSH_PORT) or set OMARCHY_SSH_PORT to a free port"
      return 1
    fi
    # Other immediate exits (e.g., mocked QEMU in tests) are left for the
    # caller to handle via wait_for_guest_ssh, as ravnvm does.
  fi

  return 0
}

function ssh_guest() {
  ssh -i "$SSH_KEY" -p "$SSH_PORT" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 \
    -o LogLevel=ERROR \
    "$OMARCHY_USER@127.0.0.1" "$@"
}

function wait_for_guest_ssh() {
  local qemu_pid="$1"
  local timeout="$2"
  local waited=0

  while ((waited < timeout)); do
    # Full-auth SSH only succeeds once the installed system is up with our
    # authorized_keys; the live ISO has no such key, so there is no false
    # positive from the installer environment itself.
    if ssh_guest true 2> /dev/null; then
      return 0
    fi

    if [[ -n $qemu_pid ]] && ! kill -0 "$qemu_pid" 2> /dev/null; then
      wait "$qemu_pid" 2> /dev/null || true
      ACTIVE_QEMU_PID=""
      print_error "The install VM stopped before SSH became available"
      return 1
    fi

    sleep 10
    ((waited += 10))
    if ((waited % 120 == 0)); then
      print_info "Still installing... (${waited}s elapsed)"
    fi
  done

  print_error "Timed out after ${timeout}s waiting for the installed system SSH"
  return 1
}

function stop_guest() {
  local qemu_pid="$1"
  local waited=0

  print_step "Shutting down the guest..."
  if ssh_guest "echo $OMARCHY_PASSWORD | sudo -S poweroff" > /dev/null 2>&1; then
    while kill -0 "$qemu_pid" 2> /dev/null && ((waited < 120)); do
      sleep 2
      ((waited += 2))
    done
  fi

  if kill -0 "$qemu_pid" 2> /dev/null; then
    print_warn "Guest did not power off; terminating QEMU"
    kill_vm_process "$qemu_pid"
    sleep 2
  fi

  if kill -0 "$qemu_pid" 2> /dev/null; then
    kill -KILL -- "-$qemu_pid" 2> /dev/null || kill -9 "$qemu_pid" 2> /dev/null || true
  fi
  wait "$qemu_pid" 2> /dev/null || true
  ACTIVE_QEMU_PID=""
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Install & Run                                                                │
# └──────────────────────────────────────────────────────────────────────────────┘

function install_base() {
  local building_disk="$CACHE_DIR/install.building.qcow2"
  local building_ovmf="$CACHE_DIR/OVMF_VARS.building.fd"
  local qemu_pid=""
  local machine_args=()

  if ! ensure_ssh_port_free; then
    cleanup_runtime
    return 1
  fi

  if ! download_iso; then
    cleanup_runtime
    return 1
  fi

  if ! find_ovmf_files; then
    cleanup_runtime
    return 1
  fi

  if ! build_cidata; then
    cleanup_runtime
    return 1
  fi

  print_step "Creating ${OMARCHY_DISK_SIZE_GB}G install disk..."
  rm -f "$building_disk"
  qemu-img create -f qcow2 "$building_disk" "${OMARCHY_DISK_SIZE_GB}G" > /dev/null
  register_temporary_path "$building_disk"
  cp "$OVMF_VARS_TEMPLATE" "$building_ovmf"
  register_temporary_path "$building_ovmf"

  echo ""
  print_info "Unattended install starting: ISO + cidata attached, SSH on port $SSH_PORT"
  print_info "The installer skips the wizard, installs, and reboots on its own."
  print_info "This takes several minutes; progress is shown below."
  echo ""

  build_machine_args "$building_disk" "$building_ovmf" machine_args
  machine_args+=(
    # Both CD-ROMs on an explicit AHCI controller: the default IDE bus
    # allows a single unit, so a second bare ide-cd fails with
    # "Can't create IDE unit 1, bus supports only 1 units".
    -device "ahci,id=ahci0"
    -drive "file=$ISO_PATH,media=cdrom,if=none,format=raw,id=cdrom0"
    -device "ide-cd,drive=cdrom0,bus=ahci0.0,bootindex=2"
    -drive "file=$CIDATA_ISO,media=cdrom,if=none,format=raw,id=cdrom1"
    -device "ide-cd,drive=cdrom1,bus=ahci0.1,bootindex=3"
  )

  if ! acquire_vm_lock; then
    cleanup_runtime
    return 1
  fi

  if ! run_qemu_background "${machine_args[@]}"; then
    release_vm_lock
    cleanup_runtime
    return 1
  fi
  qemu_pid="$ACTIVE_QEMU_PID"

  print_step "Waiting for the unattended install to finish (timeout ${OMARCHY_INSTALL_TIMEOUT}s)..."
  if ! wait_for_guest_ssh "$qemu_pid" "$OMARCHY_INSTALL_TIMEOUT"; then
    release_vm_lock
    cleanup_runtime
    return 1
  fi
  print_success "Install finished; the installed system is up."

  stop_guest "$qemu_pid"
  release_vm_lock

  print_step "Caching base snapshot..."
  if ! qemu-img convert -O qcow2 "$building_disk" "$BASE_SNAPSHOT"; then
    rm -f -- "$BASE_SNAPSHOT"
    print_error "Unable to cache the base snapshot"
    cleanup_runtime
    return 1
  fi

  rm -f "$building_disk" "$building_ovmf"
  print_success "Base snapshot ready: $BASE_SNAPSHOT"
  print_info "Run it with: omarchyvm  (or: omarchyvm --persist)"
}

function run_vm() {
  local persistent="${1:-false}"
  local vm_disk=""
  local run_ovmf="$CACHE_DIR/OVMF_VARS.run.fd"
  local machine_args=()
  local qemu_cmd=""

  if [[ ! -f $BASE_SNAPSHOT ]]; then
    print_info "No base snapshot found; running the unattended install first..."
    if ! install_base; then
      return 1
    fi
  fi

  if ! ensure_ssh_port_free; then
    return 1
  fi

  if ! find_ovmf_files; then
    return 1
  fi

  if [[ $persistent == "true" ]]; then
    print_info "Running in persistent mode - changes will be saved"
    vm_disk="$BASE_SNAPSHOT"
    cp "$OVMF_VARS_TEMPLATE" "$CACHE_DIR/OVMF_VARS.base.fd"
  else
    print_info "Running in non-persistent mode - changes will be discarded"
    vm_disk="$(mktemp -p "$CACHE_DIR" overlay.XXXXXX.qcow2)"
    register_temporary_path "$vm_disk"
    qemu-img create -f qcow2 -F qcow2 -b "$BASE_SNAPSHOT" "$vm_disk" > /dev/null
    cp "$OVMF_VARS_TEMPLATE" "$run_ovmf"
    register_temporary_path "$run_ovmf"
  fi

  if [[ $persistent == "true" ]]; then
    run_ovmf="$CACHE_DIR/OVMF_VARS.base.fd"
  fi

  print_step "Starting Omarchy VM..."
  print_info "Login: $OMARCHY_USER / $OMARCHY_PASSWORD"
  print_info "SSH: ssh -i $SSH_KEY -p ${SSH_PORT} $OMARCHY_USER@127.0.0.1 (or: omarchyvm --ssh, ssh omarchyvm)"
  print_info "Using SSH port $SSH_PORT"

  if ! acquire_vm_lock; then
    return 1
  fi

  build_machine_args "$vm_disk" "$run_ovmf" machine_args
  qemu_cmd=$(get_qemu_command)
  if ! "$qemu_cmd" "${machine_args[@]}" 2> "$CACHE_DIR/qemu.log"; then
    print_error "QEMU exited with an error. Check $CACHE_DIR/qemu.log"
  fi

  release_vm_lock

  if [[ $persistent != "true" ]]; then
    rm -f -- "$vm_disk" "$run_ovmf"
  fi
}

function list_snapshots() {
  local snapshots=""

  echo "Available Omarchy snapshots:"
  if [[ -d $SNAPSHOTS_DIR ]]; then
    snapshots=$(find "$SNAPSHOTS_DIR" -name "omarchy-*.qcow2" -exec basename {} \; | sort)
    if [[ -n $snapshots ]]; then
      echo "$snapshots" | while IFS= read -r snapshot; do
        local size=""
        size=$(du -h "$SNAPSHOTS_DIR/$snapshot" 2> /dev/null | awk '{print $1}')
        echo "  $snapshot ($size)"
      done
    else
      echo "  No snapshots found"
      echo "  Run 'omarchyvm --rebuild' to install."
    fi
  else
    echo "  No snapshots found"
  fi
}

function clean_cache() {
  print_step "Cleaning OmarchyVM cache (ISO preserved)..."

  local item=""
  for item in "$SNAPSHOTS_DIR"/* "$CACHE_DIR"/overlay.*.qcow2 "$CACHE_DIR"/install.building.qcow2 \
    "$CACHE_DIR"/OVMF_VARS.*.fd "$CIDATA_ISO" "$CACHE_DIR/cidata" "$CACHE_DIR/qemu.log"; do
    [[ -e $item ]] || continue
    rm -rf -- "$item"
  done

  print_success "Cache cleaned; base ISO preserved"
}

function format_bytes() {
  local bytes="$1"
  awk -v bytes="$bytes" 'BEGIN {
    split("B KiB MiB GiB TiB", units)
    unit_index = 1
    while (bytes >= 1024 && unit_index < 5) {
      bytes /= 1024
      unit_index++
    }
    printf "%.2f %s", bytes, units[unit_index]
  }'
}

function show_storage_status() {
  local cache_size="0"
  local disk_used=""
  local disk_total=""
  local disk_percent=""

  if [[ -d $CACHE_DIR ]]; then
    cache_size=$(du -sb "$CACHE_DIR" 2> /dev/null | awk '{print $1}')
    [[ -z $cache_size ]] && cache_size="0"
  fi

  print_section "Storage"
  print_info "VM cache: $(format_bytes "$cache_size") ($CACHE_DIR)"

  disk_used=$(df -B1 "$CACHE_DIR" 2> /dev/null | awk 'NR==2 {print $3}')
  disk_total=$(df -B1 "$CACHE_DIR" 2> /dev/null | awk 'NR==2 {print $2}')
  disk_percent=$(df "$CACHE_DIR" 2> /dev/null | awk 'NR==2 {print $5}' | tr -d '%')
  if [[ -n $disk_used && -n $disk_total ]]; then
    print_info "Disk: $(format_bytes "$disk_used") used / $(format_bytes "$disk_total") (${disk_percent}%)"
  fi

  if [[ -f $BASE_SNAPSHOT ]]; then
    local snap_size=""
    snap_size=$(stat -c %s "$BASE_SNAPSHOT" 2> /dev/null || echo "0")
    print_info "Base snapshot: $(format_bytes "$snap_size")"
  else
    print_info "Base snapshot: none (run omarchyvm --rebuild)"
  fi

  local iso_path=""
  for iso_path in "$CACHE_DIR"/omarchy-*.iso; do
    [[ -f $iso_path ]] || continue
    local iso_size=""
    iso_size=$(stat -c %s "$iso_path" 2> /dev/null || echo "0")
    print_info "ISO $(basename "$iso_path"): $(format_bytes "$iso_size")"
  done
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Interactive Interface                                                        │
# └──────────────────────────────────────────────────────────────────────────────┘

function press_enter_to_continue() {
  read -r -p "Press Enter to continue..." _
}

function print_omarchyvm_banner() {
  print_ravn_banner "OmarchyVM — Unattended Omarchy in QEMU/KVM"
}

function validate_command() {
  local command_name="$1"
  if command -v "$command_name" > /dev/null 2>&1; then
    print_success "$command_name"
    return 0
  else
    print_error "$command_name not found"
    return 1
  fi
}

function validate_environment() {
  local command_name=""
  local validation_failed=0

  print_section "Validating Environment"
  for command_name in qemu-system-x86_64 qemu-img curl openssl ssh python3 setsid flock; do
    if ! validate_command "$command_name"; then
      validation_failed=1
    fi
  done

  if cidata_builder_available; then
    print_success "cidata builder (genisoimage/xorriso)"
  else
    print_error "cidata builder not found (genisoimage or xorriso)"
    validation_failed=1
  fi

  if find_ovmf_files 2> /dev/null; then
    print_success "OVMF firmware ($OVMF_CODE)"
  else
    print_error "OVMF firmware not found"
    validation_failed=1
  fi

  if [[ -d $CACHE_DIR && -w $CACHE_DIR ]]; then
    print_success "OmarchyVM cache directory"
  else
    print_error "OmarchyVM cache directory is not writable"
    validation_failed=1
  fi

  if [[ -r /dev/kvm ]]; then
    print_success "KVM acceleration"
  else
    print_warn "KVM unavailable; QEMU will run without hardware acceleration"
  fi

  show_storage_status
  return "$validation_failed"
}

function recover_environment() {
  local recovery_choice=""

  while ! validate_environment; do
    print_section "Required dependencies missing"
    echo -e "  ${GREEN}1${NC}  Install dependencies"
    echo -e "  ${GREEN}q${NC}  Exit"
    echo ""
    read -r -p "${LIGHT_GRAY}Selection:${NC} " recovery_choice

    case "$recovery_choice" in
      1)
        if ! install_all_arch_dependencies; then
          print_error "Dependency installation failed"
          press_enter_to_continue
        fi
        ;;
      q | Q)
        return 1
        ;;
      *)
        print_error "Choose Install dependencies or Exit"
        press_enter_to_continue
        ;;
    esac
  done

  return 0
}

function show_menu() {
  clear || true
  print_omarchyvm_banner
  print_section "Choose an action"
  echo -e "  ${GREEN}1${NC}  Run installed system (ephemeral)"
  echo -e "  ${GREEN}2${NC}  Run installed system (persistent)"
  echo -e "  ${GREEN}3${NC}  Rebuild base (unattended install)"
  echo -e "  ${GREEN}4${NC}  Show VM storage usage"
  echo -e "  ${GREEN}5${NC}  Clean VM cache"
  echo -e "  ${GREEN}6${NC}  List snapshots"
  echo -e "  ${GREEN}7${NC}  Configure RAM and CPU"
  echo -e "  ${GREEN}8${NC}  Show OmarchyVM usage"
  echo -e "  ${GREEN}9${NC}  Connect to VM via SSH"
  echo -e "  ${GREEN}10${NC}  Install SSH alias"
  echo -e "  ${GREEN}q${NC}  Exit"
  echo ""
}

function select_execution_mode() {
  local ref_label="$1"
  local mode_choice=""

  while true; do
    echo ""
    print_section "Choose VM mode ($ref_label)"
    echo -e "  ${GREEN}1${NC}  Ephemeral (discard changes)"
    echo -e "  ${GREEN}2${NC}  Persistent (save changes)"
    echo -e "  ${GREEN}q${NC}  Back"
    echo ""
    read -r -p "${LIGHT_GRAY}Selection:${NC} " mode_choice
    case "$mode_choice" in
      1)
        run_vm "false"
        press_enter_to_continue
        return 0
        ;;
      2)
        run_vm "true"
        press_enter_to_continue
        return 0
        ;;
      q | Q)
        return 0
        ;;
      *)
        print_error "Invalid option: $mode_choice"
        ;;
    esac
  done
}

function configure_vm_resources() {
  local new_memory=""
  local new_cpus=""

  print_section "Configure VM resources"
  print_info "Current session resources: $VM_MEMORY RAM, $VM_CPUS CPUs"
  echo ""
  read -r -p "Memory (e.g. 8G, empty keeps $VM_MEMORY): " new_memory
  read -r -p "CPUs (empty keeps $VM_CPUS): " new_cpus

  if [[ -n $new_memory ]]; then
    if [[ $new_memory =~ ^[0-9]+[MG]$ ]]; then
      VM_MEMORY="$new_memory"
    else
      print_error "Memory must look like 8G or 8192M"
      return 1
    fi
  fi

  if [[ -n $new_cpus ]]; then
    if [[ $new_cpus =~ ^[0-9]+$ ]] && ((new_cpus >= 1)); then
      VM_CPUS="$new_cpus"
    else
      print_error "CPU count must be a positive integer"
      return 1
    fi
  fi

  print_success "Session resources: $VM_MEMORY RAM, $VM_CPUS CPUs"
}

function connect_ssh() {
  if [[ ! -f $SSH_KEY ]]; then
    print_error "No SSH key yet; run an install first"
    return 1
  fi
  ssh -i "$SSH_KEY" -p "$SSH_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$OMARCHY_USER@127.0.0.1"
  local ssh_status=$?
  if ((ssh_status != 0)); then
    print_info "SSH session ended; the VM may have stopped or become unavailable"
  fi
  return "$ssh_status"
}

function install_ssh_alias() {
  local ssh_directory="$HOME/.ssh"
  local ssh_config="$ssh_directory/config"
  local temporary_config=""
  local block_begin="# >>> OmarchyVM managed SSH alias >>>"
  local block_end="# <<< OmarchyVM managed SSH alias <<<"

  mkdir -p "$ssh_directory"
  chmod 700 "$ssh_directory"
  touch "$ssh_config"

  temporary_config=$(mktemp "$ssh_directory/config.XXXXXX")
  register_temporary_path "$temporary_config"

  {
    printf '%s\n' "$block_begin"
    printf 'Host omarchyvm\n'
    printf '    HostName 127.0.0.1\n'
    printf '    User %s\n' "$OMARCHY_USER"
    printf '    Port %s\n' "$SSH_PORT"
    if [[ -f $SSH_KEY ]]; then
      printf '    IdentityFile %s\n' "$SSH_KEY"
    fi
    printf '    StrictHostKeyChecking no\n'
    printf '    UserKnownHostsFile /dev/null\n'
    printf '%s\n' "$block_end"

    awk -v block_begin="$block_begin" -v block_end="$block_end" '
      $0 == block_begin { in_managed_block = 1; next }
      $0 == block_end { in_managed_block = 0; next }
      in_managed_block { next }
      !started && $0 == "" { next }
      { started = 1; lines[++count] = $0 }
      END {
        if (count > 0) print ""
        for (line = 1; line <= count; line++) print lines[line]
      }
    ' "$ssh_config"
  } > "$temporary_config"

  chmod 600 "$temporary_config"
  mv -- "$temporary_config" "$ssh_config"
  print_success "SSH alias installed; connect with: ssh omarchyvm"
}

function run_interactive_menu() {
  local choice=""

  while true; do
    show_menu
    read -r -p "${LIGHT_GRAY}Selection:${NC} " MENU_CHOICE
    choice="${MENU_CHOICE:-}"
    case "$choice" in
      1)
        select_execution_mode "installed system" || true
        ;;
      2)
        run_vm "true" || true
        press_enter_to_continue
        ;;
      3)
        install_base || true
        press_enter_to_continue
        ;;
      4)
        show_storage_status
        press_enter_to_continue
        ;;
      5)
        clean_cache
        press_enter_to_continue
        ;;
      6)
        list_snapshots
        press_enter_to_continue
        ;;
      7)
        configure_vm_resources || true
        press_enter_to_continue
        ;;
      8)
        print_usage
        press_enter_to_continue
        ;;
      9)
        connect_ssh || true
        press_enter_to_continue
        ;;
      10)
        install_ssh_alias || true
        press_enter_to_continue
        ;;
      q | Q)
        echo ""
        print_goodbye "Goodbye, ${USER:-$(id -un)}!"
        echo ""
        return 0
        ;;
      *)
        print_error "Invalid option: $choice"
        press_enter_to_continue
        ;;
    esac
  done
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Entry Point                                                                  │
# └──────────────────────────────────────────────────────────────────────────────┘

check_root

if [[ $# -eq 0 ]]; then
  clear || true
  print_omarchyvm_banner
  if ! recover_environment; then
    print_info "OmarchyVM closed without starting a VM"
    exit 0
  fi
  run_interactive_menu
  exit 0
fi

persistent="false"
iso_source=""
rebuild="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --persist)
      persistent="true"
      shift
      ;;
    --rebuild)
      rebuild="true"
      shift
      ;;
    --iso)
      if [[ $# -lt 2 ]]; then
        print_error "--iso requires a version (4.0.2), URL, or local path"
        exit 2
      fi
      iso_source="$2"
      shift 2
      ;;
    --user)
      OMARCHY_USER="$2"
      shift 2
      ;;
    --password)
      OMARCHY_PASSWORD="$2"
      shift 2
      ;;
    --hostname)
      OMARCHY_HOSTNAME="$2"
      shift 2
      ;;
    --timezone)
      OMARCHY_TIMEZONE="$2"
      shift 2
      ;;
    --keymap)
      OMARCHY_KEYMAP="$2"
      shift 2
      ;;
    --list)
      list_snapshots
      exit 0
      ;;
    --storage)
      show_storage_status
      exit 0
      ;;
    --clean)
      clean_cache
      exit 0
      ;;
    --install-deps)
      install_all_arch_dependencies
      exit 0
      ;;
    --check-deps)
      check_deps_only
      exit $?
      ;;
    --install-ssh-alias)
      install_ssh_alias
      exit 0
      ;;
    --ssh)
      connect_ssh
      exit 0
      ;;
    --build-cidata-only)
      if ! resolve_iso_source "$iso_source"; then
        exit 2
      fi
      build_cidata
      exit 0
      ;;
    --help | -h)
      print_usage
      exit 0
      ;;
    -*)
      print_error "Unknown option: $1"
      print_usage
      exit 1
      ;;
    *)
      print_error "Unknown argument: $1 (omarchyvm takes no positional branch argument)"
      print_usage
      exit 1
      ;;
  esac
done

if ! resolve_iso_source "$iso_source"; then
  exit 2
fi

if [[ $rebuild == "true" ]]; then
  if ! check_dependencies; then
    exit 1
  fi
  install_base
  exit 0
fi

if ! check_dependencies; then
  exit 1
fi
run_vm "$persistent"
