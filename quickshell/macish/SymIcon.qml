import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

// Icona simbolica Yaru ricolorata a piacere.
Item {
    id: root
    property string name: ""
    property color color: Theme.text
    property real size: 18

    implicitWidth: size
    implicitHeight: size

    IconImage {
        anchors.fill: parent
        source: Quickshell.iconPath(root.name, "image-missing")
        layer.enabled: true
        layer.effect: MultiEffect {
            brightness: 1.0
            colorization: 1.0
            colorizationColor: root.color
        }
    }
}
