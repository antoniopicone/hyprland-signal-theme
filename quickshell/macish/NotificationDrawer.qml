import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Cassetto delle notifiche, a destra a tutta altezza. Si apre dal pallino in alto a sinistra,
// dal launcher o con:  qs -c macish ipc call notifiche toggle
Scope {
    id: root

    property bool open: false
    property bool mapped: false
    property bool reveal: false
    property double lastClosed: 0
    property var expanded: ({})          // app -> mostra tutte

    function toggle() {
        if (!open && Date.now() - lastClosed < 250) return;
        open = !open;
    }

    Connections {
        target: Ui
        function onToggleNotifications() { root.toggle(); }
    }
    IpcHandler {
        target: "notifiche"
        function toggle(): void { root.toggle(); }
        function show(): void { root.open = true; }
        function hide(): void { root.open = false; }
    }

    onOpenChanged: {
        Ui.notificationsOpen = open;
        if (open) {
            Notifs.markRead();
            hideTimer.stop();
            mapped = true;
            Qt.callLater(() => { root.reveal = root.open; });
        } else {
            reveal = false;
            hideTimer.restart();
        }
    }
    Timer { id: hideTimer; interval: Theme.animSlow; onTriggered: root.mapped = false }

    // gruppi per app, dal più recente
    readonly property var groups: {
        const order = [], by = {};
        for (const n of Notifs.history.slice().reverse()) {
            const app = (n.appName || "Sistema");
            if (!(app in by)) { by[app] = []; order.push(app); }
            by[app].push(n);
        }
        return order.map(app => ({ app: app, items: by[app] }));
    }

    function dismissGroup(g) { Notifs.dismissAnimated(g.items.slice()); }
    function toggleGroup(app) {
        const e = Object.assign({}, expanded);
        e[app] = !e[app];
        expanded = e;
    }

    PanelWindow {
        id: win
        visible: root.mapped
        screen: Sys.focusedScreen()
        color: "transparent"
        exclusiveZone: 0
        anchors { top: true; left: true; bottom: true }
        implicitWidth: 400 + 30
        WlrLayershell.namespace: "macish-notifiche"
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
            x: root.reveal ? 10 : -60
            y: 8
            width: 400
            height: parent.height - 18
            focus: true
            Keys.onEscapePressed: root.open = false
            opacity: root.reveal ? 1 : 0
            Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

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
                            font.pixelSize: 28
                            text: "NOTIFICHE"
                        }
                        Mono {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 9
                            text: Notifs.history.length === 0 ? "nessuna" : Notifs.history.length + " in tutto"
                        }
                    }

                    // Non disturbare
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: Theme.radiusCard
                        color: Theme.card
                        border.width: 1
                        border.color: Theme.stroke
                        Text {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Non disturbare"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                        Mono {
                            anchors.right: dndToggle.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: Notifs.dnd ? "Acceso" : "Spento"
                        }
                        MToggle {
                            id: dndToggle
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            checked: Notifs.dnd
                            onToggled: c => Notifs.dnd = c
                        }
                    }

                    Text {
                        visible: Notifs.history.length === 0
                        width: parent.width
                        topPadding: 20
                        horizontalAlignment: Text.AlignHCenter
                        text: "Tutto letto."
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }

                    // gruppi per app
                    Repeater {
                        model: ScriptModel { values: root.groups; objectProp: "app" }

                        Column {
                            id: group
                            required property var modelData
                            readonly property bool open: !!root.expanded[modelData.app]
                            readonly property int extra: Math.max(0, modelData.items.length - 3)
                            width: content.width
                            spacing: 6

                            Item {
                                width: parent.width
                                height: 26
                                Mono {
                                    x: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: group.modelData.app + " · " + group.modelData.items.length
                                }
                                Row {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 14
                                    LinkText {
                                        visible: group.extra > 0
                                        text: group.open ? "Mostra meno" : "Altre " + group.extra
                                        onClicked: root.toggleGroup(group.modelData.app)
                                    }
                                    LinkText {
                                        text: "Cancella"
                                        onClicked: root.dismissGroup(group.modelData)
                                    }
                                }
                            }

                            Repeater {
                                model: ScriptModel { values: group.modelData.items }
                                NotificationCard {
                                    required property var modelData
                                    required property int index
                                    notification: modelData
                                    folded: index >= 3 && !group.open
                                    popup: false
                                    width: group.width
                                }
                            }
                        }
                    }

                    Item {
                        visible: Notifs.history.length > 0
                        width: parent.width
                        height: 44
                        MButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Cancella tutto"
                            onClicked: Notifs.clearAll()
                        }
                    }
                }
            }
        }
    }
}
