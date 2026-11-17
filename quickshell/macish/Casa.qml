pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Casa: lo stesso client Home Assistant del plugin Home Control (HaClient),
// con indirizzo e token letti da ~/.config/omarchy-home-control/config.json.
Singleton {
    id: root

    property alias client: ha
    readonly property string status: ha.status

    readonly property string headline: {
        switch (ha.status) {
        case "unconfigured": return "Non configurata";
        case "auth": return "Token non valido";
        case "offline": return "Non raggiungibile";
        }
        if (!ha.online) return "Connessione…";
        return ha.lightsOn > 0 ? ha.lightsOn + " luci accese su " + ha.lightCount : "Tutte le luci spente";
    }

    HaClient {
        id: ha
        pollIntervalSec: 5
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/omarchy-home-control/config.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.apply(text())
        onLoadFailed: root.apply("")
        onFileChanged: reload()
    }

    function apply(t) {
        let c = {};
        try { c = JSON.parse(t) || {}; } catch (e) {}
        ha.url = String(c.url || "");
        ha.token = String(c.token || "");
    }
}
