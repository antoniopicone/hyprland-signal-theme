import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Pannello Agenti. Si apre dall'indicatore AG nella barra, dal launcher o con:
//   qs -c macish ipc call agenti toggle
Scope {
    id: root

    property bool open: false
    property bool mapped: false
    property bool reveal: false
    property double lastClosed: 0

    function toggle() {
        if (!open && Date.now() - lastClosed < 250) return;
        open = !open;
    }

    Connections {
        target: Ui
        function onToggleAgents() { root.toggle(); }
    }

    onOpenChanged: {
        Ui.agentsOpen = open;
        if (open) {
            Agents.refresh();
            Agents.markAllSeen();          // aprendo il pannello il rosso smette di lampeggiare
            hideTimer.stop();
            mapped = true;
            Qt.callLater(() => { root.reveal = root.open; });
        } else {
            reveal = false;
            hideTimer.restart();
        }
    }
    Timer { id: hideTimer; interval: Theme.animSlow; onTriggered: root.mapped = false }

    PanelWindow {
        id: win
        readonly property int pad: 22
        visible: root.mapped
        screen: Sys.focusedScreen()
        color: "transparent"
        exclusiveZone: 0
        anchors { top: true; right: true }
        implicitWidth: 380 + pad * 2
        implicitHeight: Math.min(content.implicitHeight + 24, 820) + pad * 2
        WlrLayershell.namespace: "macish-agenti"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        mask: Region { item: panel }

        HyprlandFocusGrab {
            windows: [win]
            active: root.open
            onCleared: { root.lastClosed = Date.now(); root.open = false; }
        }

        Glass {
            radius: 20
            id: panel
            x: win.pad
            y: win.pad - 14
            width: 380
            height: Math.min(content.implicitHeight + 24, 820)
            focus: true
            Keys.onEscapePressed: root.open = false
            opacity: root.reveal ? 1 : 0
            scale: root.reveal ? 1 : 0.97
            transformOrigin: Item.TopRight
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

            Flickable {
                anchors.fill: parent
                anchors.margins: 12
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: content
                    width: parent.width
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 40
                        Dots {
                            x: 4
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            font.pixelSize: 30
                            text: "AGENTI"
                        }
                        Mono {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 9
                            text: Agents.list.length === 0 ? "nessuno attivo"
                                : [Agents.working ? Agents.working + (Agents.working === 1 ? " lavora" : " lavorano") : "",
                                   Agents.waiting.length ? Agents.waiting.length + " attende" + (Agents.waiting.length === 1 ? "" : "no") : ""]
                                  .filter(s => s).join(" · ") || "tutti fermi"
                            color: Agents.waiting.length ? Theme.alert : Theme.textDim
                        }
                    }

                    Card {
                        width: parent.width
                        visible: Agents.list.length === 0
                        Text {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: "Avvia Claude Code in un terminale (con gli hook installati) oppure un altro agente con  agente avvia <nome> -- <comando>: comparirà qui."
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    Repeater {
                        model: ScriptModel { values: Agents.list; objectProp: "id" }
                        AgentRow {
                            required property var modelData
                            agent: modelData
                            width: content.width
                        }
                    }

                    Item {
                        width: parent.width
                        height: 40
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            MButton { text: "+ Nuovo agente"; onClicked: { root.open = false; Sys.sh(Config.newAgentCommand); } }
                            MButton {
                                visible: Agents.list.some(a => a.state === "finito" || a.state === "errore")
                                text: "Pulisci finiti"
                                onClicked: Agents.clearFinished()
                            }
                        }
                    }
                }
            }
        }
    }
}
