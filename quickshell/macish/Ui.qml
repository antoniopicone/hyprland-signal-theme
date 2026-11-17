pragma Singleton
import Quickshell
import QtQuick

// Canale tra le parti della shell (barra, binario, launcher, pannello).
Singleton {
    signal toggleControlCenter()
    signal toggleLauncher()
    signal toggleAgents()
    signal toggleNotifications()
    property bool launcherOpen: false
    property bool controlCenterOpen: false
    property bool agentsOpen: false
    property bool notificationsOpen: false
}
