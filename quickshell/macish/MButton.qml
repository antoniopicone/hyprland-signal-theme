import QtQuick

// Pulsante a capsula. primary = pieno (inchiostro/carta), hot = colore di segnale.
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool hot: false
    property bool alert: false          // rosso: solo per gli agenti che aspettano
    signal clicked()

    readonly property color fg: alert ? "#FFFFFF" : hot ? Theme.onAccent : primary ? Theme.onText : Theme.text

    implicitHeight: 34
    implicitWidth: Math.max(implicitHeight, row.implicitWidth + (text !== "" ? 26 : 0))
    radius: height / 2
    color: alert ? (ma.containsMouse ? Qt.lighter(Theme.alert, 1.08) : Theme.alert)
         : hot ? (ma.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
         : primary ? Theme.on
         : (ma.pressed ? Theme.cardPressed : ma.containsMouse ? Theme.cardHover : Theme.card)
    border.width: (primary || hot || alert) ? 0 : 1
    border.color: Theme.stroke
    scale: ma.pressed ? 0.96 : 1
    opacity: enabled ? 1 : 0.4

    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.animFast } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        SymIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            size: 16
            name: root.icon
            color: root.fg
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            color: root.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: (root.primary || root.hot || root.alert) ? Font.DemiBold : Font.Normal
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
