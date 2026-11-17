#!/usr/bin/env bash
# Installa macish con il tema Segnale. Fa un backup di tutto ciò che sostituisce.
#   ./install.sh                     installazione completa
#   ./install.sh --keep-omarchy-bar  lascia anche la barra di Omarchy
#   ./install.sh --no-claude-hooks   non collega Claude Code al pannello Agenti
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/macish"
keep_bar=0; claude_hooks=1
for arg in "$@"; do
    [ "$arg" = "--keep-omarchy-bar" ] && keep_bar=1
    [ "$arg" = "--no-claude-hooks" ] && claude_hooks=0
done
mkdir -p "$state"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
backup() { [ -e "$1" ] && cp -r "$1" "$1.bak.$(date +%s)" || true; }

say "1/7 Controllo dei requisiti"
missing=0
for c in qs hyprctl gsettings; do command -v "$c" >/dev/null || { echo "  ! manca $c (necessario)"; missing=1; }; done
for c in nmcli wpctl brightnessctl bluetoothctl hyprsunset notify-send; do command -v "$c" >/dev/null || echo "  · manca $c (facoltativo: alcune funzioni non andranno)"; done
[ $missing = 1 ] && { echo "Installa i requisiti e riprova."; exit 1; }

say "2/7 Shell Quickshell"
backup "$cfg/quickshell/macish"
mkdir -p "$cfg/quickshell"
rm -rf "$cfg/quickshell/macish"
cp -r "$here/quickshell/macish" "$cfg/quickshell/macish"
echo "  ~/.config/quickshell/macish"

say "3/7 Caratteri (Doto, Geist, Geist Mono)"
"$here/install-fonts.sh"

say "4/7 Icone Segnale-Scuro e Segnale-Chiaro"
mkdir -p "$data/icons"
for t in Segnale-Scuro Segnale-Chiaro; do
    rm -rf "$data/icons/$t"
    cp -r "$here/icons/$t" "$data/icons/$t"
    command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$data/icons/$t" >/dev/null 2>&1
done
echo "  ~/.local/share/icons/Segnale-*"

say "Agenti"
mkdir -p "$HOME/.local/bin"
cp "$here/bin/agente" "$here/bin/agente-hooks-claude" "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/agente" "$HOME/.local/bin/agente-hooks-claude"
echo "  ~/.local/bin/agente"
if [ $claude_hooks = 1 ]; then
    if command -v claude >/dev/null || [ -d "$HOME/.claude" ]; then
        "$HOME/.local/bin/agente-hooks-claude"
    else
        echo "  Claude Code non trovato: quando lo installi, lancia  agente-hooks-claude"
    fi
fi

say "5/7 Hyprland"
mkdir -p "$cfg/hypr"
if [ -f "$cfg/hypr/hyprland.lua" ]; then
    backup "$cfg/hypr/macish.lua"
    cp "$here/hypr/macish.lua" "$cfg/hypr/macish.lua"
    grep -q 'require("macish")' "$cfg/hypr/hyprland.lua" || printf '\n-- macish · Segnale\nrequire("macish")\n' >> "$cfg/hypr/hyprland.lua"
    echo "  configurazione Lua: ~/.config/hypr/macish.lua"
else
    backup "$cfg/hypr/macish.conf"
    cp "$here/hypr/macish.conf" "$cfg/hypr/macish.conf"
    grep -q "macish.conf" "$cfg/hypr/hyprland.conf" 2>/dev/null || printf '\n# macish · Segnale\nsource = ~/.config/hypr/macish.conf\n' >> "$cfg/hypr/hyprland.conf"
    echo "  configurazione hyprlang: ~/.config/hypr/macish.conf"
fi

say "6/7 Omarchy"
mkdir -p "$cfg/omarchy"
backup "$cfg/omarchy/shell.toml"
cp "$here/omarchy/shell.toml" "$cfg/omarchy/shell.toml"
if [ $keep_bar = 0 ]; then
    toggles="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles"
    if [ ! -e "$toggles/bar-off" ]; then
        mkdir -p "$toggles" && touch "$toggles/bar-off" && touch "$state/hid-omarchy-bar"
        echo "  barra di Omarchy nascosta (al suo posto c'è quella di Segnale)"
    fi
fi

say "7/7 Avvio"
gsettings set org.gnome.desktop.interface icon-theme \
    "$(gsettings get org.gnome.desktop.interface color-scheme | grep -q light && echo Segnale-Chiaro || echo Segnale-Scuro)" 2>/dev/null
hyprctl reload >/dev/null 2>&1 || true
# Notifiche e OSD passano a macish; lo script riavvia la shell di Omarchy e avvia macish.
"$here/replace-omarchy-osd.sh" || {
    command -v omarchy-restart-shell >/dev/null && omarchy-restart-shell
    pkill -f "qs -c macish" 2>/dev/null
    (setsid qs -c macish >/dev/null 2>&1 &)
}

cat <<'MSG'

Segnale è installato.
  Super + Spazio        launcher
  Super + Ctrl + C      pannello rapido (o clic sull'ora nella barra)
  Super + Ctrl + A      agenti (o clic su AG nella barra)
  Super + Ctrl + M      notifiche (o clic sul pallino in alto a sinistra)
  Super + Ctrl + N      tema scuro / chiaro
  notify-send Ciao "Notifica di prova"
  Problemi?  qs -c macish log      ·  Disinstallare:  ./uninstall.sh
MSG
