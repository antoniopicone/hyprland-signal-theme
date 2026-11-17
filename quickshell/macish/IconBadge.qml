import QtQuick

// Cerchio con icona: acceso = pieno (inchiostro/carta).
Rectangle {
    id: root
    property string icon: ""
    property bool active: false

    implicitWidth: 34
    implicitHeight: 34
    radius: width / 2
    color: active ? Theme.on : Theme.card
    border.width: active ? 0 : 1
    border.color: Theme.stroke
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    SymIcon {
        anchors.centerIn: parent
        size: 16
        name: root.icon
        color: root.active ? Theme.onText : Theme.text
    }
}
