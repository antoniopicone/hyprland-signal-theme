import QtQuick

// Campo password a pillola con pulsante "Connetti".
Item {
    id: root
    property string placeholder: "Password"
    signal submitted(string password)
    signal cancelled()

    implicitHeight: 34

    function grab() { input.forceActiveFocus(); }

    Rectangle {
        anchors.left: parent.left
        anchors.right: go.left
        anchors.rightMargin: 6
        height: parent.height
        radius: height / 2
        color: Theme.trackOff
        border.width: input.activeFocus ? 2 : 0
        border.color: Theme.accent

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            verticalAlignment: TextInput.AlignVCenter
            echoMode: TextInput.Password
            passwordCharacter: "•"
            color: Theme.text
            selectionColor: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            clip: true
            onAccepted: if (text !== "") root.submitted(text)
            Keys.onEscapePressed: event => { root.cancelled(); event.accepted = true; }
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }

    MButton {
        id: go
        anchors.right: parent.right
        primary: true
        text: "Connetti"
        onClicked: if (input.text !== "") root.submitted(input.text)
    }
}
