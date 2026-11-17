import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Barra in alto: workspace, titolo della finestra attiva, stato e ora a puntini.
Scope {
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Variants {
        model: Config.showBar ? Quickshell.screens : []

        PanelWindow {
            id: win
            required property var modelData
            readonly property var monitor: Hyprland.monitorFor(modelData)

            screen: modelData
            color: "transparent"
            anchors { top: true; left: true; right: true }
            implicitHeight: Config.barHeight
            exclusiveZone: Config.barHeight
            WlrLayershell.namespace: "macish-bar"
            WlrLayershell.layer: WlrLayer.Top

            Glass {
                x: 0
                y: 0
                width: parent.width
                height: Config.barHeight
                radius: 0
                shadow: false
                fill: Theme.dark ? "#000000" : Theme.glass
                border: "transparent"

                // Workspace
                Row {
                    id: wsRow
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // Notifiche: pieno = niente da leggere, rosso fisso = da leggere,
                    // solo contorno = Non disturbare (rosso se nel frattempo è arrivato qualcosa)
                    Rectangle {
                        id: notifDot
                        readonly property bool fresh: Notifs.unread > 0
                        readonly property color tone: fresh ? Theme.alert : Theme.text
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        radius: 11
                        color: ndMa.containsMouse || Ui.notificationsOpen ? Theme.cardHover : "transparent"

                        // Impulso quando arriva qualcosa: anello che si espande e svanisce
                        Rectangle {
                            id: pulseRing
                            anchors.centerIn: parent
                            width: 8
                            height: 8
                            radius: 4
                            color: "transparent"
                            border.width: 1.5
                            border.color: Theme.alert
                            opacity: 0
                            scale: 1
                        }
                        Connections {
                            target: Notifs
                            property int last: 0
                            function onUnreadChanged() {
                                if (Notifs.unread > last) pulseAnim.restart();
                                last = Notifs.unread;
                            }
                        }
                        ParallelAnimation {
                            id: pulseAnim
                            NumberAnimation { target: pulseRing; property: "scale"; from: 1; to: 2.8; duration: 700; easing.type: Easing.OutCubic }
                            SequentialAnimation {
                                NumberAnimation { target: pulseRing; property: "opacity"; from: 0.9; to: 0.9; duration: 1 }
                                NumberAnimation { target: pulseRing; property: "opacity"; to: 0; duration: 700; easing.type: Easing.OutCubic }
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 8
                            height: 8
                            radius: 4
                            color: Notifs.dnd ? "transparent" : notifDot.tone
                            border.width: Notifs.dnd ? 1.5 : 0
                            border.color: notifDot.tone
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }
                        MouseArea {
                            id: ndMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ui.toggleNotifications()
                        }
                    }

                    Row {
                        spacing: 4
                        Repeater {
                            model: ScriptModel {
                                values: Sys.arr(Hyprland.workspaces.values)
                                    .filter(w => w.id > 0 && (!w.monitor || !win.monitor || w.monitor === win.monitor))
                                    .sort((a, b) => a.id - b.id)
                            }
                            Rectangle {
                                required property var modelData
                                readonly property bool current: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData.id
                                width: wsLabel.implicitWidth + 16
                                height: 22
                                radius: 7
                                color: current ? Theme.on : (wsMa.containsMouse ? Theme.cardHover : "transparent")
                                Mono {
                                    id: wsLabel
                                    anchors.centerIn: parent
                                    text: (modelData.id < 10 ? "0" : "") + modelData.id
                                    color: parent.current ? Theme.onText : Theme.textDim
                                }
                                MouseArea {
                                    id: wsMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch("workspace " + parent.modelData.id)
                                }
                            }
                        }
                    }
                }

                // Titolo della finestra attiva: a sinistra, fuori dal notch (al centro)
                Text {
                    anchors.left: wsRow.right
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, Math.min(implicitWidth, parent.width / 2 - Config.notchHalf - wsRow.x - wsRow.width - 18))
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    text: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.title : ""
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                // Agenti: un puntino per agente (bianco che respira = lavora, rosso = aspetta te, grigio = finito)
                Rectangle {
                    visible: Agents.list.length > 0
                    anchors.right: statusBox.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: agRow.implicitWidth + 20
                    height: 28
                    radius: 10
                    color: agMa.containsMouse || Ui.agentsOpen ? Theme.cardHover : "transparent"

                    Row {
                        id: agRow
                        anchors.centerIn: parent
                        spacing: 5
                        Mono { anchors.verticalCenter: parent.verticalCenter; text: "AG"; color: Theme.textDim }
                        Repeater {
                            model: ScriptModel { values: Agents.list.slice(0, 6); objectProp: "id" }
                            AlertDot {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                size: 7
                                color: modelData.state === "attende" || modelData.state === "errore" ? Theme.alert
                                     : modelData.state === "lavora" ? Theme.text : Theme.trackOff
                                blinking: modelData.state === "lavora" || (modelData.state === "attende" && !Agents.isSeen(modelData))
                                fast: modelData.state === "attende" && !Agents.isSeen(modelData) && Agents.nudging(modelData)
                            }
                        }
                        Mono {
                            visible: Agents.list.length > 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: "+" + (Agents.list.length - 6)
                        }
                    }
                    MouseArea {
                        id: agMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.toggleAgents()
                    }
                }

                // Stato e ora: un clic apre il pannello rapido
                Rectangle {
                    id: statusBox
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: status.implicitWidth + 20
                    height: 28
                    radius: 10
                    color: stMa.containsMouse || Ui.controlCenterOpen ? Theme.cardHover : "transparent"

                    Row {
                        id: status
                        anchors.centerIn: parent
                        spacing: 16

                        // Ethernet: compare solo con il cavo collegato
                        Row {
                            visible: Sys.ethOn
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter
                            Mono { text: "Eth" }
                            Mono { color: Theme.text; text: "●" }
                        }
                        Row {
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter
                            Mono { text: "Wi-Fi" }
                            Mono {
                                color: Theme.text
                                text: !Sys.wifiOn ? "off"
                                    : ["○○○○", "●○○○", "●●○○", "●●●○", "●●●●"][Math.min(4, Math.ceil(Sys.wifiSignal / 25))]
                            }
                        }
                        Row {
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter
                            Mono { text: "Vol" }
                            Mono { color: Theme.text; text: Sys.muted ? "muto" : Math.round(Sys.volume * 100) }
                        }
                        // Batteria: un clic alterna percentuale, autonomia e consumo
                        Row {
                            id: batRow
                            visible: Sys.hasBattery
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter
                            property int mode: 0        // 0 = %, 1 = ore e minuti, 2 = watt
                            Mono { text: batRow.mode === 2 ? "Watt" : "Bat" }
                            Mono {
                                color: Sys.charging ? Theme.accent : Theme.text
                                text: batRow.mode === 0 ? Math.round(Sys.batteryLevel * 100) + "%"
                                    : batRow.mode === 1 ? Sys.formatDuration(Sys.batterySeconds)
                                    : Math.round(Sys.batteryWatts)
                            }
                        }
                        ClockText {
                            anchors.verticalCenter: parent.verticalCenter
                            pixelSize: 18
                            date: clock.date
                        }
                    }

                    // Clic sulla batteria: alterna %, autonomia, watt (sopra il clic generale)
                    MouseArea {
                        visible: batRow.visible
                        z: 2
                        x: status.x + batRow.x - 6
                        width: batRow.width + 12
                        height: parent.height
                        cursorShape: Qt.PointingHandCursor
                        onClicked: batRow.mode = (batRow.mode + 1) % 3
                    }

                    MouseArea {
                        id: stMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.toggleControlCenter()
                    }
                }
            }
        }
    }
}
