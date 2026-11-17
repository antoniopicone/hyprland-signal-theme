import QtQuick

// Spia rotonda. blinking = lampeggio lento (dissolvenza ~1 volta al secondo), fast = richiamo più rapido.
Rectangle {
    id: root
    property bool blinking: false
    property bool fast: false
    property real size: 7

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    radius: size / 2

    SequentialAnimation on opacity {
        running: root.blinking && Config.agentBlink
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { to: 0.15; duration: root.fast ? 170 : 500; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: root.fast ? 170 : 500; easing.type: Easing.InOutSine }
    }
}
