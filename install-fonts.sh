#!/usr/bin/env bash
# Scarica Doto, Geist e Geist Mono dal repository di Google Fonts (licenza OFL).
set -uo pipefail
dest="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/brina"
mkdir -p "$dest"

need() { ! fc-list : family | grep -qi "^$1\(,\|$\)"; }

for pair in "doto:Doto" "geist:Geist" "geistmono:Geist Mono"; do
    dir="${pair%%:*}"; name="${pair#*:}"
    if ! need "$name"; then echo "  $name già installato"; continue; fi
    echo "  scarico $name…"
    python3 - "$dir" "$dest" <<'PY' || echo "  ! non riuscito: scarica $name da https://fonts.google.com e mettilo in $dest"
import json, os, sys, urllib.request
fam, dest = sys.argv[1:3]
req = urllib.request.Request(f"https://api.github.com/repos/google/fonts/contents/ofl/{fam}",
                             headers={"User-Agent": "brina-installer"})
items = json.load(urllib.request.urlopen(req, timeout=30))
got = 0
for it in items:
    if it["name"].lower().endswith(".ttf"):
        urllib.request.urlretrieve(it["download_url"], os.path.join(dest, it["name"]))
        print("    " + it["name"]); got += 1
sys.exit(0 if got else 1)
PY
done
fc-cache -f "$dest" >/dev/null 2>&1 || true
