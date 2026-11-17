import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Column {
    id: root
    signal back()
    signal advanced()

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? Sys.arr(adapter.devices.values) : []

    function named(d) {
        const n = d.name || d.deviceName || "";
        return n !== "" && n.replace(/[-:]/g, "").toUpperCase() !== d.address.replace(/:/g, "");
    }
    function score(d) { return (d.connected ? 4 : 0) + (d.paired ? 2 : 0); }

    readonly property var known: devices.filter(d => d.paired || d.connected)
                                        .sort((a, b) => score(b) - score(a))
    readonly property var others: devices.filter(d => !d.paired && !d.connected && named(d)).slice(0, 8)

    property string pairing: ""       // indirizzo in associazione

    spacing: 10

    Component.onCompleted: if (adapter && adapter.enabled) adapter.discovering = true
    Component.onDestruction: if (adapter) adapter.discovering = false

    function iconFor(d) {
        const s = (d.icon || "bluetooth") + "-symbolic";
        return Quickshell.iconPath(s, true) !== "" ? s : "bluetooth-active-symbolic";
    }

    function subtitleFor(d) {
        if (root.pairing === d.address) return "Associazione…";
        if (d.state === BluetoothDeviceState.Connecting) return "Connessione…";
        if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnessione…";
        if (d.connected) return "Connesso" + (d.batteryAvailable ? " · batteria " + Math.round(d.battery * 100) + "%" : "");
        return "Non connesso";
    }

    function choose(d) {
        if (d.connected) d.disconnect();
        else if (d.paired) d.connect();
        else {
            // bluetoothctl registra il proprio agente: va bene per cuffie, mouse e tastiere senza PIN
            root.pairing = d.address;
            pairProc.command = ["sh", "-c", 'bluetoothctl pair "$1" && bluetoothctl trust "$1" && bluetoothctl connect "$1"', "sh", d.address];
            pairProc.running = true;
        }
    }

    Process {
        id: pairProc
        onExited: root.pairing = ""
    }

    SubHeader {
        width: parent.width
        title: "Bluetooth"
        onBack: root.back()

        MToggle {
            checked: Sys.btOn
            onToggled: c => {
                Sys.setBluetooth(c);
                if (c && root.adapter) root.adapter.discovering = true;
            }
        }
    }

    Card {
        width: parent.width
        visible: Sys.btOn && root.known.length > 0

        SectionLabel { text: "I miei dispositivi" }

        Repeater {
            model: ScriptModel { values: root.known }
            DeviceRow {
                required property var modelData
                width: parent.width
                icon: root.iconFor(modelData)
                title: modelData.name || modelData.deviceName
                subtitle: root.subtitleFor(modelData)
                active: modelData.connected
                busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                actionText: "Dimentica"
                onClicked: root.choose(modelData)
                onActionClicked: modelData.forget()
            }
        }
    }

    Card {
        width: parent.width
        visible: Sys.btOn

        SectionLabel { text: root.adapter && root.adapter.discovering ? "Altri dispositivi · ricerca…" : "Altri dispositivi" }

        Text {
            visible: root.others.length === 0
            leftPadding: 6
            text: "Nessun dispositivo trovato nelle vicinanze"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        Repeater {
            model: ScriptModel { values: root.others }
            DeviceRow {
                required property var modelData
                width: parent.width
                icon: root.iconFor(modelData)
                title: modelData.name || modelData.deviceName
                subtitle: root.pairing === modelData.address ? "Associazione…" : ""
                busy: root.pairing === modelData.address
                onClicked: if (root.pairing === "") root.choose(modelData)
            }
        }
    }

    LinkText {
        x: 6
        text: "Impostazioni Bluetooth…"
        onClicked: root.advanced()
    }
}
