import QtQuick

// Testo cliccabile discreto, per i rimandi ai pannelli avanzati di Omarchy.
Text {
    id: root
    signal clicked()

    color: ma.containsMouse ? Theme.accent : Theme.textDim
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize - 1

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
