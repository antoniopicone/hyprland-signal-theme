pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Schermi: stato e modifiche tramite il backend del plugin Display (displayctl.py),
// che applica a caldo con Hyprland e salva in ~/.config/hypr/monitors.lua.
Singleton {
    id: root

    readonly property string backend: Quickshell.env("HOME") + "/.config/omarchy/plugins/corico.monitor/displayctl.py"
    property var monitors: []
    property string error: ""
    readonly property bool busy: stateProc.running || applyProc.running

    readonly property var scalePresets: ["1", "1.25", "1.33", "1.5", "1.6", "1.75", "2", "2.5", "3", "4"]
    readonly property var orientations: [
        { transform: 0, label: I18n.t("Orizzontale") },
        { transform: 1, label: I18n.t("Verticale 90°") },
        { transform: 2, label: I18n.t("Capovolto") },
        { transform: 3, label: I18n.t("Verticale 270°") }
    ]

    function refresh() {
        if (!stateProc.running) stateProc.running = true;
    }

    // Scala valida per la risoluzione (Hyprland vuole divisori esatti), come nel plugin
    function gcd(a, b) { while (b) { const r = a % b; a = b; b = r; } return a; }
    function norm(s) { const n = parseFloat(String(s || "")); return isFinite(n) ? String(Math.round(n * 100) / 100) : ""; }
    function cleanScale(scale, w, h) {
        const req = Number(scale);
        if (!isFinite(req) || req <= 0 || w <= 0 || h <= 0) return "";
        const div = gcd(Math.round(w * 120), Math.round(h * 120));
        let units = Math.round(req * 120);
        if (units > div) units = div;
        while (div % units !== 0) units++;
        return norm(units / 120);
    }
    function scalesFor(m) {
        const seen = {}, out = [];
        for (const p of scalePresets) {
            const eff = cleanScale(p, m.width, m.height);
            if (eff === "" || seen[eff]) continue;
            seen[eff] = true;
            out.push(eff);
        }
        return out;
    }

    function change(m, patch) {
        if (applyProc.running) return;
        const t = {
            name: m.name, width: m.width, height: m.height, refreshRate: m.refreshRate,
            x: m.x, y: m.y, scale: m.scale, transform: m.transform
        };
        for (const k in patch) t[k] = patch[k];
        error = "";
        applyProc.command = ["/usr/bin/python3", backend, "apply", JSON.stringify({ monitors: [t] })];
        applyProc.running = true;
    }

    function setScale(m, s) { change(m, { scale: Number(s) }); }
    function setTransform(m, t) { change(m, { transform: t }); }

    Component.onCompleted: refresh()
    Connections {
        target: Sys
        function onActiveChanged() { if (Sys.active) root.refresh(); }
    }

    Process {
        id: stateProc
        command: ["/usr/bin/python3", root.backend, "state"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.monitors = (JSON.parse(text).monitors || []).filter(m => m.enabled !== false); }
                catch (e) {}
            }
        }
    }

    Process {
        id: applyProc
        stderr: StdioCollector { id: applyErr }
        onExited: code => {
            if (code !== 0) root.error = applyErr.text.trim().split("\n").pop();
            root.refresh();
        }
    }
}
