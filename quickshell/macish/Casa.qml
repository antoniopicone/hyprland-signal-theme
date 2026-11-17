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
        case "unconfigured": return I18n.t("Non configurata");
        case "auth": return I18n.t("Token non valido");
        case "offline": return I18n.t("Non raggiungibile");
        }
        if (!ha.online) return I18n.t("Connessione…");
        return ha.lightsOn > 0 ? I18n.t("%1 luci accese su %2", ha.lightsOn, ha.lightCount) : I18n.t("Tutte le luci spente");
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
