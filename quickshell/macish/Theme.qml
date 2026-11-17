pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Palette Segnale. Scuro e chiaro seguono org.gnome.desktop.interface color-scheme.
Singleton {
    id: root

    property bool dark: true

    readonly property var night: ({
        panel: "#111111", card: "#1A1A1A", cardHi: "#222222", cardPressed: "#2A2A2A",
        stroke: "#2A2A2A", sheen: "transparent", rim: "transparent",
        text: "#EDEDE8", dim: "#8A8A85", on: "#EDEDE8", onText: "#0A0A0A", onDim: "#55554F",
        off: "#2E2E2E", signal: "#FF4A1C", onSignal: "#0A0A0A", shadow: Qt.rgba(0, 0, 0, 0.6), danger: "#FF6B5F", alert: "#FF4A1C", alertBorder: "rgba(ff4a1cff)",
        hardShadow: false, wall: "#0A0A0A", wallDot: "#202020", wallClock: "#1A1A1A",
        accentName: "orange", border: "rgba(ffffff99)", icons: "Segnale-Scuro"
    })
    readonly property var day: ({
        panel: "#FBF9F4", card: "#F3EEE4", cardHi: "#E9E4D9", cardPressed: "#DED6C7",
        stroke: Qt.rgba(0.106, 0.102, 0.09, 0.16), sheen: "transparent", rim: "transparent",
        text: "#1B1A17", dim: "#6B675E", on: "#D8D0BA", onText: "#1B1A17", onDim: "#8C866F",
        off: Qt.rgba(0.106, 0.102, 0.09, 0.20), signal: "#CB4B16", onSignal: "#FBF9F4", shadow: Qt.rgba(0.106, 0.102, 0.09, 0.10), danger: "#C0322B", alert: "#CB4B16", alertBorder: "rgba(cb4b16ff)",
        hardShadow: true, wall: "#EFEAE0", wallDot: "#D6CFC0", wallClock: "#E2DCCF",
        accentName: "orange", border: "rgba(1b1a1799)", icons: "Segnale-Chiaro"
    })
    readonly property var p: dark ? night : day

    // In Segnale le superfici sono piene: "glass" resta il nome del colore dei pannelli.
    readonly property color glass: p.panel
    readonly property bool hardShadow: p.hardShadow
    readonly property color wall: p.wall
    readonly property color wallDot: p.wallDot
    readonly property color wallClock: p.wallClock
    readonly property color card: p.card
    readonly property color cardHover: p.cardHi
    readonly property color cardPressed: p.cardPressed
    readonly property color stroke: p.stroke
    readonly property color sheen: p.sheen
    readonly property color rim: p.rim
    readonly property color text: p.text
    readonly property color textDim: p.dim
    readonly property color on: p.on
    readonly property color onText: p.onText
    readonly property color onDim: p.onDim
    readonly property color trackOff: p.off
    readonly property color accent: p.signal
    readonly property color onAccent: p.onSignal
    readonly property color shadow: p.shadow
    readonly property color danger: p.danger
    readonly property color alert: p.alert          // agente che aspetta te: solo per questo

    readonly property string fontFamily: "Geist"
    readonly property string mono: "Geist Mono"
    readonly property string display: "Doto"
    readonly property int fontSize: 13
    readonly property int fontSmall: 11

    readonly property int radiusPanel: 20
    readonly property int radiusCard: 14
    readonly property int animFast: 140
    readonly property int animSlow: 220

    // Applica l'aspetto al resto del sistema: icone, accento GNOME, bordo delle finestre.
    function apply() {
        const cmds = [];
        if (Config.manageIcons)
            cmds.push("gsettings set org.gnome.desktop.interface icon-theme " + p.icons);
        if (Config.manageAccent) {
            cmds.push("gsettings set org.gnome.desktop.interface accent-color " + p.accentName);
            cmds.push("hyprctl keyword general:col.active_border '" + p.border + "'");
        }
        if (cmds.length) Quickshell.execDetached(["sh", "-c", cmds.join(" 2>/dev/null; ") + " 2>/dev/null"]);
    }

    onDarkChanged: apply()

    function readScheme(line) {
        const v = line.indexOf("prefer-light") >= 0 ? false
                : line.indexOf("prefer-dark") >= 0 ? true
                : line.indexOf("default") >= 0 ? false : root.dark;
        root.dark = v;
    }

    Process {
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: SplitParser { onRead: line => root.readScheme(line) }
        onExited: root.apply()
    }

    Process {
        id: monitor
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: SplitParser { onRead: line => root.readScheme(line) }
        onExited: restart.start()
    }
    Timer { id: restart; interval: 3000; onTriggered: monitor.running = true }
}
