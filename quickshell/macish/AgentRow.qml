import QtQuick

// Una riga del pannello Agenti.
Rectangle {
    id: root
    required property var agent
    readonly property var a: agent
    readonly property bool waiting: a.state === "attende"
    readonly property bool unseen: waiting && !Agents.isSeen(a)
    readonly property bool done: a.state === "finito"
    readonly property bool failed: a.state === "errore"
    readonly property color stateColor: waiting || failed ? Theme.alert : done ? Theme.textDim : Theme.text

    implicitHeight: col.implicitHeight + 22
    radius: Theme.radiusCard
    color: Theme.card
    border.width: waiting ? 1.5 : 1
    border.color: waiting ? Theme.alert : Theme.stroke
    opacity: done ? 0.75 : 1

    // il bordo lampeggia insieme alla spia finché non hai visto la richiesta
    SequentialAnimation on border.color {
        running: root.unseen && Config.agentBlink
        loops: Animation.Infinite
        alwaysRunToEnd: true
        ColorAnimation { to: Theme.stroke; duration: 500 }
        ColorAnimation { to: Theme.alert; duration: 500 }
    }

    Column {
        id: col
        x: 11
        y: 11
        width: parent.width - 22
        spacing: 7

        // nome e stato
        Item {
            width: parent.width
            height: 18
            AlertDot {
                anchors.verticalCenter: parent.verticalCenter
                size: 7
                color: root.stateColor
                blinking: root.unseen || root.a.state === "lavora"
                fast: root.unseen && Agents.nudging(root.a)
            }
            Text {
                x: 15
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 15 - stateLabel.width - 8
                elide: Text.ElideRight
                text: (root.a.name || "Agente") + " · " + (root.a.project || "")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Mono {
                id: stateLabel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: ({ attende: "Attende", lavora: "Lavora", finito: "Finito", errore: "Errore" })[root.a.state] || root.a.state
                color: root.waiting || root.failed ? Theme.alert : root.done ? Theme.textDim : Theme.text
            }
        }

        // cartella, workspace, tempo e attività
        Item {
            width: parent.width
            height: 14
            Mono {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - spark.width - 8
                elide: Text.ElideMiddle
                text: Agents.shortPath(root.a.cwd)
                      + (root.a.workspace ? " · WS " + (root.a.workspace < 10 ? "0" : "") + root.a.workspace : "")
                      + " · " + Agents.elapsed(root.a)
            }
            Row {
                id: spark
                visible: !root.done
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 3
                Repeater {
                    model: Agents.spark(root.a)
                    Rectangle {
                        required property int modelData
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 4
                        height: 2 + Math.min(12, modelData * 2)
                        radius: 2
                        color: index === 9 && modelData > 0 ? Theme.accent : (modelData > 0 ? Theme.text : Theme.trackOff)
                    }
                }
            }
        }

        // cosa sta facendo o cosa chiede
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            text: root.waiting ? (root.a.message || "Chiede la tua conferma") : (root.a.last || "")
            visible: text !== ""
            color: Theme.text
            opacity: 0.85
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        // azioni
        Row {
            spacing: 6
            MButton {
                visible: root.waiting
                implicitHeight: 30
                text: "Vai al terminale"
                alert: true
                onClicked: { Agents.focus(root.a); Ui.toggleAgents(); }
            }
            MButton {
                visible: root.waiting
                implicitHeight: 30
                text: "Più tardi"
                onClicked: Agents.markSeen(root.a)
            }
            MButton {
                visible: !root.waiting
                implicitHeight: 30
                text: "Vai"
                onClicked: { Agents.focus(root.a); Ui.toggleAgents(); }
            }
            MButton {
                visible: root.done || root.failed
                implicitHeight: 30
                text: "Chiudi"
                onClicked: Agents.remove(root.a)
            }
        }
    }
}
