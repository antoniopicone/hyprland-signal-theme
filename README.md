# Signal

[Italiano](README.it.md) · **English**

![Signal: top bar with the working-agent dot breathing, launcher, quick panel and dot-matrix wallpaper clock](docs/screenshot.png)

A desktop theme for [Omarchy](https://omarchy.org) on Hyprland that treats the screen as a
measuring instrument: solid surfaces, values and time in a dot-matrix typeface, monospaced
labels and a single signal colour for whatever is active or needs you.

Two variants: **dark** (black, paper white, orange-red signal) and **light** (Paper palette,
ink-blue signal, crisp shadows). The variant follows the system appearance
(`org.gnome.desktop.interface color-scheme`), and icons, GNOME accent colour, window border
and wallpaper change with it. The interface is available in **English and Italian**.

Signal runs as a separate Quickshell instance (`qs -c macish`) alongside `omarchy-shell`.
The directory and config names inside the project still use the working name `macish`
(and `Segnale-*` for the icon themes).

## Installation

    git clone https://github.com/antoniopicone/hyprland-signal-theme.git && cd hyprland-signal-theme
    ./install.sh                    # or: ./install.sh --keep-omarchy-bar

The installer backs up everything it replaces (`*.bak.<timestamp>`).

Requirements: Omarchy (the installer edits its shell config and replaces its notification and
OSD plugins), Hyprland, `quickshell` 0.2+, Qt 6.9+, `gsettings`. Optional: `nmcli`, `wpctl`,
`brightnessctl`, `bluetoothctl`, `hyprsunset`, `notify-send`; without them the matching
controls do nothing. Fonts (Doto, Geist, Geist Mono) are downloaded from the Google Fonts
repository.

## What it installs

| Where | What |
|---|---|
| `~/.config/quickshell/macish` | Bar, app rail (dock), launcher, quick panel with Wi-Fi / Bluetooth / Audio / Display / Tailscale / Home pages, notifications, OSD, dot-matrix wallpaper with the time |
| `~/.config/hypr/macish.lua` or `macish.conf` | Rounded corners, shadows, window border, no blur, shortcuts, media keys (Lua if you use `hyprland.lua`, hyprlang otherwise) |
| `~/.local/share/icons/Segnale-Scuro`, `Segnale-Chiaro` | Icon themes with tinted folders, 80+ file types, devices, trash (the rest comes from Yaru) |
| `~/.local/bin/agente`, `agente-hooks-claude` | Agent status for the panel; hook installer for Claude Code |
| `~/.local/share/fonts/brina` | Doto, Geist, Geist Mono |
| `~/.config/omarchy/shell.toml` | System-wide tweaks to Omarchy's own menus and panels (bar size, font size, spacing, borderless controls) |

The installer also disables Omarchy's notification and OSD plugins and hides its bar
(`--keep-omarchy-bar` leaves the bar alone).

## Language

The interface follows `LANG` (`it_*` → Italian, anything else → English). To force one,
set `readonly property string language: "en"` (or `"it"`) in `Config.qml` (default: `"auto"`).
Translations live in `I18n.qml`: the Italian strings in the code are the keys, and
`I18n.t("text")` returns the English version. Adding a language means adding another table.
The `agente` command follows `LANG` too (or `MACISH_LANG`); its command names stay in Italian.

## Shortcuts

| Keys | Action |
|---|---|
| Super + Space | Launcher |
| Super + Ctrl + C | Quick panel (also click the status and time in the bar) |
| Super + Ctrl + A | Agents (also click `AG` in the bar) |
| Super + Ctrl + M | Notifications (also click the dot at the top left) |
| Super + Ctrl + N | Dark / light theme |
| Volume, brightness, microphone keys | Signal OSD |

## Notifications

The dot at the top left, before the workspaces, is the notification indicator:

- **filled, text colour**: nothing to read;
- **filled, signal colour**: unread notifications;
- **outline only**: Do Not Disturb is on (signal colour if something arrived in the meantime).

A click opens the drawer on the left: notifications grouped by app (three visible, the rest
behind "N more"), Clear per group or all, and Do Not Disturb at the top. Opening it turns the
dot back to the text colour. Banners appear at the top left, under the bar; with Do Not
Disturb on, only critical ones get through.

Colour rule: **solid signal colour** = there is something to read, **blinking** = someone (an
agent) is waiting for you. The signal colour is orange-red in the dark variant and blue in the
light one.

The drawer, the quick panel, the Agents menu and the app rail share the launcher's curvature
(20 px corners).

## Agents

The bar shows `AG` with one dot per agent: **breathing white** = working, **blinking signal
colour** = waiting for you, **grey** = done. The number of the workspace where the agent lives
gets the same dot. The panel (click `AG`, or Super + Ctrl + A) lists the agents with folder,
workspace, elapsed time, last action and activity over the last 10 minutes.

When an agent asks for something:
- the indicator blinks slowly (once a second) until you open the panel or go to its window,
  then stays solid until you answer;
- its window border takes the signal colour;
- if it has been waiting for more than 5 minutes, the indicator blinks fast for a few seconds
  every minute;
- optionally, a critical notification with "Go to terminal" (it gets through Do Not Disturb).
  This is off by default: set `agentNotify: true` in `Config.qml`.

**Claude Code** is hooked up automatically: the installer adds the hooks to
`~/.claude/settings.json` (with a backup; skip it with `--no-claude-hooks`). To remove them:
`agente-hooks-claude --rimuovi`.

**Other agents**: launch them with `agente avvia codex -- codex` (or any command). A script
can signal a wait with `agente attende ID "message"`. Everything else: `agente --help`.

Permission requests are approved in the agent's terminal: the panel alerts you and takes you
there, but does not approve remotely.

## Home panel

The Home tile in the quick panel talks to Home Assistant, reading the address and token from
`~/.config/omarchy-home-control/config.json` (the same file as Omarchy's Home Control plugin).
Without it the tile says "Not configured".

## Customising

`~/.config/quickshell/macish/Config.qml`:
- pinned apps and the parts to show (`showBar`, `showWallpaper`, `wallpaperClock`), icon and
  accent handling (`manageIcons`, `manageAccent`), `language`;
- agents: `agentBlink` (false = solid, no blinking), `agentNudgeAfter`, `agentNotify`,
  `agentWindowBorder`, `newAgentCommand`;
- commands: the Wi-Fi, Bluetooth, Audio, Display, Tailscale and Home pages open their
  detailed panels through `omarchy-shell shell summon …`. Some of those plugin ids are the
  author's own (`antonio.menu`, `corico.monitor`, `antoniopicone.home-control`): change them
  to the plugins you use.

Colours are in `Theme.qml`.

## Uninstalling

    ./uninstall.sh

It restores Omarchy's bar, notifications and OSD and removes Signal's files; the `.bak.*`
backups and the fonts stay where they are.

## Troubleshooting

- `qs -c macish log` shows QML errors (a `QtWebSockets` warning comes from the Home tile's Home Assistant client).
- Omarchy's bar is still visible: `touch ~/.local/state/omarchy/toggles/bar-off && omarchy-restart-shell`.
- Duplicate or missing notifications: `./replace-omarchy-osd.sh` and check `omarchy plugin list`.
- The agent indicator doesn't light up: check `agente lista` and that `~/.claude/settings.json`
  contains the hooks.
- The active window border doesn't change colour: with the Lua configuration `hyprctl keyword`
  may not be supported.
