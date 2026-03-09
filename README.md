# ArcOS

A clean, minimal Hyprland rice for Arch Linux.

![ArcOS Preview](assets/preview.png)

---

## Stack

| Component | Package |
|---|---|
| Compositor | Hyprland |
| Bar | Waybar |
| Launcher | Rofi |
| Terminal | Kitty |
| Shell | Zsh + Oh My Zsh + Powerlevel10k |
| Notifications | swaync |
| Wallpaper | swww + wallust |
| Lock screen | Hyprlock |
| Display manager | SDDM (silent theme) |
| File manager | Thunar |
| Browser | Brave |
| Theme | adw-gtk3-dark |
| Icons | Papirus-Dark |
| Cursor | Bibata-Modern-Classic |
| Font (UI) | Inter |
| Font (terminal) | FiraCode Nerd Font |
| Font (clock) | Orbitron Bold |

---

## Install

> Requires a fresh Arch Linux install with internet access. Do **not** run as root.

```bash
git clone https://github.com/arclen-dev/arcos.git
cd arcos
chmod +x install.sh
./install.sh
```

The installer will ask 4 questions (GPU type, laptop y/n, username confirm, hibernate swap), then run fully unattended.

**Reboot after install:**
```bash
sudo reboot
```

---

## Keybinds

| Keys | Action |
|---|---|
| `Super + Enter` | Terminal |
| `Super + Space` | App launcher |
| `Super + E` | File manager |
| `Super + W` | Wallpaper picker |
| `Super + Shift + W` | Toggle dark/light mode |
| `Super + L` | Lock screen |
| `Super + X` | Power menu |
| `Super + N` | Notification center |
| `Super + Shift + N` | Toggle Do Not Disturb |
| `Super + V` | Clipboard history |
| `Super + .` | Emoji picker |
| `Super + Q` | Close window |
| `Super + arrows` | Move focus |
| `Super + Ctrl + arrows` | Navigate workspaces |
| `Super + 1–0` | Switch to workspace |
| `Super + Shift + 1–0` | Move window to workspace |
| `Print` | Screenshot (region) |
| `Shift + Print` | Screenshot (window) |
| `Super + Shift + Print` | Screenshot (fullscreen) |

---

## Wallpapers

Wallpapers are copyright-free and included in `assets/wallpapers/`. Change wallpaper anytime with `Super + W`.

Colors across the entire system (bar, terminal, lock screen, launcher) update automatically via wallust when you pick a new wallpaper.

---

## Structure

```
arcos/
├── install.sh          # Main installer
├── packages.txt        # All packages
├── dotfiles/           # ~/.config contents (uploaded directly)
│   ├── hypr/
│   ├── waybar/
│   ├── rofi/
│   ├── kitty/
│   ├── swaync/
│   ├── wallust/
│   ├── swayosd/
│   ├── btop/
│   ├── fresh/
│   ├── gtk-3.0/
│   ├── gtk-4.0/
│   ├── nwg-look/
│   ├── qt5ct/
│   ├── qt6ct/
│   └── kvantum/
├── fonts/              # Inter + FiraCode Nerd Font
├── zsh/
│   ├── .zshrc
│   └── .p10k.zsh
├── system/
│   ├── sddm.conf
│   └── 99-swappiness.conf
└── assets/
    └── wallpapers/
```

---

## Credits

- [Hyprland](https://hyprland.org)
- [wallust](https://codeberg.org/explosion-mental/wallust)
- [swww](https://github.com/LGFae/swww)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- [sddm-silent-theme](https://github.com/MarianArlt/sddm-sugar-dark)
- [Inter font](https://rsms.me/inter)
