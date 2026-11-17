import QtQuick
import Quickshell

// Dettaglio Tailscale: questo dispositivo, macchine con IP, copia indirizzo e Taildrop.
Column {
    id: root
    signal back()
    signal advanced()
    spacing: 10

    Component.onCompleted: Tail.refresh()

    function osIcon(os) {
        const v = os.toLowerCase();
        return v === "ios" || v === "android" ? "smartphone-symbolic" : "computer-symbolic";
    }

    SubHeader {
        width: parent.width
        title: "Tailscale"
        onBack: root.back()

        MToggle {
            checked: Tail.running
            onToggled: Tail.toggle()
        }
    }

    Card {
        width: parent.width
        visible: !Tail.running

        Text {
            leftPadding: 6
            text: !Tail.known ? I18n.t("Controllo dello stato…")
                : Tail.backend === "NeedsLogin" ? I18n.t("Accesso richiesto: esegui «tailscale up» in un terminale.")
                : I18n.t("Tailscale è spento.")
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }

    Card {
        width: parent.width
        visible: Tail.running

        // Questo dispositivo
        Item {
            width: parent.width
            height: 46

            IconBadge {
                id: selfBadge
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 30
                implicitHeight: 30
                icon: "network-vpn-symbolic"
                active: true
            }
            Column {
                anchors.left: selfBadge.right
                anchors.leftMargin: 10
                anchors.right: selfCopy.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    width: parent.width
                    text: Tail.selfName + I18n.t(" · questo dispositivo")
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                }
                Text {
                    text: Tail.selfIp
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                }
            }
            MButton {
                id: selfCopy
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 26
                icon: "edit-copy-symbolic"
                onClicked: Tail.copy(Tail.selfIp)
            }
        }

        SectionLabel { text: I18n.t("Macchine · %1 online su %2", Tail.onlineCount, Tail.peers.length) }

        Repeater {
            model: ScriptModel {
                values: Tail.peers.slice(0, 16)
                objectProp: "name"
            }

            Item {
                id: row
                required property var modelData
                width: parent.width
                height: 46
                opacity: modelData.online ? 1 : 0.5

                HoverHandler { id: hover }
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: hover.hovered ? Theme.cardHover : "transparent"
                }

                IconBadge {
                    id: badge
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 30
                    implicitHeight: 30
                    icon: root.osIcon(row.modelData.os)
                    active: row.modelData.online
                }
                Column {
                    anchors.left: badge.right
                    anchors.leftMargin: 10
                    anchors.right: actions.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        width: parent.width
                        text: row.modelData.name
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: row.modelData.online ? Font.DemiBold : Font.Normal
                    }
                    Text {
                        width: parent.width
                        text: row.modelData.ip
                        elide: Text.ElideRight
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                    }
                }
                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    MButton {
                        visible: row.modelData.canSend
                        implicitHeight: 26
                        icon: "document-send-symbolic"
                        onClicked: Tail.send(row.modelData)
                    }
                    MButton {
                        implicitHeight: 26
                        icon: "edit-copy-symbolic"
                        onClicked: Tail.copy(row.modelData.ip)
                    }
                }
            }
        }
    }

    Item {
        width: parent.width
        height: 26

        LinkText {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("Apri il pannello Tailscale…")
            onClicked: root.advanced()
        }
        MButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 26
            icon: "view-refresh-symbolic"
            onClicked: Tail.refresh()
        }
    }
}
