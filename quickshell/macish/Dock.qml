import QtQuick
import Quickshell
import Quickshell.Wayland

// Binario a sinistra: launcher, app fissate e app aperte.
Scope {
    id: root

    function lookup(id) {
        if (!id) return null;
        return DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(id) : DesktopEntries.byId(id);
    }

    readonly property var items: {
        DesktopEntries.applications.values;
        const toplevels = ToplevelManager.toplevels.values;
        const out = [], index = {};
        for (const id of Config.pinned) {
            const e = root.lookup(id);
            if (!e) continue;
            const k = e.id.toLowerCase();
            if (k in index) continue;
            index[k] = out.length;
            out.push({ key: k, entry: e, appId: id, windows: [] });
        }
        for (const t of toplevels) {
            const e = root.lookup(t.appId);
            const k = (e ? e.id : (t.appId || "?")).toLowerCase();
            if (!(k in index)) {
                index[k] = out.length;
                out.push({ key: k, entry: e, appId: t.appId, windows: [] });
            }
            out[index[k]].windows.push(t);
        }
        return out;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            color: "transparent"
            anchors { left: true }
            implicitWidth: 260                      // spazio per le etichette
            implicitHeight: rail.height + 40
            exclusiveZone: 70
            WlrLayershell.namespace: "macish-rail"
            WlrLayershell.layer: WlrLayer.Top
            mask: Region { item: rail }

            Glass {
                id: rail
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: Config.railIcon + 16
                height: col.implicitHeight + 20
                radius: 20

                Column {
                    id: col
                    y: 10
                    spacing: 2

                    DockItem {
                        iconName: "view-app-grid-symbolic"
                        label: I18n.t("Applicazioni")
                        onTriggered: Ui.toggleLauncher()
                    }
                    Item {
                        width: Config.railIcon + 16
                        height: 11
                        Rectangle { anchors.centerIn: parent; width: 22; height: 1; color: Theme.stroke }
                    }
                    Repeater {
                        model: ScriptModel { values: root.items; objectProp: "key" }
                        DockItem {
                            required property var modelData
                            entry: modelData.entry
                            appId: modelData.appId
                            windows: modelData.windows
                        }
                    }
                }
            }
        }
    }
}
