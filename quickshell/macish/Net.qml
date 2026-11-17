pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Reti Wi-Fi tramite NetworkManager (nmcli).
Singleton {
    id: root

    property var networks: []        // { ssid, signal, secure, enterprise, active, band }
    property var saved: []           // nomi delle connessioni Wi-Fi salvate
    property bool scanning: list.running
    property string connecting: ""
    property string error: ""
    property string errorSsid: ""

    // nmcli -t separa i campi con ":" ed esegue l'escape dei ":" interni con "\"
    function splitTerse(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) cur += line[++i];
            else if (c === ":") { out.push(cur); cur = ""; }
            else cur += c;
        }
        out.push(cur);
        return out;
    }

    function scan(rescan) {
        if (!list.running) {
            list.lines = [];
            list.command = ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,FREQ,SSID",
                            "device", "wifi", "list", "--rescan", rescan ? "yes" : "auto"];
            list.running = true;
        }
        if (!savedProc.running) {
            savedProc.names = [];
            savedProc.running = true;
        }
    }

    function finish(lines) {
        const by = {};
        for (const l of lines) {
            const f = splitTerse(l);
            if (f.length < 5 || f[4] === "") continue;     // reti nascoste
            const sec = f[2] || "";
            const net = {
                ssid: f[4],
                signal: Number(f[1]) || 0,
                secure: sec !== "" && sec !== "--",
                enterprise: sec.indexOf("802.1X") >= 0,
                active: f[0] === "*",
                band: parseInt(f[3]) >= 5000 ? "5 GHz" : "2,4 GHz"
            };
            const old = by[net.ssid];
            if (!old || net.active || (!old.active && net.signal > old.signal)) by[net.ssid] = net;
        }
        networks = Object.values(by).sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
    }

    function connect(net, password) {
        error = "";
        errorSsid = "";
        connecting = net.ssid;
        const known = saved.indexOf(net.ssid) >= 0;
        let cmd;
        if (known && password)
            // Rete salvata ma con password cambiata: aggiorna il profilo invece di crearne un doppione
            cmd = ["sh", "-c", 'nmcli connection modify id "$1" wifi-sec.psk "$2" && nmcli connection up id "$1"', "sh", net.ssid, password];
        else if (known)
            cmd = ["nmcli", "connection", "up", "id", net.ssid];
        else {
            cmd = ["nmcli", "device", "wifi", "connect", net.ssid];
            if (password) cmd.push("password", password);
        }
        conn.isNew = !known;
        conn.err = "";
        conn.command = cmd;
        conn.running = true;
    }

    function disconnect() {
        if (Sys.wifiName !== "") Quickshell.execDetached(["nmcli", "connection", "down", "id", Sys.wifiName]);
        later.restart();
    }

    function forget(ssid) {
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", ssid]);
        later.restart();
    }

    Process {
        id: list
        property var lines: []
        stdout: SplitParser { onRead: l => list.lines.push(l) }
        onExited: root.finish(list.lines)
    }

    Process {
        id: savedProc
        property var names: []
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: SplitParser {
            onRead: l => {
                const f = root.splitTerse(l);
                if (f[1] === "802-11-wireless") savedProc.names.push(f[0]);
            }
        }
        onExited: root.saved = savedProc.names
    }

    Process {
        id: conn
        property bool isNew: false
        property string err: ""
        stderr: SplitParser { onRead: l => conn.err += l + "\n" }
        onExited: code => {
            const ssid = root.connecting;
            root.connecting = "";
            if (code !== 0) {
                root.errorSsid = ssid;
                root.error = /secret|password|psk|802-11-wireless-security/i.test(conn.err)
                    ? I18n.t("Password errata") : I18n.t("Connessione non riuscita");
                // nmcli lascia un profilo con la password sbagliata: lo togliamo
                if (conn.isNew) Quickshell.execDetached(["nmcli", "connection", "delete", "id", ssid]);
            }
            later.restart();
        }
    }

    Timer {
        id: later
        interval: 800
        onTriggered: { root.scan(false); Sys.poke(); }
    }
}
