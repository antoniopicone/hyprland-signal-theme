import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// OSD Segnale: capsula in basso con dieci puntini e valore in Doto.
// Il volume si aggiorna da solo (PipeWire); la luminosità la segnalano i tasti:
//   qs -c macish ipc call osd brightness
Scope {
    id: root

    property string icon: ""
    property string label: ""
    property real value: 0
    property bool showBar: true

    property bool ready: false      // niente OSD durante l'avvio
    property bool mapped: false
    property bool reveal: false

    function show(icon, label, value, showBar) {
        if (!ready || Sys.active) return;        // con il Centro di Controllo aperto non serve
        root.icon = icon;
        root.label = label;
        root.value = Math.max(0, Math.min(1, value));
        root.showBar = showBar;
        unmapTimer.stop();
        mapped = true;
        Qt.callLater(() => root.reveal = true);
        hideTimer.restart();
    }

    function showVolume() {
        show(Sys.volumeIcon, Sys.muted ? I18n.t("Audio disattivato") : "Volume", Sys.muted ? 0 : Sys.volume, !Sys.muted);
    }
    function showMic() {
        show(Sys.micMuted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic",
             Sys.micMuted ? I18n.t("Microfono disattivato") : I18n.t("Microfono attivo"), 0, false);
    }
    function showBrightness() {
        show("display-brightness-symbolic", I18n.t("Luminosità"), Sys.brightness, true);
    }

    Timer { interval: 2500; running: true; onTriggered: root.ready = true }
    Timer { id: hideTimer; interval: Config.osdTimeout; onTriggered: { root.reveal = false; unmapTimer.restart(); } }
    Timer { id: unmapTimer; interval: Theme.animSlow; onTriggered: root.mapped = false }

    Connections {
        target: Sys.sink ? Sys.sink.audio : null
        function onVolumeChanged() { root.showVolume(); }
        function onMutedChanged() { root.showVolume(); }
    }
    Connections {
        target: Sys.source ? Sys.source.audio : null
        function onMutedChanged() { root.showMic(); }
    }

    Process {
        id: readBrightness
        command: ["brightnessctl", "-m"]
        stdout: SplitParser {
            onRead: line => {
                const v = Number((line.split(",")[3] || "").replace("%", ""));
                if (!isNaN(v)) {
                    Sys.brightness = v / 100;
                    root.showBrightness();
                }
            }
        }
    }

    IpcHandler {
        target: "osd"
        function brightness(): void { readBrightness.running = true; }
        function volume(): void { root.showVolume(); }
        function mic(): void { root.showMic(); }
    }

    PanelWindow {
        visible: root.mapped
        screen: Sys.focusedScreen()
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 420
        implicitHeight: 100
        anchors { bottom: true }
        margins { bottom: 36 }

        WlrLayershell.namespace: "macish-osd"
        WlrLayershell.layer: WlrLayer.Overlay

        mask: Region {}      // non intercetta clic

        Glass {
            id: pill
            anchors.centerIn: parent
            width: row.implicitWidth + 40
            height: 50
            radius: height / 2

            opacity: root.reveal ? 1 : 0
            scale: root.reveal ? 1 : 0.9
            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack } }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 14

                SymIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 18
                    name: root.icon
                }

                // dieci puntini: il valore
                Row {
                    visible: root.showBar
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Repeater {
                        model: 10
                        Rectangle {
                            required property int index
                            readonly property int lit: Math.round(root.value * 10)
                            anchors.verticalCenter: parent.verticalCenter
                            width: index === lit - 1 ? 8 : 6
                            height: width
                            radius: width / 2
                            color: index < lit ? (index === lit - 1 ? Theme.accent : Theme.text) : Theme.trackOff
                        }
                    }
                }

                Dots {
                    visible: root.showBar
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: 18
                    text: Math.round(root.value * 100)
                }

                Mono {
                    visible: !root.showBar
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.label
                    color: Theme.text
                    font.pixelSize: 12
                }
            }
        }
    }
}
