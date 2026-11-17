import QtQuick

// Slider a puntini: i punti accesi sono il valore, l'ultimo è il segnale.
// label (mono) a sinistra e valore in Doto a destra sono facoltativi.
Item {
    id: root
    property real value: 0          // 0..1
    property string icon: ""        // compatibilità: non usato
    property string label: ""
    property bool showValue: true
    signal moved(real value)

    implicitWidth: 240
    implicitHeight: 24

    readonly property real shown: ma.pressed ? ma.v : Math.max(0, Math.min(1, value))
    readonly property int count: Math.max(6, Math.floor(track.width / 13))
    readonly property int lit: Math.round(shown * count)

    Mono {
        id: lab
        visible: root.label !== ""
        width: visible ? 38 : 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
    }

    Item {
        id: track
        anchors.left: lab.right
        anchors.right: val.left
        anchors.rightMargin: val.visible ? 10 : 0
        height: parent.height

        Row {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: (parent.width - root.count * 6) / Math.max(1, root.count - 1)

            Repeater {
                model: root.count
                Rectangle {
                    required property int index
                    readonly property bool last: index === root.lit - 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: last ? 8 : 6
                    height: width
                    radius: width / 2
                    color: index < root.lit ? (last ? Theme.accent : Theme.text) : Theme.trackOff
                    Behavior on color { ColorAnimation { duration: 90 } }
                }
            }
        }

        MouseArea {
            id: ma
            property real v: 0
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            cursorShape: Qt.PointingHandCursor
            function clamp(x) { return Math.max(0, Math.min(1, x)); }
            function update(mx) { v = clamp(mx / width); root.moved(v); }
            onPressed: mouse => update(mouse.x)
            onPositionChanged: mouse => { if (pressed) update(mouse.x); }
            onWheel: wheel => root.moved(clamp(root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
        }
    }

    Dots {
        id: val
        visible: root.showValue
        width: visible ? 32 : 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        font.pixelSize: 16
        text: Math.round(root.shown * 100)
    }
}
