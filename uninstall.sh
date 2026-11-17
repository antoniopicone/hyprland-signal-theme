#!/usr/bin/env bash
# Rimuove macish/Segnale e ripristina Omarchy. I backup .bak.* restano dove sono.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/macish"

pkill -f "qs -c macish" 2>/dev/null

# Notifiche e OSD di nuovo a Omarchy (senza riavviare macish)
MACISH_NO_START=1 "$here/replace-omarchy-osd.sh" --undo 2>/dev/null

# Barra di Omarchy
if [ -e "$state/hid-omarchy-bar" ]; then
    rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/bar-off" "$state/hid-omarchy-bar"
fi

# Hyprland
sed -i '/-- macish · /d; /require("macish")/d' "$cfg/hypr/hyprland.lua" 2>/dev/null
sed -i '/# macish/d; /macish.conf/d' "$cfg/hypr/hyprland.conf" 2>/dev/null
rm -f "$cfg/hypr/macish.lua" "$cfg/hypr/macish.conf"

# Agenti
[ -x "$HOME/.local/bin/agente-hooks-claude" ] && "$HOME/.local/bin/agente-hooks-claude" --rimuovi
rm -f "$HOME/.local/bin/agente" "$HOME/.local/bin/agente-hooks-claude"
rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/macish/agenti"

# File
rm -rf "$cfg/quickshell/macish" "$data/icons/Segnale-Scuro" "$data/icons/Segnale-Chiaro"
rm -f "$cfg/omarchy/shell.toml"
gsettings set org.gnome.desktop.interface icon-theme Yaru 2>/dev/null

hyprctl reload >/dev/null 2>&1 || true
command -v omarchy-restart-shell >/dev/null && omarchy-restart-shell
echo "Segnale rimosso. I caratteri restano in ~/.local/share/fonts/brina (cancellali a mano se vuoi)."
