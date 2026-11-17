pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Tailscale: stato, IP e macchine della rete (tailscale status --json).
Singleton {
    id: root

    property bool known: false          // almeno una risposta ricevuta
    property bool running: false
    property string backend: ""
    property string selfName: ""
    property string selfIp: ""
    property bool fileSharing: false
    property var peers: []              // { name, dns, ip, os, online, canSend }

    readonly property int onlineCount: peers.filter(p => p.online).length
    readonly property string headline: !known ? "…"
        : backend === "NeedsLogin" ? I18n.t("Accesso richiesto")
        : !running ? I18n.t("Spento")
        : selfIp !== "" ? selfIp : I18n.t("Attivo")

    function refresh() {
        if (!proc.running) proc.running = true;
    }

    function toggle() {
        Quickshell.execDetached(["/usr/share/omarchy/bin/omarchy-shell", "omarchy.tailscale", "toggleTailscale"]);
        later.restart();
    }

    function copy(text) {
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "_", text]);
    }

    function send(peer) {
        Quickshell.execDetached(["/usr/share/omarchy/bin/omarchy-tailscale-send", peer.dns !== "" ? peer.dns : peer.name]);
    }

    function ipv4(ips) {
        return (ips || []).filter(i => /^100\./.test(i));
    }

    function clean(dns) {
        const v = String(dns || "");
        return v.endsWith(".") ? v.slice(0, -1) : v;
    }

    function parse(text) {
        let j;
        try { j = JSON.parse(text); } catch (e) { return; }
        backend = j.BackendState || "";
        running = backend === "Running";
        const self = j.Self || {};
        const sip = ipv4(self.TailscaleIPs);
        selfIp = sip.length > 0 ? sip[0] : "";
        selfName = self.HostName || "";
        const cap = "https://tailscale.com/cap/file-sharing";
        fileSharing = !!((self.CapMap && self.CapMap[cap] !== undefined)
                         || (self.Capabilities || []).indexOf(cap) >= 0);
        const owner = String(self.UserID || "");
        const out = [];
        for (const id in (j.Peer || {})) {
            const p = j.Peer[id];
            const ips = ipv4(p.TailscaleIPs);
            const dns = clean(p.DNSName);
            const name = (p.HostName && p.HostName.toLowerCase() !== "localhost") ? p.HostName : (dns.split(".")[0] || "?");
            let target = typeof p.TaildropTarget === "number" && p.TaildropTarget !== 0
                ? p.TaildropTarget === 1
                : (owner !== "" && String(p.UserID || "") === owner);
            out.push({
                name: name, dns: dns, ip: ips.length > 0 ? ips[0] : "",
                os: String(p.OS || ""), online: p.Online === true,
                canSend: fileSharing && running && target && p.Online === true
            });
        }
        out.sort((a, b) => (b.online - a.online) || a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
        peers = out;
        known = true;
    }

    Timer { id: later; interval: 1500; onTriggered: root.refresh() }

    // Aggiorna mentre il pannello è aperto
    Timer {
        interval: 10000
        repeat: true
        running: Sys.active
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: proc
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
}
