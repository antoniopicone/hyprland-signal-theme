import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// Una notifica: banner (popup: true) o voce nel Centro di Controllo (popup: false).
Item {
    id: root
    required property var notification
    property bool popup: true

    readonly property var n: notification
    readonly property bool critical: n !== null && n.urgency === NotificationUrgency.Critical
    readonly property var actions: Notifs.actionsOf(n)
    readonly property var buttons: actions.filter(a => a.identifier !== "default")
    readonly property var defaultAction: actions.find(a => a.identifier === "default") ?? null
    readonly property string iconSource: Notifs.iconFor(n)

    // In uscita dal cassetto: si accorcia, sfuma e scivola a sinistra
    property bool folded: false          // nel cassetto: nascosta dietro "Altre N"
    readonly property bool leaving: folded || (!popup && Notifs.isLeaving(n))
    visible: height > 0.5 || !leaving
    implicitHeight: leaving ? 0 : body.implicitHeight + 24
    Behavior on implicitHeight { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.InOutCubic } }
    clip: leaving
    property real leaveOp: leaving ? 0 : 1
    Behavior on leaveOp { NumberAnimation { duration: Theme.animFast + 40; easing.type: Easing.InCubic } }
    property real leaveX: leaving ? -50 : 0
    Behavior on leaveX { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.InCubic } }

    // Entrata dal lato destro, come su macOS
    property real appear: 0
    property real enterX: root.popup ? -40 : 0
    opacity: appear * leaveOp
    transform: Translate { x: root.enterX + root.leaveX }
    Component.onCompleted: enter.start()
    ParallelAnimation {
        id: enter
        NumberAnimation { target: root; property: "appear"; to: 1; duration: Theme.animSlow; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "enterX"; to: 0; duration: Theme.animSlow + 60; easing.type: Easing.OutCubic }
    }

    HoverHandler { id: hover }

    Glass {
        anchors.fill: parent
        radius: 18
        shadow: root.popup
        glossy: root.popup
        fill: root.popup ? Theme.glass : (clickMa.containsMouse ? Theme.cardHover : Theme.card)
        border: root.critical ? Theme.danger : Theme.stroke
    }

    // Clic sulla notifica = azione predefinita dell'app (di solito: apri la finestra)
    MouseArea {
        id: clickMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.defaultAction) root.defaultAction.invoke();
            else if (root.popup) Notifs.removePopup(root.n);
        }
    }

    Item {
        id: body
        x: 12
        y: 12
        width: parent.width - 24
        implicitHeight: Math.max(iconBox.height, texts.implicitHeight)
                        + (actionRow.visible ? actionRow.height + 10 : 0)

        ClippingRectangle {
            id: iconBox
            width: 38
            height: 38
            radius: 10
            color: "transparent"
            visible: root.iconSource !== ""

            IconImage {
                anchors.fill: parent
                source: root.iconSource
            }
        }

        Column {
            id: texts
            anchors.left: iconBox.visible ? iconBox.right : parent.left
            anchors.leftMargin: iconBox.visible ? 10 : 0
            anchors.right: parent.right
            spacing: 2

            Item {
                width: parent.width
                height: appName.implicitHeight

                Mono {
                    id: appName
                    anchors.left: parent.left
                    anchors.right: when.left
                    anchors.rightMargin: 8
                    text: root.n ? (root.n.appName || "") : ""
                    elide: Text.ElideRight
                }
                Mono {
                    id: when
                    anchors.right: parent.right
                    text: Notifs.timeOf(root.n)
                }
            }

            Text {
                width: parent.width
                text: root.n ? root.n.summary : ""
                elide: Text.ElideRight
                color: root.critical ? Theme.danger : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.n ? root.n.body : ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 4 : 2
                elide: Text.ElideRight
                color: Theme.text
                opacity: 0.85
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
        }

        Row {
            id: actionRow
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            spacing: 6

            Repeater {
                model: root.buttons
                MButton {
                    required property var modelData
                    implicitHeight: 28
                    text: modelData.text
                    onClicked: modelData.invoke()
                }
            }

            MButton {
                implicitHeight: 28
                text: I18n.t("Chiudi")
                opacity: hover.hovered ? 1 : 0
                enabled: hover.hovered
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                onClicked: root.popup ? root.n.dismiss() : Notifs.dismissAnimated([root.n])
            }
        }
    }

    // Scadenza del banner: si ferma se ci passi sopra col mouse
    Timer {
        running: root.popup && !root.critical && !hover.hovered
        interval: root.n && root.n.expireTimeout > 0 ? root.n.expireTimeout * 1000 : Config.notifTimeout
        onTriggered: {
            if (root.n.transient) root.n.expire();
            else Notifs.removePopup(root.n);     // resta nel Centro di Controllo
        }
    }
}
