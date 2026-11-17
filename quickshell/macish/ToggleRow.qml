import QtQuick

// Riga "icona + titolo/sottotitolo + interruttore".
// Con expandable: true, il clic sulla parte sinistra apre il sottopannello.
Item {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool expandable: false
    signal toggled(bool checked)
    signal opened()

    implicitHeight: 48

    Rectangle {
        id: hl
        anchors.left: parent.left
        anchors.leftMargin: -6
        anchors.right: sw.left
        anchors.rightMargin: 6
        height: parent.height
        radius: 12
        color: root.expandable && openMa.containsMouse ? Theme.cardHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    IconBadge {
        id: badge
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        active: root.checked
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 10
        anchors.right: chev.left
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
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            elide: Text.ElideRight
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
        }
    }

    SymIcon {
        id: chev
        visible: root.expandable
        anchors.right: sw.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        size: 14
        name: "go-next-symbolic"
        color: Theme.textDim
    }

    MToggle {
        id: sw
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: root.checked
        onToggled: c => root.toggled(c)
    }

    MouseArea {
        id: openMa
        anchors.fill: hl
        enabled: root.expandable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.opened()
    }
}
