# Desktop Plan (Sway + Waybar)

## Components

- WM/Compositor: `sway` (i3-compatible, Wayland native)
- Bar: `waybar`
- Launcher: `wofi`
- Notifications: `mako`
- Wallpaper: `swaybg`
- Screenshot: `grim` + `slurp`
- Clipboard: `wl-clipboard`
- Monitor profiles: `kanshi`
- Idle/lock: `swayidle` + `swaylock`

## Proposed hotkeys (MVP)

- `SUPER + Enter` → open terminal (`kitty`)
- `SUPER + Shift + Enter` → open alt terminal (`alacritty`)
- `SUPER + B` → open browser (`firefox`)
- `SUPER + D` → launcher (`wofi --show drun`)
- `SUPER + Q` → close active window
- `SUPER + F` → fullscreen
- `SUPER + V` → floating toggle
- `SUPER + H/J/K/L` → focus left/down/up/right
- `SUPER + Shift + H/J/K/L` → move window
- `SUPER + 1..9` → workspace 1..9
- `SUPER + Shift + 1..9` → move window to workspace
- `SUPER + P` → toggle layout
- `Print` → screenshot area

## Screen management

- Start with `kanshi` for profiles:
  - docked profile (external monitor as primary)
  - mobile profile (laptop screen only)

## Next phase

- Add Waybar theme
- Add autostart script
- Add wallpaper manager
- Configure `swayidle` (auto lock + suspend)
- Configure `swaylock` (lock screen)
