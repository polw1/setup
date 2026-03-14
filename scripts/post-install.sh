#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Setup Arch — Post Install (standalone)
#
# For use on an EXISTING Arch installation (mode 2 in start.sh).
# During a fresh install, chroot-setup.sh handles everything.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGES_FILE="${SCRIPT_DIR}/configs/packages.txt"
AUR_FILE="${SCRIPT_DIR}/configs/aur-packages.txt"
SETUP_USER_FILE="${SCRIPT_DIR}/.setup-user"
LOG_FILE="/var/log/setup-arch-post.log"

log()   { echo -e "\e[32m[post-install]\e[0m $*" | tee -a "$LOG_FILE"; }
warn()  { echo -e "\e[33m[post-install]\e[0m $*" | tee -a "$LOG_FILE"; }
err()   { echo -e "\e[31m[post-install]\e[0m $*" | tee -a "$LOG_FILE" >&2; }
die()   { err "$@"; exit 1; }

require_root() {
  [[ ${EUID} -eq 0 ]] || die "Run as root."
}

# ---------------------------------------------------------------------------
# Pacman config (Color, ILoveCandy, ParallelDownloads, multilib)
# ---------------------------------------------------------------------------

setup_pacman() {
  log "Configuring pacman..."
  local conf="/etc/pacman.conf"

  sed -i 's/^#Color$/Color/' "$conf"

  if ! grep -q '^ILoveCandy' "$conf"; then
    sed -i '/^Color$/a ILoveCandy' "$conf"
  fi

  sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' "$conf"

  if ! grep -q '^\[multilib\]' "$conf"; then
    cat >> "$conf" <<'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
  fi

  log "Pacman configured ✓"
}

# ---------------------------------------------------------------------------
# Wait for network connectivity (standalone mode)
# ---------------------------------------------------------------------------

wait_for_network() {
  local max_attempts=60
  local attempt=1

  # Ensure NetworkManager is running
  systemctl start NetworkManager 2>/dev/null || true
  sleep 3  # give NM time to detect devices

  # Set up DNS fallback (Cloudflare + Google) in case resolved isn't ready
  if [[ ! -f /etc/resolv.conf ]] || ! grep -q '^nameserver' /etc/resolv.conf 2>/dev/null; then
    log "Setting fallback DNS..."
    printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
  fi

  # Try to activate any saved WiFi connection
  local wifi_dev
  wifi_dev="$(nmcli -t -f DEVICE,TYPE device | awk -F: '/wifi/{print $1; exit}')" || true
  if [[ -n "$wifi_dev" ]]; then
    log "WiFi device found: $wifi_dev — trying saved connections..."
    nmcli device connect "$wifi_dev" 2>/dev/null || true
    sleep 5
  fi

  log "Waiting for network..."
  while (( attempt <= max_attempts )); do
    if ping -c1 -W2 archlinux.org &>/dev/null; then
      log "Network is up ✓"
      return 0
    fi
    log "  attempt $attempt/$max_attempts — no connection yet..."

    # At attempt 10, open interactive WiFi setup
    if (( attempt == 10 )); then
      warn "Network still unavailable after 10 attempts."

      # Scan for available networks
      nmcli device wifi rescan 2>/dev/null || true
      sleep 2

      # Try nmtui first (full visual interface — user can browse and select WiFi)
      if command -v nmtui &>/dev/null; then
        warn "Opening nmtui — select your WiFi network..."
        nmtui-connect </dev/tty >/dev/tty 2>/dev/tty || true
        sleep 3
        continue
      fi

      # Fallback: manual SSID/password via nmcli
      echo ""
      echo "  Available WiFi networks:"
      nmcli -f SSID,SIGNAL,SECURITY device wifi list 2>/dev/null || true
      echo ""

      read -rp "  Enter WiFi SSID (or press Enter to keep waiting): " ssid </dev/tty 2>/dev/null || true
      if [[ -n "${ssid:-}" ]]; then
        read -rsp "  Password: " pass </dev/tty 2>/dev/null || true
        echo
        nmcli device wifi connect "$ssid" password "$pass" 2>/dev/null && {
          log "Connected to '$ssid' ✓"
          sleep 3
          continue
        } || warn "Failed to connect to '$ssid'"
      fi
    fi

    sleep 2
    ((attempt++))
  done

  die "No network after $max_attempts attempts. Connect manually and run: bash /setup-arch/scripts/post-install.sh"
}

get_username() {
  if [[ -f "$SETUP_USER_FILE" ]]; then
    USERNAME="$(cat "$SETUP_USER_FILE")"
  else
    read -rp "System username: " USERNAME
  fi
  [[ -n "$USERNAME" ]] || die "Username cannot be empty."
  id "$USERNAME" &>/dev/null || die "User $USERNAME does not exist."
  USER_HOME="/home/${USERNAME}"
  log "User: $USERNAME"
}

# ---------------------------------------------------------------------------
# Official packages (pacman)
# ---------------------------------------------------------------------------

install_repo_packages() {
  log "Installing official packages..."
  mapfile -t pkgs < <(grep -Ev '^\s*#|^\s*$' "$PACKAGES_FILE")
  pacman -Syu --noconfirm --needed "${pkgs[@]}"
}

# ---------------------------------------------------------------------------
# Install yay (AUR helper) as normal user
# ---------------------------------------------------------------------------

install_yay() {
  if command -v yay &>/dev/null; then
    log "yay already installed."
    return
  fi

  log "Installing yay..."
  local YAY_DIR="/tmp/yay-build"
  rm -rf "$YAY_DIR"

  sudo -u "$USERNAME" bash -c "
    git clone https://aur.archlinux.org/yay-bin.git '$YAY_DIR' &&
    cd '$YAY_DIR' &&
    makepkg -si --noconfirm
  "

  rm -rf "$YAY_DIR"
  log "yay installed ✓"
}

# ---------------------------------------------------------------------------
# AUR packages
# ---------------------------------------------------------------------------

install_aur_packages() {
  log "Installing AUR packages..."
  mapfile -t aur_pkgs < <(grep -Ev '^\s*#|^\s*$' "$AUR_FILE")

  if [[ ${#aur_pkgs[@]} -eq 0 ]]; then
    log "No AUR packages to install."
    return
  fi

  sudo -u "$USERNAME" yay -S --noconfirm --needed "${aur_pkgs[@]}"
}

# ---------------------------------------------------------------------------
# Rust toolchain
# ---------------------------------------------------------------------------

setup_rust() {
  log "Configuring Rust (rustup default stable)..."
  sudo -u "$USERNAME" rustup default stable
}

# ---------------------------------------------------------------------------
# zram (compressed RAM swap)
# ---------------------------------------------------------------------------

setup_zram() {
  log "Configuring zram..."
  mkdir -p /etc/systemd
  cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
  systemctl daemon-reload
  systemctl start /dev/zram0 2>/dev/null || true
  log "zram configured (50% RAM, zstd) ✓"
}

# ---------------------------------------------------------------------------
# NVIDIA Wayland
# ---------------------------------------------------------------------------

setup_nvidia() {
  log "Configuring NVIDIA for Wayland..."

  # Early KMS modules
  local MKINIT_CONF="/etc/mkinitcpio.conf"
  if ! grep -q "nvidia" "$MKINIT_CONF"; then
    sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINIT_CONF"
    mkinitcpio -P
    log "NVIDIA modules added to initramfs."
  fi

  # Hook to auto-rebuild initramfs when nvidia updates
  mkdir -p /etc/pacman.d/hooks
  cat > /etc/pacman.d/hooks/nvidia.hook <<'EOF'
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-open
Target=linux

[Action]
Description=Rebuild initramfs after NVIDIA driver update
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF

  log "NVIDIA hook created ✓"
}

# ---------------------------------------------------------------------------
# Boot backup hook (auto rsync /boot on kernel update)
# ---------------------------------------------------------------------------

setup_boot_backup_hook() {
  log "Creating boot backup pacman hook..."

  mkdir -p /etc/pacman.d/hooks

  cat > /etc/pacman.d/hooks/95-boot-backup.hook <<'EOF'
[Trigger]
Operation = Upgrade
Operation = Install
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Depends = rsync
Description = Backing up /boot...
When = PostTransaction
Exec = /usr/bin/rsync -a --delete /boot/ /boot.bak/
EOF

  log "Boot backup hook created (rsync /boot → /boot.bak on kernel update) ✓"
}

# ---------------------------------------------------------------------------
# Enable services
# ---------------------------------------------------------------------------

enable_services() {
  log "Enabling services..."

  systemctl enable --now NetworkManager   2>/dev/null || true
  systemctl enable --now bluetooth        2>/dev/null || true
  systemctl enable --now docker           2>/dev/null || true
  systemctl enable --now fstrim.timer     2>/dev/null || true

  # Add user to docker group
  usermod -aG docker "$USERNAME"
  log "Services enabled (NetworkManager, bluetooth, docker, fstrim.timer)"
}

# ---------------------------------------------------------------------------
# System tuning (sysctl + systemd timeout)
# ---------------------------------------------------------------------------

setup_system_tuning() {
  log "Applying system performance tweaks..."

  # sysctl — from gjpin/arch-linux (laptop-optimized)
  cat > /etc/sysctl.d/99-setup-arch.conf <<'EOF'
# Reduce swappiness (prefer RAM over zram/swap)
vm.swappiness = 10

# Keep more dentries/inodes in cache
vm.vfs_cache_pressure = 50

# Reduce disk write clustering (better for SSDs)
vm.page-cluster = 0
EOF
  sysctl --system &>/dev/null || true
  log "sysctl tweaks applied ✓"

  # systemd — reduce stop timeout (default 90s is too long)
  mkdir -p /etc/systemd/system.conf.d
  cat > /etc/systemd/system.conf.d/timeout.conf <<'EOF'
[Manager]
DefaultTimeoutStopSec=5s
EOF
  systemctl daemon-reexec 2>/dev/null || true
  log "systemd DefaultTimeoutStopSec=5s ✓"
}

# ---------------------------------------------------------------------------
# Environment variables for Sway + NVIDIA
# ---------------------------------------------------------------------------

setup_env_vars() {
  log "Configuring Wayland/NVIDIA environment variables..."

  local ENV_FILE="${USER_HOME}/.config/environment.d/wayland-nvidia.conf"
  mkdir -p "$(dirname "$ENV_FILE")"

  cat > "$ENV_FILE" <<'EOF'
# Wayland + NVIDIA
WLR_NO_HARDWARE_CURSORS=1
WLR_RENDERER=vulkan
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
XDG_SESSION_TYPE=wayland
XDG_CURRENT_DESKTOP=sway
EOF

  chown -R "${USERNAME}:${USERNAME}" "${USER_HOME}/.config/environment.d"
  log "Variables in $ENV_FILE ✓"

  # Electron/Chromium Wayland flags (Brave, Chrome, VSCode, etc.)
  local ELECTRON_FLAGS="${USER_HOME}/.config/electron-flags.conf"
  cat > "$ELECTRON_FLAGS" <<'EOF'
--ozone-platform-hint=auto
--enable-features=WaylandWindowDecorations
EOF
  # Chromium-based browsers read this too
  cp "$ELECTRON_FLAGS" "${USER_HOME}/.config/chromium-flags.conf"
  cp "$ELECTRON_FLAGS" "${USER_HOME}/.config/brave-flags.conf"
  cp "$ELECTRON_FLAGS" "${USER_HOME}/.config/chrome-flags.conf"
  chown "${USERNAME}:${USERNAME}" "$ELECTRON_FLAGS" \
    "${USER_HOME}/.config/chromium-flags.conf" \
    "${USER_HOME}/.config/brave-flags.conf" \
    "${USER_HOME}/.config/chrome-flags.conf"
  log "Electron/Chromium Wayland flags configured ✓"
}

# ---------------------------------------------------------------------------
# Auto-start Sway on login (TTY1)
# ---------------------------------------------------------------------------

setup_sway_autostart() {
  log "Configuring Sway auto-start on TTY1..."

  local ZPROFILE="${USER_HOME}/.zprofile"

  # Only add if not already present
  if grep -q 'exec sway' "$ZPROFILE" 2>/dev/null; then
    log "Sway auto-start already configured, skipping."
    return
  fi

  # Only starts on TTY1 if Sway is not already running
  cat >> "$ZPROFILE" <<'EOF'

# Auto-start Sway on TTY1
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec sway --unsupported-gpu
fi
EOF

  chown "${USERNAME}:${USERNAME}" "$ZPROFILE"
  log "Sway will start automatically when logging in on TTY1 ✓"
}

# ---------------------------------------------------------------------------
# Copy configs (Sway, Waybar, wofi, nvim)
# ---------------------------------------------------------------------------

deploy_configs() {
  log "Deploying Sway, Waybar, wofi, nvim, tmux configs..."

  local CONFIGS_SRC="${SCRIPT_DIR}/configs/dotfiles"
  local DEST="${USER_HOME}/.config"

  mkdir -p "$DEST"

  if [[ -d "$CONFIGS_SRC" ]]; then
    cp -rn "$CONFIGS_SRC/sway"   "$DEST/" 2>/dev/null || true
    cp -rn "$CONFIGS_SRC/waybar" "$DEST/" 2>/dev/null || true
    cp -rn "$CONFIGS_SRC/wofi"   "$DEST/" 2>/dev/null || true
    cp -rn "$CONFIGS_SRC/nvim"   "$DEST/" 2>/dev/null || true
    cp -rn "$CONFIGS_SRC/tmux"   "$DEST/" 2>/dev/null || true
    chown -R "${USERNAME}:${USERNAME}" "$DEST"
    log "Configs deployed ✓"
  else
    warn "Directory $CONFIGS_SRC not found, skipping configs."
  fi

  # Create XDG user directories
  sudo -u "$USERNAME" xdg-user-dirs-update 2>/dev/null || true
  log "XDG user directories created ✓"

  # Add user to video group (for brightness control with light)
  usermod -aG video "$USERNAME" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Install custom scripts to ~/.local/bin
# ---------------------------------------------------------------------------

install_bin_scripts() {
  local BIN_SRC="${SCRIPT_DIR}/bin"
  local BIN_DEST="${USER_HOME}/.local/bin"

  if [[ ! -d "$BIN_SRC" ]]; then
    warn "No bin/ directory found, skipping."
    return
  fi

  mkdir -p "$BIN_DEST"

  for script in "$BIN_SRC"/*; do
    [[ -f "$script" ]] || continue
    local name
    name="$(basename "$script")"
    local dest="${BIN_DEST}/${name}"

    if [[ -L "$dest" || -f "$dest" ]]; then
      log "$name already in ~/.local/bin, skipping."
    else
      cp "$script" "$dest"
      chmod +x "$dest"
      log "Installed $name → ~/.local/bin/$name ✓"
    fi
  done

  chown -R "${USERNAME}:${USERNAME}" "$BIN_DEST"

  # Ensure ~/.local/bin is in PATH (zsh)
  local ZPROFILE="${USER_HOME}/.zprofile"
  if ! grep -q '.local/bin' "$ZPROFILE" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZPROFILE"
    chown "${USERNAME}:${USERNAME}" "$ZPROFILE"
    log "Added ~/.local/bin to PATH in .zprofile ✓"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  log "=== Setup Arch — Post Install (standalone) ==="

  require_root
  get_username
  setup_pacman
  wait_for_network
  install_repo_packages
  install_yay
  install_aur_packages
  setup_rust
  setup_zram
  setup_nvidia
  setup_boot_backup_hook
  enable_services
  setup_system_tuning
  setup_env_vars
  deploy_configs
  install_bin_scripts
  setup_sway_autostart

  log ""
  log "✅ Post-install complete!"
  log "Reboot and log in as $USERNAME on TTY1."
  log "Sway will start automatically."
  log ""
}

main "$@"
