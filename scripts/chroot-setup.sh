#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Setup Arch — Chroot Setup
# Runs inside arch-chroot, called by live-installer.sh
#
# Does ALL heavy work here (packages, AUR, configs) while the live CD's
# network is still active. No firstboot service needed — reboot straight
# into a working desktop.
# =============================================================================

SCRIPT_DIR="/setup-arch"
PACKAGES_FILE="${SCRIPT_DIR}/configs/packages.txt"
AUR_FILE="${SCRIPT_DIR}/configs/aur-packages.txt"

log()   { echo -e "\e[32m[chroot-setup]\e[0m $*"; }
warn()  { echo -e "\e[33m[chroot-setup]\e[0m $*"; }
die()   { echo -e "\e[31m[chroot-setup]\e[0m $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Timezone and locale
# ---------------------------------------------------------------------------

setup_locale() {
  log "Setting timezone to America/Sao_Paulo..."
  ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
  hwclock --systohc

  log "Setting locale (pt_BR.UTF-8 + en_US.UTF-8)..."
  sed -i 's/^#pt_BR.UTF-8/pt_BR.UTF-8/' /etc/locale.gen
  sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
  locale-gen

  echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
  echo "KEYMAP=br-abnt2"  > /etc/vconsole.conf
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

  pacman -Sy
  log "Pacman configured (Color, ILoveCandy, ParallelDownloads=5, multilib) ✓"
}

# ---------------------------------------------------------------------------
# Hostname
# ---------------------------------------------------------------------------

setup_hostname() {
  read -rp "Hostname (e.g.: archnitro): " HOSTNAME
  HOSTNAME="${HOSTNAME:-archnitro}"

  echo "$HOSTNAME" > /etc/hostname

  cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

  log "Hostname: $HOSTNAME"
}

# ---------------------------------------------------------------------------
# User
# ---------------------------------------------------------------------------

setup_user() {
  read -rp "Username: " USERNAME
  [[ -n "$USERNAME" ]] || die "Username cannot be empty."

  if id "$USERNAME" &>/dev/null; then
    log "User $USERNAME already exists, skipping creation."
  else
    log "Creating user $USERNAME..."
    useradd -m -G wheel -s /usr/bin/zsh "$USERNAME"
  fi

  log "Set password for user $USERNAME:"
  passwd "$USERNAME"

  log "Set root password:"
  passwd

  # Enable sudo for wheel group
  sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

  USER_HOME="/home/${USERNAME}"

  # Save username for standalone post-install (mode 2)
  echo "$USERNAME" > "${SCRIPT_DIR}/.setup-user"
}

# ---------------------------------------------------------------------------
# Bootloader (systemd-boot)
# ---------------------------------------------------------------------------

setup_bootloader() {
  if bootctl is-installed &>/dev/null; then
    log "systemd-boot already installed, updating..."
    bootctl update
  else
    log "Installing systemd-boot..."
    bootctl install
  fi

  ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$(findmnt -n -o SOURCE /)")

  cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
console-mode max
editor  no
EOF

  cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options root=PARTUUID=${ROOT_PARTUUID} rw nvidia-drm.modeset=1
EOF

  log "systemd-boot configured with nvidia-drm.modeset=1"
}

# ---------------------------------------------------------------------------
# Official packages (pacman) — uses live CD network
# ---------------------------------------------------------------------------

install_repo_packages() {
  log "Installing official packages..."
  pacman -S --noconfirm --needed zsh
  mapfile -t pkgs < <(grep -Ev '^\s*#|^\s*$' "$PACKAGES_FILE")
  pacman -Syu --noconfirm --needed "${pkgs[@]}"
}

# ---------------------------------------------------------------------------
# Install yay (AUR helper)
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
# NVIDIA Wayland
# ---------------------------------------------------------------------------

setup_nvidia() {
  log "Configuring NVIDIA for Wayland..."

  local MKINIT_CONF="/etc/mkinitcpio.conf"
  if ! grep -q "nvidia" "$MKINIT_CONF"; then
    sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINIT_CONF"
    mkinitcpio -P
    log "NVIDIA modules added to initramfs."
  fi

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
# Pacman hooks (boot backup)
# ---------------------------------------------------------------------------

setup_pacman_hooks() {
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

  log "Boot backup hook created ✓"
}

# ---------------------------------------------------------------------------
# System tuning (zram, sysctl, systemd timeout)
# ---------------------------------------------------------------------------

setup_system_tuning() {
  log "Configuring zram..."
  mkdir -p /etc/systemd
  cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF

  log "Applying sysctl tweaks..."
  cat > /etc/sysctl.d/99-setup-arch.conf <<'EOF'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.page-cluster = 0
EOF

  log "Setting systemd timeout..."
  mkdir -p /etc/systemd/system.conf.d
  cat > /etc/systemd/system.conf.d/timeout.conf <<'EOF'
[Manager]
DefaultTimeoutStopSec=5s
EOF

  log "System tuning configured (zram, sysctl, timeout) ✓"
}

# ---------------------------------------------------------------------------
# Enable services (systemctl enable — no --now, we're in chroot)
# ---------------------------------------------------------------------------

enable_services() {
  log "Enabling services..."
  systemctl enable NetworkManager
  systemctl enable NetworkManager-wait-online
  systemctl enable systemd-timesyncd
  systemctl enable systemd-resolved
  systemctl enable fstrim.timer
  systemctl enable bluetooth
  systemctl enable docker

  # Add user to docker + video groups
  usermod -aG docker "$USERNAME"
  usermod -aG video "$USERNAME"
  log "Services enabled (NM, bluetooth, docker, fstrim, resolved) ✓"
}

# ---------------------------------------------------------------------------
# Environment variables for Sway + NVIDIA
# ---------------------------------------------------------------------------

setup_env_vars() {
  log "Configuring Wayland/NVIDIA environment variables..."

  local ENV_FILE="${USER_HOME}/.config/environment.d/wayland-nvidia.conf"
  mkdir -p "$(dirname "$ENV_FILE")"

  cat > "$ENV_FILE" <<'EOF'
WLR_NO_HARDWARE_CURSORS=1
WLR_RENDERER=vulkan
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
XDG_SESSION_TYPE=wayland
XDG_CURRENT_DESKTOP=sway
EOF

  chown -R "${USERNAME}:${USERNAME}" "${USER_HOME}/.config/environment.d"

  # Electron/Chromium Wayland flags
  local ELECTRON_FLAGS="${USER_HOME}/.config/electron-flags.conf"
  cat > "$ELECTRON_FLAGS" <<'EOF'
--ozone-platform-hint=auto
--enable-features=WaylandWindowDecorations
EOF
  cp "$ELECTRON_FLAGS" "${USER_HOME}/.config/chromium-flags.conf"
  cp "$ELECTRON_FLAGS" "${USER_HOME}/.config/brave-flags.conf"
  cp "$ELECTRON_FLAGS" "${USER_HOME}/.config/chrome-flags.conf"
  chown "${USERNAME}:${USERNAME}" "$ELECTRON_FLAGS" \
    "${USER_HOME}/.config/chromium-flags.conf" \
    "${USER_HOME}/.config/brave-flags.conf" \
    "${USER_HOME}/.config/chrome-flags.conf"
  log "Environment + Electron Wayland flags configured ✓"
}

# ---------------------------------------------------------------------------
# Deploy dotfiles (sway, waybar, wofi, nvim, tmux)
# ---------------------------------------------------------------------------

deploy_configs() {
  log "Deploying dotfiles..."

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

  sudo -u "$USERNAME" xdg-user-dirs-update 2>/dev/null || true
  log "XDG user directories created ✓"
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

  local ZPROFILE="${USER_HOME}/.zprofile"
  if ! grep -q '.local/bin' "$ZPROFILE" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZPROFILE"
    chown "${USERNAME}:${USERNAME}" "$ZPROFILE"
    log "Added ~/.local/bin to PATH ✓"
  fi
}

# ---------------------------------------------------------------------------
# Auto-start Sway on TTY1
# ---------------------------------------------------------------------------

setup_sway_autostart() {
  log "Configuring Sway auto-start on TTY1..."

  local ZPROFILE="${USER_HOME}/.zprofile"

  if grep -q 'exec sway' "$ZPROFILE" 2>/dev/null; then
    log "Sway auto-start already configured, skipping."
    return
  fi

  cat >> "$ZPROFILE" <<'EOF'

# Auto-start Sway on TTY1
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec sway --unsupported-gpu
fi
EOF

  chown "${USERNAME}:${USERNAME}" "$ZPROFILE"
  log "Sway auto-start on TTY1 ✓"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  log "=== Setup Arch — Chroot Setup ==="
  log "(all packages installed now — using live CD network)"
  log ""

  # Stage 1: System config
  setup_locale
  setup_pacman
  setup_hostname

  # Stage 2: User
  setup_user

  # Stage 3: Bootloader
  setup_bootloader

  # Stage 4: All packages (uses live CD network — no WiFi issues)
  install_repo_packages
  install_yay
  install_aur_packages
  setup_rust

  # Stage 5: System config (NVIDIA, hooks, tuning)
  setup_nvidia
  setup_pacman_hooks
  setup_system_tuning

  # Stage 6: Services
  enable_services

  # Stage 7: User environment
  setup_env_vars
  deploy_configs
  install_bin_scripts
  setup_sway_autostart

  log ""
  log "✅ Setup complete!"
  log "Exit chroot, unmount, and reboot."
  log "Log in as $USERNAME on TTY1 — Sway starts automatically."
  log ""
}

main "$@"
