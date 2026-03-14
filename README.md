# Setup

My personal setup

---

## Repository structure

```
start.sh              → one-liner entry point (curl | bash) — mode menu
scripts/
  live-installer.sh   → run from Live CD (partition, pacstrap, chroot)
  chroot-setup.sh     → ALL setup inside chroot (locale, user, packages, NVIDIA, configs)
  post-install.sh     → standalone re-apply for existing Arch (mode 2)
  dotfiles.sh         → standalone dotfiles manager (interactive / --all / per-module)
bin/
  modify              → markdown code-block runner (python, rust, zsh, plantuml)
  update-all          → full system update (pacman, AUR, rust, flatpak, npm)
configs/
  packages.txt        → official packages (pacman)
  aur-packages.txt    → AUR packages (yay)
  dotfiles/
    nvim/             → Neovim config (NvChad-based, LSP, DAP, Rust, Flutter)
    tmux/tmux.conf    → tmux config (vim keys, Dracula theme, resurrect)
    sway/config       → Sway config (hotkeys, appearance, autostart)
    waybar/config     → Waybar config (modules)
    waybar/style.css  → Waybar theme
    wofi/style.css    → wofi theme
    yazi/yazi.toml    → Yazi config (Neovim as text editor)
docs/
  PLANO-SWAY.md       → detailed desktop plan
```

Scripts in `bin/` are installed to `~/.local/bin/` during post-install and are available as commands (e.g. `modify file.md`, `update-all`).

## Safety

Installation scripts can wipe disks. Always:

- confirm the target disk twice
- review partition commands before executing
- test in a VM first

---

## Usage

### Quick start (one-liner)

Boot from the Arch Live CD, connect to the internet, and run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/polw1/setup/main/start.sh)
```

You will see a mode menu:

| Mode | Description |
|---|---|
| **1) Full install** | Partition → install Arch → packages → desktop → dotfiles |
| **2) Post-install** | Packages, NVIDIA, services, dotfiles (on existing Arch) |
| **3) Dotfiles only** | Deploy all dotfile configs at once |
| **4) Dotfiles select** | Interactive menu to choose which dotfiles to deploy |

### Dotfiles manager

You can also run the dotfiles manager directly:

```bash
# Interactive menu — pick which modules to deploy
bash scripts/dotfiles.sh

# Deploy all dotfiles at once
bash scripts/dotfiles.sh --all

# Deploy specific modules only
bash scripts/dotfiles.sh sway waybar
```

Available modules are auto-discovered from `configs/dotfiles/` (currently: nvim, sway, tmux, waybar, wofi, yazi).

### Manual method

#### 1. Boot from the Arch Live CD

Connect to the internet (ethernet or `iwctl`) and clone the repository:

```bash
pacman -Sy git
git clone https://github.com/polw1/setup.git
cd setup
bash scripts/live-installer.sh
```

The script will:
- Validate UEFI and network
- Ask for the target disk (with double confirmation)
- Partition (EFI 1G + Root ext4)
- `pacstrap` with base + essentials
- Enter chroot automatically — **everything installs here** (using live CD network):
  - Configure locale (pt_BR), timezone (Sao Paulo), keyboard (br-abnt2)
  - Pacman config (Color, ILoveCandy, ParallelDownloads=5, multilib)
  - Create user with zsh
  - Install systemd-boot with `nvidia-drm.modeset=1`
  - Install ALL packages (dev tools, desktop, NVIDIA, Docker)
  - Install `yay` + AUR packages (Brave, Chrome)
  - Configure `rustup default stable`
  - NVIDIA early KMS + pacman hooks
  - Deploy all dotfiles (Sway, Waybar, wofi, nvim, tmux)
  - Enable all services

#### 2. Reboot and use

```bash
umount -R /mnt
reboot
```

Log in on **TTY1** — Sway starts automatically. No post-install wait.

**System tuning applied automatically:**

- Pacman: `Color`, `ILoveCandy`, `ParallelDownloads=5`, multilib
- zram: compressed RAM swap (50% RAM, zstd)
- fstrim.timer: periodic SSD TRIM
- sysctl: `swappiness=10`, `vfs_cache_pressure=50`, `page-cluster=0`
- systemd: `DefaultTimeoutStopSec=5s`
- Boot backup: auto rsync `/boot` → `/boot.bak` on kernel updates
- Electron/Chromium: native Wayland via `--ozone-platform-hint=auto`

---

## Main hotkeys

| Shortcut | Action |
|---|---|
| `Super + Enter` | Terminal (kitty) |
| `Super + Shift + Enter` | Alt terminal (alacritty) |
| `Super + B` | Browser (firefox) |
| `Super + D` | Launcher (wofi) |
| `Super + E` | File manager (yazi) |
| `Super + Q` | Close window |
| `Super + F` | Fullscreen |
| `Super + H/J/K/L` | Focus (vim-style) |
| `Super + Shift + H/J/K/L` | Move window |
| `Super + 1..9` | Workspace |
| `Super + Shift + 1..9` | Move to workspace |
| `Super + R` | Resize mode |
| `Super + P` | Toggle layout |
| `Super + Escape` | Lock screen |
| `Print` | Screenshot (area) |
| `XF86AudioRaiseVolume` | Volume up |
| `XF86AudioLowerVolume` | Volume down |
| `XF86AudioMute` | Toggle mute |
| `XF86MonBrightnessUp` | Brightness up |
| `XF86MonBrightnessDown` | Brightness down |
| `XF86AudioPlay` | Play/pause media |
