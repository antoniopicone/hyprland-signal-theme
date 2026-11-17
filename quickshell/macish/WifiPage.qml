import QtQuick
import Quickshell

Column {
    id: root
    signal back()
    signal advanced()

    property string expanded: ""      // rete con il campo password aperto
    spacing: 10

    Component.onCompleted: Net.scan(true)

    Timer {
        interval: 10000
        repeat: true
        running: Sys.wifiOn
        onTriggered: Net.scan(false)
    }

    Connections {
        target: Net
        function onErrorChanged() {
            if (Net.error === "Password errata") root.expanded = Net.errorSsid;
        }
    }

    function signalIcon(s) {
        return "network-wireless-signal-" + (s > 75 ? "excellent" : s > 50 ? "good" : s > 25 ? "ok" : "weak") + "-symbolic";
    }

    function subtitleFor(n) {
        if (Net.connecting === n.ssid) return "Connessione…";
        if (Net.errorSsid === n.ssid && Net.error !== "") return Net.error;
        if (n.active) return "Connesso · " + n.band;
        if (n.enterprise) return "Rete aziendale: apri le impostazioni di rete";
        if (Net.saved.indexOf(n.ssid) >= 0) return "Salvata";
        return "";
    }

    function choose(n) {
        if (n.active || Net.connecting !== "") return;
        if (n.enterprise) { root.advanced(); return; }
        if (n.secure && Net.saved.indexOf(n.ssid) < 0) {
            root.expanded = root.expanded === n.ssid ? "" : n.ssid;
            return;
        }
        root.expanded = "";
        Net.connect(n, "");
    }

    SubHeader {
        width: parent.width
        title: "Wi-Fi"
        onBack: root.back()

        MToggle {
            checked: Sys.wifiOn
            onToggled: c => { Sys.setWifi(c); if (c) Net.scan(true); }
        }
    }

    Card {
        width: parent.width
        visible: Sys.wifiOn

        Text {
            visible: Net.networks.length === 0
            leftPadding: 6
            text: "Ricerca delle reti…"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        Repeater {
            model: ScriptModel {
                values: Net.networks.slice(0, 10)
                objectProp: "ssid"
            }

            Column {
                id: entry
                required property var modelData
                width: parent.width
                spacing: 4

                SectionLabel {
                    visible: !entry.modelData.active && entry.modelData.ssid === (Net.networks.find(n => !n.active) || {}).ssid
                    text: "Altre reti"
                }

                DeviceRow {
                    width: parent.width
                    icon: root.signalIcon(entry.modelData.signal)
                    title: entry.modelData.ssid
                    subtitle: root.subtitleFor(entry.modelData)
                    warn: Net.errorSsid === entry.modelData.ssid && Net.error !== ""
                    active: entry.modelData.active
                    checked: entry.modelData.active
                    busy: Net.connecting === entry.modelData.ssid
                    trailingIcon: entry.modelData.secure && !entry.modelData.active ? "system-lock-screen-symbolic" : ""
                    actionText: entry.modelData.active ? "Disconnetti"
                              : Net.saved.indexOf(entry.modelData.ssid) >= 0 ? "Dimentica" : ""
                    onClicked: root.choose(entry.modelData)
                    onActionClicked: entry.modelData.active ? Net.disconnect() : Net.forget(entry.modelData.ssid)
                }

                PasswordField {
                    id: pw
                    x: 6
                    width: parent.width - 12
                    visible: root.expanded === entry.modelData.ssid
                    placeholder: "Password per " + entry.modelData.ssid
                    onVisibleChanged: if (visible) grab()
                    onSubmitted: p => { root.expanded = ""; Net.connect(entry.modelData, p); }
                    onCancelled: root.expanded = ""
                }
            }
        }
    }

    Item {
        width: parent.width
        height: 26

        LinkText {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "Impostazioni di rete…"
            onClicked: root.advanced()
        }

        MButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 26
            icon: "view-refresh-symbolic"
            rotation: Net.scanning ? 360 : 0
            Behavior on rotation { RotationAnimation { duration: 800 } }
            onClicked: Net.scan(true)
        }
    }
}
