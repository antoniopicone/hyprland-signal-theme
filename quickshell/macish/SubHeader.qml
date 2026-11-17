import QtQuick

// Intestazione dei sottopannelli: indietro, titolo, controllo a destra (es. interruttore).
Item {
    id: root
    property string title: ""
    signal back()
    default property alias trailing: right.data

    implicitHeight: 34

    MButton {
        id: backBtn
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 30
        icon: "go-previous-symbolic"
        onClicked: root.back()
    }

    Text {
        anchors.left: backBtn.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 2
        font.weight: Font.DemiBold
    }

    Row {
        id: right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
}
