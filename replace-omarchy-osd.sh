#!/usr/bin/env bash
# Disattiva i plugin di Omarchy per notifiche e OSD, così li gestisce macish.
#   ./replace-omarchy-osd.sh          disattiva
#   ./replace-omarchy-osd.sh --undo   riattiva quelli di Omarchy
set -uo pipefail
state="${XDG_STATE_HOME:-$HOME/.local/state}/macish"
mkdir -p "$state"
list="$state/disabled-omarchy-plugins"

if [ "${1:-}" = "--undo" ]; then
    [ -f "$list" ] || { echo "Niente da ripristinare."; exit 0; }
    while read -r id; do
        [ -n "$id" ] && omarchy plugin enable "$id" --yes && echo "Riattivato $id"
    done < "$list"
    rm -f "$list"
    pkill -f "qs -c macish" 2>/dev/null
    omarchy-restart-shell
    [ -z "${MACISH_NO_START:-}" ] && (setsid qs -c macish >/dev/null 2>&1 &)
    exit 0
fi

ids=$(omarchy plugin list 2>/dev/null | grep -oE 'omarchy\.[A-Za-z0-9._-]*(notif|osd)[A-Za-z0-9._-]*' | sort -u)
if [ -z "$ids" ]; then
    echo "Non ho trovato i plugin di notifiche/OSD di Omarchy. Controlla con: omarchy plugin list"
    echo "e disattivali a mano con: omarchy plugin disable <id>"
    exit 1
fi

: > "$list"
for id in $ids; do
    if omarchy plugin disable "$id" --yes; then
        echo "$id" >> "$list"
        echo "Disattivato $id"
    fi
done

# Riavvio: Omarchy libera il nome org.freedesktop.Notifications, poi lo prende macish.
pkill -f "qs -c macish" 2>/dev/null
omarchy-restart-shell
sleep 1
(setsid qs -c macish >/dev/null 2>&1 &)

if busctl --user status org.freedesktop.Notifications >/dev/null 2>&1; then
    sleep 1
    notify-send -a "macish" "Notifiche attive" "Da ora notifiche e OSD sono gestiti da macish." 2>/dev/null || true
fi
