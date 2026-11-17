import QtQuick
import Quickshell

// Dettaglio Schermo: luminosità, scala e orientamento di ogni monitor.
Column {
    id: root
    signal back()
    signal advanced()
    spacing: 10

    Component.onCompleted: Disp.refresh()

    function sameScale(a, b) { return Math.abs(Number(a) - Number(b)) < 0.005; }

    SubHeader {
        width: parent.width
        title: "Schermo"
        onBack: root.back()
    }

    Card {
        width: parent.width
        title: "Luminosità"

        MSlider {
            width: parent.width
            label: "Luce"
            value: Sys.brightness
            onMoved: v => Sys.setBrightness(v)
        }
    }

    Repeater {
        model: ScriptModel { values: Disp.monitors; objectProp: "name" }

        Card {
            id: card
            required property var modelData
            width: root.width
            title: modelData.name + " · " + modelData.width + "×" + modelData.height

            SectionLabel { text: "Scala" }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: Disp.scalesFor(card.modelData)
                    MButton {
                        required property string modelData
                        implicitHeight: 28
                        primary: root.sameScale(modelData, card.modelData.scale)
                        text: modelData + "×"
                        onClicked: Disp.setScale(card.modelData, modelData)
                    }
                }
            }

            SectionLabel { text: "Orientamento" }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: Disp.orientations
                    MButton {
                        required property var modelData
                        implicitHeight: 28
                        primary: card.modelData.transform === modelData.transform
                        text: modelData.label
                        onClicked: Disp.setTransform(card.modelData, modelData.transform)
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        visible: Disp.error !== ""
        leftPadding: 6
        text: Disp.error
        wrapMode: Text.WordWrap
        color: "#ff6b5f"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
    }

    Item {
        width: parent.width
        height: 26

        LinkText {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "Altre impostazioni dello schermo…"
            onClicked: root.advanced()
        }
    }
}
