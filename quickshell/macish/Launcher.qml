import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

// Launcher Segnale: riga di comando con app e azioni.
//   qs -c macish ipc call launcher toggle
Scope {
    id: root

    property bool open: false
    property string query: ""
    property int sel: 0
    property bool mapped: false
    property bool reveal: false

    onOpenChanged: {
        Ui.launcherOpen = open;
        if (open) {
            query = "";
            input.text = "";
            sel = 0;
            hideTimer.stop();
            mapped = true;
            Qt.callLater(() => { root.reveal = root.open; });
        } else {
            reveal = false;
            hideTimer.restart();
        }
    }
    Timer { id: hideTimer; interval: Theme.animSlow; onTriggered: root.mapped = false }

    function toggle() { open = !open; }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle(); }
        function show(): void { root.open = true; }
        function hide(): void { root.open = false; }
    }
    Connections {
        target: Ui
        function onToggleLauncher() { root.toggle(); }
    }

    function lookup(id) {
        return DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(id) : DesktopEntries.byId(id);
    }

    readonly property var actions: [
        { name: "Pannello rapido", icon: "emblem-system-symbolic", sub: "Azione", run: () => Ui.toggleControlCenter() },
        { name: Theme.dark ? "Passa al tema chiaro" : "Passa al tema scuro", icon: Theme.dark ? "weather-clear-symbolic" : "weather-clear-night-symbolic",
          sub: "Aspetto", run: () => Sys.setDark(!Theme.dark) },
        { name: Agents.waiting.length ? "Agenti · " + Agents.waiting.length + " in attesa" : "Agenti", icon: "system-run-symbolic",
          sub: "Agenti", run: () => Ui.toggleAgents() },
        { name: Notifs.unread ? "Notifiche · da leggere" : "Notifiche", icon: "preferences-system-notifications-symbolic",
          sub: "Notifiche", run: () => Ui.toggleNotifications() },
        { name: Notifs.dnd ? "Disattiva Non disturbare" : "Attiva Non disturbare", icon: "notifications-disabled-symbolic",
          sub: "Notifiche", run: () => { Notifs.dnd = !Notifs.dnd; } },
        { name: "Nuovo agente", icon: "list-add-symbolic", sub: "Agenti", run: () => Sys.sh(Config.newAgentCommand) },
        { name: "Blocca schermo", icon: "system-lock-screen-symbolic", sub: "Azione", run: () => Sys.sh(Config.lockCommand) },
        { name: "Sospendi", icon: "media-playback-pause-symbolic", sub: "Azione", run: () => Sys.sh(Config.suspendCommand) }
    ]

    function appItem(e) {
        return { name: e.name, app: e, sub: e.genericName || "App", run: () => e.execute() };
    }

    readonly property var results: {
        const q = root.query.trim().toLowerCase();
        if (q === "") {
            const pinned = Config.pinned.map(id => root.lookup(id)).filter(e => e).slice(0, 5).map(e => root.appItem(e));
            return pinned.concat(root.actions);
        }
        const scored = [];
        for (const e of Sys.arr(DesktopEntries.applications.values)) {
            if (e.noDisplay) continue;
            const name = (e.name || "").toLowerCase();
            const extra = ((e.genericName || "") + " " + (e.comment || "") + " " + Sys.arr(e.keywords).join(" ")).toLowerCase();
            const s = name.startsWith(q) ? 3 : name.indexOf(q) >= 0 ? 2 : extra.indexOf(q) >= 0 ? 1 : 0;
            if (s > 0) scored.push({ s: s, e: e });
        }
        scored.sort((a, b) => (b.s - a.s) || a.e.name.localeCompare(b.e.name));
        const apps = scored.slice(0, 7).map(x => root.appItem(x.e));
        const acts = root.actions.filter(a => a.name.toLowerCase().indexOf(q) >= 0 || a.sub.toLowerCase().indexOf(q) >= 0);
        return apps.concat(acts);
    }

    onResultsChanged: sel = Math.min(sel, Math.max(0, results.length - 1))

    function run(i) {
        const r = results[i];
        if (!r) return;
        open = false;
        r.run();
    }

    PanelWindow {
        id: win
        visible: root.mapped
        screen: Sys.focusedScreen()
        color: "transparent"
        anchors { top: true }
        margins { top: 110 }
        exclusiveZone: 0
        implicitWidth: Config.launcherWidth + 60
        implicitHeight: panel.height + 60
        WlrLayershell.namespace: "macish-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region { item: panel }

        HyprlandFocusGrab {
            windows: [win]
            active: root.open
            onCleared: root.open = false
        }

        Glass {
            id: panel
            x: 30
            y: 10
            width: Config.launcherWidth
            height: col.implicitHeight
            radius: 20
            opacity: root.reveal ? 1 : 0
            scale: root.reveal ? 1 : 0.97
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

            Column {
                id: col
                width: parent.width

                // Riga di comando
                Item {
                    width: parent.width
                    height: 58
                    Mono {
                        id: prompt
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: ">"
                        color: Theme.accent
                        font.pixelSize: 15
                    }
                    TextInput {
                        id: input
                        anchors.left: prompt.right
                        anchors.leftMargin: 12
                        anchors.right: hint.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.query
                        onTextChanged: { root.query = text; root.sel = 0; }
                        color: Theme.text
                        selectionColor: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                        focus: root.open
                        onVisibleChanged: if (visible) forceActiveFocus()
                        Component.onCompleted: forceActiveFocus()
                        Keys.onEscapePressed: root.open = false
                        Keys.onUpPressed: root.sel = Math.max(0, root.sel - 1)
                        Keys.onDownPressed: root.sel = Math.min(root.results.length - 1, root.sel + 1)
                        Keys.onTabPressed: root.sel = (root.sel + 1) % Math.max(1, root.results.length)
                        onAccepted: root.run(root.sel)

                        Text {
                            visible: input.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Cerca app e azioni"
                            color: Theme.textDim
                            font: input.font
                        }
                    }
                    Rectangle {
                        id: hint
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: hintText.implicitWidth + 12
                        height: 20
                        radius: 6
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.stroke
                        Mono { id: hintText; anchors.centerIn: parent; text: "Super" }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.stroke }

                // Risultati
                Column {
                    x: 8
                    width: parent.width - 16
                    topPadding: 8
                    bottomPadding: 8

                    Mono {
                        leftPadding: 10
                        topPadding: 4
                        bottomPadding: 6
                        text: root.query === "" ? "Fissate e azioni" : (root.results.length ? "Risultati" : "Nessun risultato")
                    }

                    Repeater {
                        model: root.results
                        Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool current: index === root.sel
                            width: parent.width
                            height: 44
                            radius: 12
                            color: current ? Theme.cardHover : "transparent"

                            Rectangle {
                                visible: parent.current
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6; height: 6; radius: 3
                                color: Theme.accent
                            }
                            IconImage {
                                visible: !!parent.modelData.app
                                x: 26
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 24
                                source: parent.modelData.app ? Quickshell.iconPath(parent.modelData.app.icon, "application-x-executable") : ""
                            }
                            SymIcon {
                                visible: !parent.modelData.app
                                x: 29
                                anchors.verticalCenter: parent.verticalCenter
                                size: 18
                                name: parent.modelData.icon || ""
                            }
                            Text {
                                x: 62
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 62 - subText.width - 20
                                elide: Text.ElideRight
                                text: parent.modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: parent.current ? Font.DemiBold : Font.Normal
                            }
                            Mono {
                                id: subText
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, 160)
                                elide: Text.ElideRight
                                text: parent.current ? "↵ Apri" : parent.modelData.sub
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.sel = parent.index
                                onClicked: root.run(parent.index)
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.stroke }

                Row {
                    x: 20
                    height: 38
                    spacing: 18
                    Mono { anchors.verticalCenter: parent.verticalCenter; text: "↑↓ Scegli" }
                    Mono { anchors.verticalCenter: parent.verticalCenter; text: "↵ Apri" }
                    Mono { anchors.verticalCenter: parent.verticalCenter; text: "Esc Chiudi" }
                }
            }
        }
    }
}
