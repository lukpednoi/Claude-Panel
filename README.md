# Claude Panel

A standalone Wayland overlay panel for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) extracted from [Anserin](https://github.com/lukpednoi/Anserin).

It wraps a real `claude` CLI session inside an animated layer-shell overlay with a GPU liquid-wave reveal shader, a collapsible corner dome with the waving Clawd mascot, a side Studio rail (live edited files/diffs, slash commands, recent sessions, model/effort switcher, context & plan usage), and optional PipeWire sound effects.

## Features

- **Launch streak & liquid-wave GPU shader** (`claude_box_wipe.frag.qsb`) sweeping in from the bottom-left corner
- **Foldable corner dome** — press your toggle keybind to tuck the active session into the corner while Claude keeps working (Clawd animates while typing or waiting for attention)
- **Real Claude Code terminal** embedded via `qmltermwidget`, paired with a lightweight Python hook/status bridge (`scripts/bridge.py`) without modifying your `~/.claude/settings.json`
- **Studio rail** — live edited files & diffs, pinned/searchable slash commands, recent session resume, model & effort selector, context meter, and task checklist
- **Auto update check** — checks GitHub every 6 hours, notifies once per new version, and updates in place from Settings → Updates or via `claude-panel update`
- **Optional UI sound effects** via `pw-play` (silently skipped if unavailable or muted)

## Compatibility

### Linux Distributions
Works on any Linux distribution (Fedora, Arch, Ubuntu/Debian, NixOS, openSUSE, etc.) with Qt 6, Quickshell, Python 3, and Claude Code CLI.

### Window Managers / Compositors
Claude Panel uses `wlr-layer-shell` (`PanelWindow`) for its floating overlay, click-through input mask, and corner dome:

| Compositor | Support |
| --- | --- |
| **Hyprland** | Full support (including multi-monitor focused screen detection) |
| **Niri** | Full support (including focused output detection) |
| **Sway** | Full support (including focused output detection) |
| **River / Wayfire / Labwc / KDE Plasma Wayland** | Supported (`wlr-layer-shell`) |
| **GNOME Wayland / X11 WMs (i3, bspwm, etc.)** | Not supported (no `wlr-layer-shell`) |

## Requirements

- [`quickshell`](https://quickshell.outfoxxed.me/) (Qt 6 + QtQuick + QtQuick.Shapes + QtQuick.Layouts)
- [`claude`](https://docs.anthropic.com/en/docs/claude-code) (Claude Code CLI, signed in or sign in from the panel)
- `python3` (for session hooks, status line, diffs, and session list)
- `qmltermwidget` (Qt 6 build — required for the embedded terminal; if missing, the animations and panel still open and show install instructions)
- `pipewire-utils` (`pw-play`, optional — for UI sound effects)
- Fonts (optional, falls back gracefully): `JetBrainsMono Nerd Font`, `Google Sans`, `Noto Serif`

### Fedora (Hyprland)

```bash
# 1. Install Quickshell (via COPR) and Qt 6 / Python / PipeWire dependencies
sudo dnf copr enable errornointernet/quickshell
sudo dnf install quickshell qt6-qtdeclarative qt6-qt5compat python3 pipewire-utils

# 2. Install Claude Code CLI
npm install -g @anthropic-ai/claude-code
```

If `qmltermwidget` (Qt 6) is not packaged in your Fedora repos, build the Qt 6 fork from source:

```bash
sudo dnf install cmake gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel git
git clone https://github.com/sddm/qmltermwidget.git /tmp/qmltermwidget
# Or any Qt6-compatible qmltermwidget fork (e.g. https://github.com/Swordfish90/qmltermwidget / qt6 branch)
```

> Make sure the `QMLTermWidget` QML plugin installs into Qt 6's QML import path (typically `/usr/lib64/qt6/qml/QMLTermWidget` on Fedora) or export `QML2_IMPORT_PATH` to include it.

### Arch Linux

```bash
sudo pacman -S quickshell qmltermwidget python pipewire
# Plus Claude Code CLI (AUR or npm)
```

## Install

```bash
git clone https://github.com/lukpednoi/Claude-Panel.git ~/.local/share/claude-panel
chmod +x ~/.local/share/claude-panel/bin/claude-panel \
         ~/.local/share/claude-panel/scripts/launch.sh \
         ~/.local/share/claude-panel/scripts/bridge.py
```

Optional symlink into `~/.local/bin`:

```bash
mkdir -p ~/.local/bin
ln -sf ~/.local/share/claude-panel/bin/claude-panel ~/.local/bin/claude-panel
```

## Usage

```bash
# Toggle open / fold into corner dome (auto-starts daemon on first run)
claude-panel

# Explicit subcommands
claude-panel toggle [--cwd /path/to/project] [--screen DP-1]
claude-panel open [--cwd /path/to/project]
claude-panel close
claude-panel daemon     # Start idle background daemon (good for autostart)
claude-panel restart    # Restart the background daemon
claude-panel stop       # Stop the background daemon
claude-panel status
claude-panel update     # Update Claude Panel from GitHub (alias: -up)
claude-panel version    # Show installed version (alias: -V)
```

Or run directly with Quickshell:

```bash
quickshell -p ~/.local/share/claude-panel/qml/shell.qml
```

## Updating

Claude Panel checks GitHub automatically 1 minute after startup and then every **6 hours** (notifying once per new version via `notify-send`, if installed).

You can update in two ways:
- **Inside the panel:** Open **Settings (`⚙`)** in the left rail → **Updates** → click **Update** (pulls in the background without opening a terminal), then **Restart panel** when ready.
- **From your terminal:**

```bash
claude-panel update
# or
claude-panel -up
```

Your preferences (`~/.local/state/claude-panel/prefs.json`) and audio config (`~/.config/claude-panel/config.json`) are never touched.

## Compositor Keybinds

### Hyprland (`~/.config/hypr/hyprland.conf`)

```ini
# Optional: start idle daemon on login so the first toggle is instant
exec-once = ~/.local/share/claude-panel/bin/claude-panel daemon

# Toggle Claude Panel (open -> fold to corner dome -> unfold)
bind = SUPER, C, exec, ~/.local/share/claude-panel/bin/claude-panel toggle
```

### Niri (`~/.config/niri/config.kdl`)

```kdl
spawn-at-startup "~/.local/share/claude-panel/bin/claude-panel" "daemon"

binds {
    Mod+C { spawn "~/.local/share/claude-panel/bin/claude-panel" "toggle"; }
}
```

### Sway (`~/.config/sway/config`)

```ini
exec ~/.local/share/claude-panel/bin/claude-panel daemon
bindsym $mod+c exec ~/.local/share/claude-panel/bin/claude-panel toggle
```

## Configuration

Optional audio config at `~/.config/claude-panel/config.json`:

```json
{
  "muteSfx": false,
  "sfxVolume": 100
}
```

Environment variables:
- `CLAUDE_PANEL_CWD` — default working directory for new Claude sessions (default: `$HOME`)
- `CLAUDE_PANEL_RUN` — runtime directory for hooks/status files (default: `$XDG_RUNTIME_DIR/claude-panel`)
- `CLAUDE_PANEL_MUTE=1` — mute UI sound effects
- `CLAUDE_PANEL_VOLUME=0.8` — adjust SFX volume (`0.0` to `1.5`)

Pinned commands and pane toggles are saved in `~/.local/state/claude-panel/prefs.json`.

## Recompiling the Shader (Optional)

A precompiled `.qsb` shader is included in `assets/shaders/claude_box_wipe.frag.qsb`. If you edit `assets/shaders/claude_box_wipe.frag`, recompile it with Qt 6's `qsb`:

```bash
qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
  -o assets/shaders/claude_box_wipe.frag.qsb \
  assets/shaders/claude_box_wipe.frag
```

## Credits & License

Extracted from [Anserin](https://github.com/lukpednoi/Anserin) by **lukpednoi**.  
Licensed under the **GNU Affero General Public License v3.0** — see [LICENSE.md](LICENSE.md).
