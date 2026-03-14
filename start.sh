#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Setup Arch — Quick Start
# bash <(curl -fsSL https://raw.githubusercontent.com/polw1/setup/main/start.sh)
# =============================================================================

REPO="https://github.com/polw1/setup.git"
DIR="/root/setup"

# When piped through curl, stdin is the pipe — redirect to /dev/tty for user input
if [[ ! -t 0 ]]; then
  exec < /dev/tty
fi

echo -e "\e[32m"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║       Setup Arch — Quick Start        ║"
echo "  ║  Arch Linux installer (UEFI + NVIDIA) ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "\e[0m"

# Ensure git is available
if ! command -v git &>/dev/null; then
  echo "[start] Installing git..."
  pacman -Sy --noconfirm git
fi

# Clone or update repo
if [[ -d "$DIR/.git" ]]; then
  echo "[start] Updating existing repo..."
  git -C "$DIR" pull --ff-only
else
  echo "[start] Cloning repository..."
  rm -rf "$DIR"
  git clone "$REPO" "$DIR"
fi

# ---------------------------------------------------------------------------
# Mode selection
# ---------------------------------------------------------------------------

echo ""
echo "  Select mode:"
echo ""
echo "    1) Full install    — partition, install Arch, packages, desktop, dotfiles"
echo "    2) Post-install    — packages, NVIDIA, services, dotfiles (on existing Arch)"
echo "    3) Dotfiles only   — deploy all dotfile configs"
echo "    4) Dotfiles select — choose which dotfiles to deploy"
echo "    q) Quit"
echo ""

read -rp "  Choice [1/2/3/4/q]: " MODE

case "$MODE" in
  1)
    echo "[start] Launching full installer..."
    exec bash "$DIR/scripts/live-installer.sh"
    ;;
  2)
    echo "[start] Launching post-install..."
    exec bash "$DIR/scripts/post-install.sh"
    ;;
  3)
    echo "[start] Deploying all dotfiles..."
    exec bash "$DIR/scripts/dotfiles.sh" --all
    ;;
  4)
    echo "[start] Dotfiles selector..."
    exec bash "$DIR/scripts/dotfiles.sh"
    ;;
  q|Q)
    echo "[start] Cancelled."
    exit 0
    ;;
  *)
    echo "[start] Invalid option."
    exit 1
    ;;
esac
