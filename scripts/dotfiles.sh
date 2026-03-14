#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Setup Arch — Dotfiles Manager
# Deploy or update dotfiles independently from the full install
#
# Usage:
#   bash scripts/dotfiles.sh              # interactive menu
#   bash scripts/dotfiles.sh --all        # deploy all dotfiles
#   bash scripts/dotfiles.sh sway         # deploy only sway
#   bash scripts/dotfiles.sh sway waybar  # deploy sway + waybar
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGS_SRC="${SCRIPT_DIR}/configs/dotfiles"

BIN_SRC="${SCRIPT_DIR}/bin"

log()  { echo -e "\e[32m[dotfiles]\e[0m $*"; }
warn() { echo -e "\e[33m[dotfiles]\e[0m $*"; }
die()  { echo -e "\e[31m[dotfiles]\e[0m $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Install custom bin scripts to ~/.local/bin
# ---------------------------------------------------------------------------

install_bin_scripts() {
  [[ -d "$BIN_SRC" ]] || return 0
  local BIN_DEST="${TARGET_HOME}/.local/bin"
  mkdir -p "$BIN_DEST"

  for script in "$BIN_SRC"/*; do
    [[ -f "$script" ]] || continue
    local name
    name="$(basename "$script")"
    local dest="${BIN_DEST}/${name}"

    if [[ -f "$dest" ]]; then
      read -rp "  Overwrite $dest? [y/N] " ans
      [[ "$ans" =~ ^[Yy]$ ]] || { log "Skipped $name"; continue; }
    fi

    cp "$script" "$dest"
    chmod +x "$dest"
    log "Installed $name → ~/.local/bin/$name ✓"
  done

  if [[ ${EUID} -eq 0 ]]; then
    chown -R "${TARGET_USER}:${TARGET_USER}" "$BIN_DEST"
  fi

  # Ensure ~/.local/bin is in PATH
  local ZPROFILE="${TARGET_HOME}/.zprofile"
  if ! grep -q '.local/bin' "$ZPROFILE" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZPROFILE"
    if [[ ${EUID} -eq 0 ]]; then
      chown "${TARGET_USER}:${TARGET_USER}" "$ZPROFILE"
    fi
    log "Added ~/.local/bin to PATH in .zprofile ✓"
  fi
}

# ---------------------------------------------------------------------------
# Detect target user and home
# ---------------------------------------------------------------------------

detect_user() {
  if [[ ${EUID} -eq 0 ]]; then
    if [[ -f "${SCRIPT_DIR}/.setup-user" ]]; then
      TARGET_USER="$(cat "${SCRIPT_DIR}/.setup-user")"
    else
      read -rp "Target username: " TARGET_USER
    fi
  else
    TARGET_USER="$(whoami)"
  fi

  [[ -n "$TARGET_USER" ]] || die "Username cannot be empty."
  id "$TARGET_USER" &>/dev/null || die "User $TARGET_USER does not exist."
  TARGET_HOME="/home/${TARGET_USER}"
  DEST="${TARGET_HOME}/.config"
  mkdir -p "$DEST"
  log "Target: $TARGET_USER ($DEST)"
}

# ---------------------------------------------------------------------------
# Available dotfile modules
# ---------------------------------------------------------------------------

AVAILABLE_MODULES=()

discover_modules() {
  for dir in "$CONFIGS_SRC"/*/; do
    [[ -d "$dir" ]] || continue
    AVAILABLE_MODULES+=("$(basename "$dir")")
  done

  if [[ ${#AVAILABLE_MODULES[@]} -eq 0 ]]; then
    die "No dotfile modules found in $CONFIGS_SRC"
  fi
}

# ---------------------------------------------------------------------------
# Deploy a single module
# ---------------------------------------------------------------------------

deploy_module() {
  local module="$1"
  local src="${CONFIGS_SRC}/${module}"

  if [[ ! -d "$src" ]]; then
    warn "Module '$module' not found in $CONFIGS_SRC, skipping."
    return 1
  fi

  local dest_dir="${DEST}/${module}"

  if [[ -d "$dest_dir" ]]; then
    read -rp "  '$module' already exists. Overwrite? [y/N] " answer
    if [[ "${answer,,}" != "y" ]]; then
      log "  Skipped '$module'."
      return 0
    fi
    rm -rf "$dest_dir"
  fi

  cp -r "$src" "$dest_dir"

  # Fix ownership if running as root
  if [[ ${EUID} -eq 0 ]]; then
    chown -R "${TARGET_USER}:${TARGET_USER}" "$dest_dir"
  fi

  log "  ✓ $module deployed"
}

# ---------------------------------------------------------------------------
# Deploy all modules (no prompts for overwrite)
# ---------------------------------------------------------------------------

deploy_all() {
  log "Deploying all dotfiles..."
  for module in "${AVAILABLE_MODULES[@]}"; do
    local src="${CONFIGS_SRC}/${module}"
    local dest_dir="${DEST}/${module}"

    rm -rf "$dest_dir"
    cp -r "$src" "$dest_dir"

    if [[ ${EUID} -eq 0 ]]; then
      chown -R "${TARGET_USER}:${TARGET_USER}" "$dest_dir"
    fi

    log "  ✓ $module"
  done
  install_bin_scripts
  log "All dotfiles deployed ✓"
}

# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------

interactive_menu() {
  echo ""
  echo "  Available dotfile modules:"
  echo ""
  local i=1
  for module in "${AVAILABLE_MODULES[@]}"; do
    echo "    $i) $module"
    ((i++))
  done
  echo ""
  echo "    a) Deploy ALL"
  echo "    b) Install bin scripts (~/.local/bin)"
  echo "    q) Quit"
  echo ""

  read -rp "  Select modules (e.g.: 1 2 3, a for all, b for bin, q to quit): " selection

  if [[ "$selection" == "q" ]]; then
    log "Cancelled."
    exit 0
  fi

  if [[ "$selection" == "a" ]]; then
    deploy_all
    return
  fi

  if [[ "$selection" == "b" ]]; then
    install_bin_scripts
    return
  fi

  for sel in $selection; do
    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#AVAILABLE_MODULES[@]} )); then
      deploy_module "${AVAILABLE_MODULES[$((sel - 1))]}"
    else
      warn "Invalid selection: $sel"
    fi
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  detect_user
  discover_modules

  if [[ $# -eq 0 ]]; then
    # No args → interactive menu
    interactive_menu
  elif [[ "$1" == "--all" ]]; then
    # --all → deploy everything
    deploy_all
  elif [[ "$1" == "--bin" || "$1" == "bin" ]]; then
    # --bin → install only bin scripts
    install_bin_scripts
  else
    # Specific modules as args
    for module in "$@"; do
      deploy_module "$module"
    done
  fi

  log "Done."
}

main "$@"
