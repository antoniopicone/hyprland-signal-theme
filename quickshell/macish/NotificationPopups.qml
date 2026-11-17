import QtQuick
import Quickshell
import Quickshell.Wayland

// Banner delle notifiche in alto a sinistra, sotto la barra.
Scope {
    PanelWindow {
        id: win
        visible: Notifs.popups.length > 0 || lingerTimer.running
        screen: Sys.focusedScreen()
        color: "transparent"
        exclusiveZone: 0
        implicitWidth: Config.notifWidth + 44
        implicitHeight: 640   // alta abbastanza per l'animazione di uscita; il mask lascia passare i clic

        Timer { id: lingerTimer; interval: Theme.animSlow + 60 }
        Connections { target: Notifs; function onPopupsChanged() { lingerTimer.restart(); } }

        anchors { top: true; left: true }

        WlrLayershell.namespace: "macish-notifications"
        WlrLayershell.layer: WlrLayer.Overlay

        mask: Region { item: col }

        ListView {
            id: col
            x: 22
            y: 10
            width: Config.notifWidth
            height: contentHeight
            interactive: false
            spacing: 10
            model: ScriptModel { values: Notifs.popups }

            // Uscita verso sinistra, gli altri scorrono a riempire il posto
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: Theme.animSlow; easing.type: Easing.InCubic }
                    NumberAnimation { property: "x"; to: -60; duration: Theme.animSlow; easing.type: Easing.InCubic }
                }
            }
            displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.animSlow; easing.type: Easing.OutCubic } }

            delegate: NotificationCard {
                required property var modelData
                notification: modelData
                width: col.width
            }
        }
    }
}
