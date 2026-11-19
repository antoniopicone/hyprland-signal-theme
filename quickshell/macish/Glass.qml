import QtQuick
import QtQuick.Effects

// Pannello Segnale: superficie piena con bordo sottile.
// Chiaro e scuro: ombra netta spostata, come fogli impilati. Alone morbido solo se hardShadow è false.
Item {
    id: root
    property real radius: Theme.radiusPanel
    property bool shadow: true
    property color fill: Theme.glass
    property color border: Theme.stroke
    property bool glossy: false          // compatibilità: Segnale non ha riflessi
    default property alias content: inner.data

    // ombra netta (chiaro)
    Rectangle {
        visible: root.shadow && Theme.hardShadow
        x: 8
        y: 8
        width: inner.width
        height: inner.height
        radius: root.radius
        color: Theme.shadow
    }

    // alone (scuro)
    RectangularShadow {
        visible: root.shadow && !Theme.hardShadow
        anchors.fill: inner
        radius: root.radius
        blur: 40
        offset: Qt.vector2d(0, 16)
        color: Theme.shadow
    }

    Rectangle {
        id: inner
        anchors.fill: parent
        radius: root.radius
        color: root.fill
        border.width: 1
        border.color: root.border
        Behavior on color { ColorAnimation { duration: 400 } }
    }
}
