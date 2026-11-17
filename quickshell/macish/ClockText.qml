import QtQuick

// Ora nel carattere a puntini, con i due punti centrati sulle cifre
// (in Doto i due punti stanno più in basso di circa un decimo di corpo).
Row {
    id: root
    property date date: new Date()
    property color color: Theme.text
    property int pixelSize: 18
    property int weight: Font.ExtraBold
    property real colonLift: 0.10
    property real lineHeight: 1

    component Seg: Text {
        color: root.color
        font.family: Theme.display
        font.weight: root.weight
        font.pixelSize: root.pixelSize
        lineHeight: root.lineHeight
    }

    Seg { text: Qt.formatTime(root.date, "HH") }
    Seg {
        text: ":"
        transform: Translate { y: -root.pixelSize * root.colonLift }
    }
    Seg { text: Qt.formatTime(root.date, "mm") }
}
