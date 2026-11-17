import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

Column {
    id: root
    signal back()
    signal advanced()

    readonly property var nodes: Sys.arr(Pipewire.nodes.values)
    readonly property var outputs: nodes.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var inputs: nodes.filter(n => n.audio && !n.isSink && !n.isStream)
    readonly property var apps: nodes.filter(n => n.audio && n.isStream && !n.isSink)   // app che riproducono

    spacing: 10

    PwObjectTracker { objects: root.apps.concat(Sys.source ? [Sys.source] : []) }

    function label(n) { return n.description || n.nickname || n.name; }

    function outputIcon(n) {
        const s = (n.name + " " + label(n)).toLowerCase();
        if (s.indexOf("bluez") >= 0 || s.indexOf("headphone") >= 0 || s.indexOf("cuffie") >= 0) return "audio-headphones-symbolic";
        if (s.indexOf("hdmi") >= 0 || s.indexOf("displayport") >= 0) return "video-display-symbolic";
        return "audio-speakers-symbolic";
    }

    function appName(n) {
        return (n.properties && n.properties["application.name"]) || label(n);
    }
    function appIcon(n) {
        const p = n.properties || {};
        const id = p["application.icon-name"] || p["application.process.binary"] || appName(n);
        const e = DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(id) : DesktopEntries.byId(id);
        return Quickshell.iconPath(e ? e.icon : id, "audio-x-generic");
    }

    SubHeader {
        width: parent.width
        title: "Audio"
        onBack: root.back()
    }

    Card {
        width: parent.width

        MSlider {
            width: parent.width
            icon: Sys.volumeIcon
            value: Sys.volume
            onMoved: v => Sys.setVolume(v)
        }

        SectionLabel { text: "Uscita" }

        Repeater {
            model: ScriptModel { values: root.outputs }
            DeviceRow {
                required property var modelData
                width: parent.width
                icon: root.outputIcon(modelData)
                title: root.label(modelData)
                active: modelData === Sys.sink
                checked: modelData === Sys.sink
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }

    Card {
        width: parent.width
        visible: root.inputs.length > 0

        SectionLabel { text: "Ingresso" }

        Repeater {
            model: ScriptModel { values: root.inputs }
            DeviceRow {
                required property var modelData
                width: parent.width
                icon: "audio-input-microphone-symbolic"
                title: root.label(modelData)
                subtitle: modelData === Sys.source && Sys.micMuted ? "Disattivato" : ""
                active: modelData === Sys.source
                checked: modelData === Sys.source
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
    }

    Card {
        width: parent.width
        visible: root.apps.length > 0

        SectionLabel { text: "Applicazioni" }

        Repeater {
            model: ScriptModel { values: root.apps }
            Item {
                id: app
                required property var modelData
                width: parent.width
                height: 50

                IconImage {
                    id: appIco
                    x: 6
                    y: 4
                    implicitSize: 20
                    source: root.appIcon(app.modelData)
                }
                Text {
                    anchors.left: appIco.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: appIco.verticalCenter
                    text: root.appName(app.modelData)
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
                MSlider {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    implicitHeight: 22
                    value: app.modelData.audio ? app.modelData.audio.volume : 0
                    onMoved: v => { if (app.modelData.audio) app.modelData.audio.volume = v; }
                }
            }
        }
    }

    LinkText {
        x: 6
        text: "Impostazioni audio…"
        onClicked: root.advanced()
    }
}
