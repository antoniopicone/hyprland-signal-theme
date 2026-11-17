import QtQuick

// Interruttore Segnale: capsula, il pallino è la spia (segnale quando acceso).
Item {
    id: root
    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 48
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.on : Theme.card
        border.width: root.checked ? 0 : 1
        border.color: Theme.stroke
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Rectangle {
        width: ma.pressed ? 14 : 10
        height: 10
        radius: 5
        y: (root.height - height) / 2
        x: root.checked ? root.width - width - 8 : 8
        color: root.checked ? Theme.accent : Theme.trackOff
        Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Theme.animFast } }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
