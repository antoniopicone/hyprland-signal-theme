pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Stato degli agenti. Ogni agente è un file JSON in ~/.local/state/macish/agenti,
// scritto dal comando `agente` (anche dagli hook di Claude Code).
//   qs -c macish ipc call agenti aggiorna     rilegge subito la cartella
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/macish/agenti"

    property var list: []              // ordinati: in attesa, al lavoro, finiti
    property var seen: ({})            // id -> "since" dello stato già visto
    property var prev: ({})            // id -> stato precedente (per accorgersi dei cambi)
    property real now: Date.now() / 1000
    property string activeAddress: ""

    readonly property var waiting: list.filter(a => a.state === "attende")
    readonly property int working: list.filter(a => a.state === "lavora").length
    readonly property bool anyUnseen: waiting.some(a => !isSeen(a))

    function isSeen(a) { return seen[a.id] === a.since; }
    function markSeen(a) {
        if (isSeen(a)) return;
        const s = Object.assign({}, seen);
        s[a.id] = a.since;
        seen = s;
    }
    function markAllSeen() { for (const a of waiting) markSeen(a); }

    // Il richiamo: dopo agentNudgeAfter secondi di attesa, ogni minuto qualche secondo di lampeggio veloce.
    function nudging(a) {
        const w = now - a.since;
        return w > Config.agentNudgeAfter && (Math.floor(w) % 60) < 4;
    }

    // 0 = niente, 1 = agente in attesa già visto, 2 = in attesa e non ancora visto
    function workspaceState(wsId) {
        let st = 0;
        for (const a of waiting)
            if (a.workspace === wsId) st = Math.max(st, isSeen(a) ? 1 : 2);
        return st;
    }

    function norm(addr) { return (addr || "").toLowerCase().replace(/^0x/, ""); }

    function focus(a) {
        if (a.window) Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:0x" + norm(a.window), I18n.t("Vai al terminale")]);
        else if (a.workspace) Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(a.workspace)]);
        markSeen(a);
    }
    function remove(a) {
        Quickshell.execDetached([Config.agentCli, "chiudi", a.id]);
        later.restart();
    }
    function clearFinished() {
        Quickshell.execDetached([Config.agentCli, "pulisci"]);
        later.restart();
    }

    function elapsed(a) {
        const s = Math.max(0, now - a.since);
        if (s < 60) return I18n.t("ora");
        if (s < 3600) return Math.floor(s / 60) + " min";
        return Math.floor(s / 3600) + " h " + Math.floor((s % 3600) / 60) + " min";
    }
    function shortPath(p) {
        const home = Quickshell.env("HOME");
        return p && home && p.startsWith(home) ? "~" + p.slice(home.length) : (p || "");
    }
    // attività degli ultimi 10 minuti, in 10 colonne
    function spark(a) {
        const b = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        for (const t of (a.activity || [])) {
            const k = 9 - Math.floor((now - t) / 60);
            if (k >= 0 && k < 10) b[k]++;
        }
        return b;
    }

    // ---------- avvisi: notifica critica e bordo rosso ----------
    function onEnterWaiting(a) {
        if (Config.agentNotify) {
            const title = I18n.t("%1 · %2 attende", a.name || I18n.t("Agente"), a.project || "");
            const body = a.message || I18n.t("Chiede la tua conferma");
            Quickshell.execDetached(["sh", "-c",
                'r=$(notify-send -u critical -a Agenti -i dialog-warning -A vai="$4" "$1" "$2"); ' +
                '[ "$r" = vai ] && [ -n "$3" ] && hyprctl dispatch focuswindow "address:0x$3"',
                "sh", title, body, norm(a.window)]);
        }
        border(a, true);
    }
    function onLeaveWaiting(a) { border(a, false); }
    function border(a, on) {
        if (!Config.agentWindowBorder || !a.window) return;
        const addr = "address:0x" + norm(a.window);
        const col = on ? Theme.p.alertBorder : Theme.p.border;
        const ina = on ? Theme.p.alertBorder : "rgba(80808033)";
        Quickshell.execDetached(["sh", "-c",
            'hyprctl dispatch setprop "$1" activebordercolor "$2" >/dev/null 2>&1; hyprctl dispatch setprop "$1" inactivebordercolor "$3" >/dev/null 2>&1',
            "sh", addr, col, ina]);
    }

    // ---------- lettura della cartella ----------
    function refresh() { if (!reader.running) { reader.lines = []; reader.running = true; } }

    function ingest(lines) {
        const out = [];
        for (const l of lines) {
            try {
                const a = JSON.parse(l);
                if (a && a.id) out.push(a);
            } catch (e) {}
        }
        const rank = { attende: 0, errore: 1, lavora: 2, finito: 3 };
        out.sort((x, y) => ((rank[x.state] ?? 4) - (rank[y.state] ?? 4)) || (y.since - x.since));

        const p = {};
        for (const a of out) {
            const before = root.prev[a.id];
            if (a.state === "attende" && before !== "attende") root.onEnterWaiting(a);
            if (a.state !== "attende" && before === "attende") root.onLeaveWaiting(a);
            p[a.id] = a.state;
        }
        for (const id in root.prev)
            if (!(id in p) && root.prev[id] === "attende") root.onLeaveWaiting(root.list.find(x => x.id === id) || { id: id });
        root.prev = p;
        root.list = out;
        // se l'agente in attesa è proprio la finestra che stai guardando, è già visto
        for (const a of root.waiting)
            if (root.norm(a.window) !== "" && root.norm(a.window) === root.activeAddress) root.markSeen(a);
    }

    Process {
        id: reader
        property var lines: []
        command: ["sh", "-c", 'mkdir -p "$1"; for f in "$1"/*.json; do [ -f "$f" ] && { tr -d "\\n" < "$f"; echo; }; done', "sh", root.dir]
        stdout: SplitParser { onRead: l => reader.lines.push(l) }
        onExited: root.ingest(reader.lines)
    }

    Timer {
        interval: root.list.some(a => a.state === "lavora" || a.state === "attende") ? 1500 : 4000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.list.length > 0
        onTriggered: root.now = Date.now() / 1000
    }
    Timer { id: later; interval: 300; onTriggered: root.refresh() }

    // finestra attiva: se è quella di un agente in attesa, l'avviso diventa "visto" (rosso fisso)
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activewindowv2") return;
            root.activeAddress = root.norm(event.data);
            for (const a of root.waiting)
                if (root.norm(a.window) === root.activeAddress) root.markSeen(a);
        }
    }

    IpcHandler {
        target: "agenti"
        function aggiorna(): void { root.refresh(); }
        function toggle(): void { Ui.toggleAgents(); }
    }
}
