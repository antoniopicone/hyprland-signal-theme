pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Hyprland
import Quickshell.Bluetooth
import QtQuick

// Stato di sistema e azioni usate dal Centro di Controllo.
Singleton {
    id: root

    property bool active: false          // true mentre il pannello è aperto: aggiorna più spesso

    property bool wifiOn: false
    property bool ethOn: false           // cavo ethernet connesso
    property string ethName: ""
    property string ethIp: ""
    property int ethSpeed: 0             // Mbit/s, 0 se sconosciuta
    readonly property string ethSpeedText: ethSpeed <= 0 ? ""
        : ethSpeed >= 1000 ? (ethSpeed / 1000) + " Gbit/s" : ethSpeed + " Mbit/s"
    property string wifiName: ""
    property int wifiSignal: 0          // 0..100
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    readonly property var btConnected: btAdapter ? arr(btAdapter.devices.values).filter(d => d.connected) : []

    function arr(list) {
        const out = [];
        if (!list) return out;
        for (let i = 0; i < list.length; i++) out.push(list[i]);
        return out;
    }

    function poke() { refresh.restart(); }
    property bool nightOn: false
    property bool darkScheme: true
    property real brightness: 0.5        // 0..1

    // --- Audio (PipeWire) ---
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property string volumeIcon: muted || volume <= 0.001 ? "audio-volume-muted-symbolic"
        : volume < 0.34 ? "audio-volume-low-symbolic"
        : volume < 0.67 ? "audio-volume-medium-symbolic"
        : "audio-volume-high-symbolic"

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false

    PwObjectTracker { objects: [root.sink, root.source] }

    function setMicMuted(m) {
        if (source && source.audio) source.audio.muted = m;
    }

    // Lo schermo su cui si trova il focus (per pannelli, OSD e notifiche)
    function focusedScreen() {
        const m = Hyprland.focusedMonitor;
        const screens = Quickshell.screens;
        if (m) {
            for (let i = 0; i < screens.length; i++)
                if (screens[i].name === m.name) return screens[i];
        }
        return screens[0];
    }

    function setVolume(v) {
        if (!sink || !sink.audio) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    // --- Batteria (UPower) ---
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery ? battery.isLaptopBattery : false
    readonly property real batteryLevel: battery ? battery.percentage : 0     // 0..1
    readonly property bool charging: !UPower.onBattery
    // Autonomia (o tempo alla carica completa) in secondi, 0 se sconosciuta
    readonly property real batterySeconds: battery ? (charging ? battery.timeToFull : battery.timeToEmpty) : 0
    readonly property real batteryWatts: battery ? Math.abs(battery.changeRate) : 0
    function formatDuration(sec) {
        if (!(sec > 0)) return "--";
        const m = Math.round(sec / 60);
        const h = Math.floor(m / 60);
        return h > 0 ? h + "h" + String(m % 60).padStart(2, "0") + "m" : m + "m";
    }
    readonly property string batteryIcon: "battery-level-" + (Math.round(batteryLevel * 10) * 10)
        + (charging ? "-charging" : "") + "-symbolic"

    // --- Azioni ---
    function sh(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
        refresh.restart();
    }

    function setWifi(on) { wifiOn = on; sh("nmcli radio wifi " + (on ? "on" : "off")); }
    function setBluetooth(on) {
        if (btAdapter) btAdapter.enabled = on;
        else sh("bluetoothctl power " + (on ? "on" : "off"));
    }

    function setNight(on) {
        nightOn = on;
        // Come il servizio di Omarchy: per spegnere non basta "identity", perché hyprsunset
        // continuerebbe a riportare 4000 K e il pannello lo leggerebbe come ancora acceso.
        sh("pgrep -x hyprsunset >/dev/null || { setsid hyprsunset >/dev/null 2>&1 & sleep 1; }; "
            + "hyprctl hyprsunset temperature " + (on ? Config.nightTemperature : Config.dayTemperature)
            + (on ? "" : " && hyprctl hyprsunset identity"));
    }

    function setDark(on) {
        darkScheme = on;
        let cmd = "gsettings set org.gnome.desktop.interface color-scheme " + (on ? "prefer-dark" : "prefer-light");
        // Il tema Omarchy decide i colori delle app (zapfast, terminale...): lo applico in coppia.
        const theme = on ? Config.darkTheme : Config.lightTheme;
        if (theme !== "") cmd += "; omarchy-theme-set '" + theme + "'";
        sh(cmd);
    }

    function setBrightness(v) {
        brightness = Math.max(0.01, Math.min(1, v));
        if (!brightTimer.running) brightTimer.start();   // al massimo ~16 scritture al secondo
    }

    Timer {
        id: brightTimer
        interval: 60
        onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(root.brightness * 100) + "%"])
    }

    // --- Lettura dello stato ---
    function parseLine(line) {
        const i = line.indexOf("=");
        if (i < 0) return;
        const k = line.slice(0, i), v = line.slice(i + 1).trim();
        if (k === "wifi") wifiOn = v === "enabled";
        else if (k === "eth") { ethName = v; ethOn = v !== ""; }
        else if (k === "ethip") ethIp = v;
        else if (k === "ethspeed") ethSpeed = Number(v) > 0 ? Number(v) : 0;
        else if (k === "ssid") wifiName = v;
        else if (k === "sig") wifiSignal = Number(v) || 0;
        else if (k === "bright") { if (v !== "" && !brightTimer.running) brightness = Number(v) / 100; }
        else if (k === "night") nightOn = v !== "" && Number(v) < 6000;
        else if (k === "scheme") darkScheme = v.indexOf("light") < 0;
    }

    Process {
        id: poll
        command: ["sh", "-c", "export LC_ALL=C\n"
            + "echo \"wifi=$(nmcli -t -f WIFI radio 2>/dev/null)\"\n"
            + "eth=$(nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null | awk -F: '$2==\"ethernet\" && $3==\"connected\" {print $1; exit}')\n"
            + "echo \"eth=$eth\"\n"
            + "echo \"ethip=$([ -n \"$eth\" ] && nmcli -g IP4.ADDRESS device show \"$eth\" 2>/dev/null | head -n1 | cut -d/ -f1)\"\n"
            + "echo \"ethspeed=$([ -n \"$eth\" ] && cat /sys/class/net/$eth/speed 2>/dev/null)\"\n"
            + "echo \"sig=$(nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null | sed -n 's/^\\*://p' | head -n1)\"\n"
            + "echo \"ssid=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | sed -n 's/:802-11-wireless$//p' | head -n1)\"\n"
            + "echo \"bright=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d %)\"\n"
            + "echo \"night=$(hyprctl hyprsunset temperature 2>/dev/null | grep -Eo '^[0-9]+' | head -n1)\"\n"
            + "echo \"scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)\"\n"]
        stdout: SplitParser { onRead: line => root.parseLine(line) }
    }

    Timer {
        interval: root.active ? 4000 : 20000      // la barra mostra il Wi-Fi anche a pannello chiuso
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    Timer {
        id: refresh
        interval: 1500
        onTriggered: poll.running = true
    }

    Component.onCompleted: poll.running = true
}
