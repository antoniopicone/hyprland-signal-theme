import QtQuick

// Scheda di vetro dentro i pannelli; il titolo è un'etichetta monospazio.
Rectangle {
    id: root
    property string title: ""
    property bool chevron: false
    signal titleClicked()
    default property alias content: col.data

    implicitHeight: col.implicitHeight + 24
    radius: Theme.radiusCard
    color: Theme.card
    border.width: 1
    border.color: Theme.stroke

    Column {
        id: col
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Item {
            visible: root.title !== ""
            width: parent.width
            height: titleText.implicitHeight

            Mono {
                id: titleText
                text: root.title
                color: titleMa.containsMouse ? Theme.accent : Theme.textDim
            }
            SymIcon {
                visible: root.chevron
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                size: 13
                name: "go-next-symbolic"
                color: Theme.textDim
            }
            MouseArea {
                id: titleMa
                anchors.fill: parent
                anchors.margins: -6
                enabled: root.chevron
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.titleClicked()
            }
        }
    }
}
