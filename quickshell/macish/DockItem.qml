import QtQuick
import Quickshell
import Quickshell.Widgets

// Voce del binario: clic = porta in primo piano (o avvia), clic centrale = nuova finestra.
Item {
    id: root

    property var entry: null
    property string appId: ""
    property var windows: []
    property string iconName: ""      // pulsanti speciali (launcher)
    property string label: entry ? entry.name : appId
    signal triggered()

    readonly property bool special: iconName !== ""
    readonly property bool running: windows.length > 0
    readonly property bool focused: windows.some(w => w.activated)

    width: Config.railIcon + 16
    height: Config.railIcon + 10

    function launch() { if (entry) entry.execute(); }
    function activate() {
        if (windows.length === 0) { launch(); return; }
        const i = windows.findIndex(w => w.activated);
        windows[(i + 1) % windows.length].activate();
    }

    Rectangle {
        id: tile
        anchors.centerIn: parent
        width: Config.railIcon
        height: Config.railIcon
        radius: 12
        color: root.special ? Theme.on : (ma.containsMouse ? Theme.cardHover : Theme.card)
        border.width: root.special ? 0 : (root.focused ? 1.5 : 1)
        border.color: root.focused ? Qt.alpha(Theme.text, 0.6) : Theme.stroke
        scale: ma.pressed ? 0.92 : ma.containsMouse ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        IconImage {
            visible: !root.special
            anchors.centerIn: parent
            implicitSize: Config.railIcon - 12
            source: Quickshell.iconPath(root.entry ? root.entry.icon : root.appId, "application-x-executable")
        }
        SymIcon {
            visible: root.special
            anchors.centerIn: parent
            size: 18
            name: root.iconName
            color: Theme.onText
        }
    }

    // Spia: segnale = finestra attiva, grigio = app aperta
    Rectangle {
        visible: root.running
        anchors.verticalCenter: parent.verticalCenter
        x: tile.x + tile.width + 4
        width: 5; height: root.focused ? 12 : 5
        radius: 2.5
        color: root.focused ? Qt.alpha(Theme.text, 0.6) : Theme.textDim
        Behavior on height { NumberAnimation { duration: Theme.animFast } }
    }

    // Etichetta a destra
    Glass {
        x: tile.x + tile.width + 16
        anchors.verticalCenter: parent.verticalCenter
        width: tip.implicitWidth + 20
        height: 26
        radius: 13
        shadow: false
        opacity: ma.containsMouse ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Text {
            id: tip
            anchors.centerIn: parent
            text: root.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: ma
        anchors.fill: tile
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (root.special) root.triggered();
            else if (mouse.button === Qt.MiddleButton) root.launch();
            else root.activate();
        }
    }
}
