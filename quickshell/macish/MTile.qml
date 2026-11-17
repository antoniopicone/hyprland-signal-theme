import QtQuick

// Modulo del pannello: acceso = pieno e invertito, come in Segnale.
// Clic = attiva/disattiva; la freccia (se presente) apre il sottopannello.
Rectangle {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool expandable: false
    signal clicked()
    signal opened()

    implicitHeight: 78
    radius: Theme.radiusCard
    color: active ? Theme.on : (ma.pressed ? Theme.cardPressed : ma.containsMouse ? Theme.cardHover : Theme.card)
    border.width: active ? 0 : 1
    border.color: Theme.stroke
    scale: ma.pressed ? 0.97 : 1

    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.animFast } }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    SymIcon {
        x: 12
        y: 12
        size: 18
        name: root.icon
        color: root.active ? Theme.onText : Theme.text
    }

    Rectangle {
        visible: root.expandable
        x: parent.width - width - 8
        y: 8
        width: 26
        height: 26
        radius: 13
        color: openMa.containsMouse ? (root.active ? Qt.rgba(0.5, 0.5, 0.5, 0.25) : Theme.cardHover) : "transparent"
        SymIcon {
            anchors.centerIn: parent
            size: 13
            name: "go-next-symbolic"
            color: root.active ? Theme.onDim : Theme.textDim
        }
        MouseArea {
            id: openMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.opened()
        }
    }

    Column {
        x: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: parent.width - 24
        spacing: 1

        Mono {
            width: parent.width
            text: root.title
            elide: Text.ElideRight
            color: root.active ? Theme.onDim : Theme.textDim
        }
        Text {
            width: parent.width
            text: root.subtitle
            elide: Text.ElideRight
            color: root.active ? Theme.onText : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }
}
