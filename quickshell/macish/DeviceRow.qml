import QtQuick

// Riga di un elenco (rete, dispositivo, uscita audio).
// active = badge colorato, checked = spunta, trailingIcon = icona fissa (es. lucchetto),
// actionIcon/actionText = pulsante che compare al passaggio del mouse.
Item {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool checked: false
    property bool busy: false
    property string trailingIcon: ""
    property string actionIcon: ""
    property string actionText: ""
    property bool warn: false
    signal clicked()
    signal actionClicked()

    implicitHeight: 46

    HoverHandler { id: hover }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: ma.pressed ? Theme.cardPressed : hover.hovered ? Theme.cardHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    IconBadge {
        id: badge
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 30
        implicitHeight: 30
        icon: root.icon
        active: root.active
        SequentialAnimation on opacity {
            running: root.busy
            loops: Animation.Infinite
            alwaysRunToEnd: true          // finisce sempre a opacità piena
            NumberAnimation { to: 0.35; duration: 500 }
            NumberAnimation { to: 1; duration: 500 }
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 10
        anchors.right: tail.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.title
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: root.active ? Font.DemiBold : Font.Normal
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            elide: Text.ElideRight
            color: root.warn ? "#ff6b5f" : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
        }
    }

    Row {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        MButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: hover.hovered && (root.actionIcon !== "" || root.actionText !== "")
            implicitHeight: 26
            icon: root.actionIcon
            text: root.actionText
            onClicked: root.actionClicked()
        }
        SymIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.trailingIcon !== ""
            size: 14
            name: root.trailingIcon
            color: Theme.textDim
        }
        SymIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.checked
            size: 16
            name: "object-select-symbolic"
            color: Theme.accent
        }
    }
}
