import QtQuick
import Quickshell
import Quickshell.Wayland

// Sfondo Segnale: griglia di puntini e l'ora in grande, a matrice, quasi invisibile.
// Sta sul livello "bottom", sopra lo sfondo di Omarchy e sotto le finestre.
Scope {
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Variants {
        model: Config.showWallpaper ? Quickshell.screens : []

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: Theme.wall
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "segnale-wallpaper"
            mask: Region {}

            Behavior on color { ColorAnimation { duration: 600 } }

            Canvas {
                id: grid
                anchors.fill: parent
                property color dot: Theme.wallDot
                onDotChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = dot;
                    const step = 14, r = 1.15;
                    for (let y = step / 2; y < height; y += step)
                        for (let x = step / 2; x < width; x += step) {
                            ctx.beginPath();
                            ctx.arc(x, y, r, 0, 2 * Math.PI);
                            ctx.fill();
                        }
                }
            }

            ClockText {
                visible: Config.wallpaperClock
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 96
                anchors.bottomMargin: 30
                date: clock.date
                color: Theme.wallClock
                pixelSize: Math.round(parent.height * 0.25)
                Behavior on color { ColorAnimation { duration: 600 } }
            }
        }
    }
}
