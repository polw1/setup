#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Setup Arch — Live Installer
# Runs from the Arch Linux Live CD (UEFI)
# =============================================================================

LOG_FILE="/tmp/setup-arch-live.log"

log()   { echo -e "\e[32m[live-installer]\e[0m $*" | tee -a "$LOG_FILE"; }
warn()  { echo -e "\e[33m[live-installer]\e[0m $*" | tee -a "$LOG_FILE"; }
err()   { echo -e "\e[31m[live-installer]\e[0m $*" | tee -a "$LOG_FILE" >&2; }
die()   { err "$@"; exit 1; }

# ---------------------------------------------------------------------------
# Validations
# ---------------------------------------------------------------------------

require_root() {
  [[ ${EUID} -eq 0 ]] || die "Run as root."
}

check_uefi() {
  [[ -d /sys/firmware/efi ]] || die "UEFI not detected. This script requires UEFI boot."
}

check_network() {
  ping -c 1 -W 3 archlinux.org &>/dev/null || die "No network. Connect before continuing."
}

# ---------------------------------------------------------------------------
# Disk selection
# ---------------------------------------------------------------------------

select_disk() {
  log "Available disks:"
  echo
  lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk
  echo

  read -rp "Enter target disk (e.g.: sda, nvme0n1): " DISK_NAME
  DISK="/dev/${DISK_NAME}"

  [[ -b "$DISK" ]] || die "Disk $DISK not found."

  warn "⚠  ALL data on $DISK will be ERASED!"
  read -rp "Are you sure? Type YES to confirm: " CONFIRM
  [[ "$CONFIRM" == "YES" ]] || die "Cancelled by user."

  # Detect partition suffix (nvme uses p1, sata uses 1)
  if [[ "$DISK" == *nvme* ]]; then
    PART_PREFIX="${DISK}p"
  else
    PART_PREFIX="${DISK}"
  fi

  EFI_PART="${PART_PREFIX}1"
  ROOT_PART="${PART_PREFIX}2"
}

# ---------------------------------------------------------------------------
# GPT partitioning: EFI (1G) + Root (remaining ext4)
# ---------------------------------------------------------------------------

partition_disk() {
  log "Partitioning $DISK (GPT: EFI 1G + Root remaining)..."

  sgdisk --zap-all "$DISK"

  sgdisk -n 1:0:+1G   -t 1:ef00 -c 1:"EFI"  "$DISK"
  sgdisk -n 2:0:0     -t 2:8300 -c 2:"Root" "$DISK"

  partprobe "$DISK"
  sleep 1

  log "Partitions created: $EFI_PART (EFI) and $ROOT_PART (Root)"
}

# ---------------------------------------------------------------------------
# Format and mount
# ---------------------------------------------------------------------------

format_and_mount() {
  log "Formatting partitions..."
  mkfs.fat -F32 "$EFI_PART"
  mkfs.ext4 -F "$ROOT_PART"

  log "Mounting on /mnt..."
  if mountpoint -q /mnt; then
    warn "/mnt already mounted, unmounting first..."
    umount -R /mnt
  fi
  mount "$ROOT_PART" /mnt
  mkdir -p /mnt/boot
  mount "$EFI_PART" /mnt/boot
}

# ---------------------------------------------------------------------------
# Base installation
# ---------------------------------------------------------------------------

install_base() {
  log "Syncing clock..."
  timedatectl set-ntp true

  log "Installing base system (pacstrap)..."
  pacstrap -K /mnt \
    base linux linux-firmware \
    amd-ucode \
    networkmanager \
    sudo \
    neovim \
    git \
    base-devel

  log "Generating fstab..."
  genfstab -U /mnt >> /mnt/etc/fstab
}

# ---------------------------------------------------------------------------
# Save WiFi connection for the installed system
# ---------------------------------------------------------------------------

save_wifi_for_target() {
  local iwd_dir="/var/lib/iwd"
  local wifi_interface ssid psk=""

  # Detect WiFi interface
  wifi_interface="$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -n1)" || true

  if [[ -z "$wifi_interface" ]]; then
    log "No WiFi interface detected (ethernet). Skipping WiFi profile."
    return
  fi

  # Try multiple methods to get the connected SSID
  # Method 1: iw (most reliable)
  ssid="$(iw dev "$wifi_interface" link 2>/dev/null | awk -F': ' '/SSID:/{print $2}')" || true

  # Method 2: iwctl
  if [[ -z "$ssid" ]]; then
    ssid="$(iwctl station "$wifi_interface" show 2>/dev/null \
      | sed -n 's/.*Connected network[[:space:]]*//p' | xargs)" || true
  fi

  # Method 3: check iwd directory for any .psk files
  if [[ -z "$ssid" ]]; then
    for f in "$iwd_dir"/*.psk; do
      [[ -f "$f" ]] || continue
      ssid="$(basename "$f" .psk)"
      break
    done
  fi

  # Fallback: ask the user
  if [[ -z "$ssid" ]]; then
    warn "Could not detect WiFi SSID automatically."
    read -rp "  Enter your WiFi SSID (or leave empty to skip): " ssid
    if [[ -z "$ssid" ]]; then
      warn "Skipping WiFi profile. You will need to connect manually after reboot."
      return
    fi
    read -rsp "  WiFi password: " psk; echo
  fi

  # Get PSK from iwd config if not already provided
  if [[ -z "$psk" ]]; then
    for f in "$iwd_dir"/*.psk; do
      [[ -f "$f" ]] || continue
      local fname
      fname="$(basename "$f" .psk)"
      if [[ "$fname" == "$ssid" ]]; then
        psk="$(awk -F= '/^Passphrase=/{print $2}' "$f" 2>/dev/null)" || true
        break
      fi
    done
  fi

  # Still no password? Ask
  if [[ -z "$psk" ]]; then
    read -rsp "  WiFi password for '$ssid': " psk; echo
  fi

  log "Saving WiFi profile: '$ssid'"

  local nm_dir="/mnt/etc/NetworkManager/system-connections"
  mkdir -p "$nm_dir"
  local nm_file="${nm_dir}/${ssid}.nmconnection"

  cat > "$nm_file" <<NMEOF
[connection]
id=${ssid}
type=wifi
autoconnect=true

[wifi]
ssid=${ssid}
mode=infrastructure

[wifi-security]
key-mgmt=wpa-psk
psk=${psk}

[ipv4]
method=auto

[ipv6]
method=auto
NMEOF

  chmod 600 "$nm_file"
  log "WiFi profile saved for NetworkManager: '$ssid' ✓"
  log "System will auto-connect to '$ssid' after reboot."
}

# ---------------------------------------------------------------------------
# Copy scripts into chroot
# ---------------------------------------------------------------------------

copy_scripts_to_chroot() {
  local SCRIPT_DIR
  SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

  log "Copying scripts to /mnt/setup-arch..."
  cp -r "$SCRIPT_DIR" /mnt/setup-arch
}

# ---------------------------------------------------------------------------
# Chroot
# ---------------------------------------------------------------------------

run_chroot() {
  log "Entering chroot..."
  arch-chroot /mnt /bin/bash /setup-arch/scripts/chroot-setup.sh
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  log "=== Setup Arch — Live Installer ==="

  require_root
  check_uefi
  check_network
  log "Environment validated ✓"

  select_disk
  partition_disk
  format_and_mount
  install_base
  save_wifi_for_target
  copy_scripts_to_chroot
  run_chroot

  log ""
  log "✅ Installation complete!"
  log "Next steps:"
  log "  1) umount -R /mnt"
  log "  2) reboot"
  log ""
  log "Log in as your user on TTY1 — Sway starts automatically."
  log "(Everything was installed during chroot — no post-install needed)"
  log ""
}

main "$@"
