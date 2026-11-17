import QtQuick

// Dettaglio Casa: scene, stanze con luci e dispositivi, climatizzatori (Home Assistant).
Column {
    id: root
    signal back()
    signal advanced()
    spacing: 10

    readonly property var ha: Casa.client
    readonly property var structure: ha.structure
    readonly property var ents: ha.entities

    readonly property var modeNames: ({
        cool: I18n.t("Freddo"), heat: I18n.t("Caldo"), dry: I18n.t("Deumidifica"), fan_only: I18n.t("Ventola"),
        auto: "Auto", heat_cool: "Auto", off: I18n.t("Spento")
    })

    function lightsOnIn(room) {
        let n = 0;
        for (const id of room.lights) if (ents[id] && ents[id].on) n++;
        return n;
    }

    function lightSub(v) {
        if (!v) return "";
        if (!v.available) return I18n.t("Non disponibile");
        if (!v.on) return I18n.t("Spenta");
        return v.dim ? Math.round(v.brightness * 100) + "%" : I18n.t("Accesa");
    }

    function climateSub(v) {
        if (!v) return "";
        if (!v.available) return I18n.t("Non disponibile");
        if (!v.on) return I18n.t("Spento") + (v.current !== null ? " · " + v.current + "°" : "");
        const parts = [modeNames[v.mode] || v.mode];
        if (v.current !== null) parts.push(v.current + "°");
        if (v.target !== null) parts.push("→ " + v.target + "°");
        return parts.join(" · ");
    }

    SubHeader {
        width: parent.width
        title: I18n.t("Casa")
        onBack: root.back()

        MButton {
            implicitHeight: 30
            visible: root.ha.online && root.ha.lightsOn > 0
            icon: "weather-clear-night-symbolic"
            text: I18n.t("Spegni tutto")
            onClicked: root.ha.allLightsOff()
        }
    }

    Card {
        width: parent.width

        Text {
            width: parent.width
            leftPadding: 6
            text: Casa.headline
            wrapMode: Text.WordWrap
            color: root.ha.online ? Theme.text : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
        }
    }

    // Scene
    Card {
        width: parent.width
        visible: root.ha.online && root.structure.scenes.length > 0
        title: I18n.t("Scene")

        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: root.structure.scenes
                MButton {
                    required property var modelData
                    implicitHeight: 28
                    hot: root.ha.activeScene === modelData.id
                    icon: "media-playback-start-symbolic"
                    text: modelData.name
                    onClicked: root.ha.activateScene(modelData.id)
                }
            }
        }
    }

    // Stanze
    Repeater {
        model: root.ha.online ? root.structure.rooms : []

        Card {
            id: roomCard
            required property var modelData
            width: root.width
            title: (modelData.name !== "" ? modelData.name : I18n.t("Altro"))
                   + (root.lightsOnIn(modelData) > 0 ? " · " + root.lightsOnIn(modelData) + I18n.t(" accese") : "")
            chevron: false

            Repeater {
                model: roomCard.modelData.lights
                DeviceRow {
                    required property string modelData
                    readonly property var v: root.ents[modelData] || null
                    width: roomCard.width - 24
                    icon: "display-brightness-symbolic"
                    title: v ? v.name : modelData
                    subtitle: root.lightSub(v)
                    active: v ? v.on : false
                    onClicked: root.ha.toggleLight(modelData)
                }
            }
            Repeater {
                model: roomCard.modelData.devices
                DeviceRow {
                    required property string modelData
                    readonly property var v: root.ents[modelData] || null
                    width: roomCard.width - 24
                    icon: "system-shutdown-symbolic"
                    title: v ? v.name : modelData
                    subtitle: v ? (v.available ? (v.on ? I18n.t("Acceso") : I18n.t("Spento")) : I18n.t("Non disponibile")) : ""
                    active: v ? v.on : false
                    onClicked: root.ha.toggleDevice(modelData)
                }
            }
            Repeater {
                model: roomCard.modelData.climates
                Item {
                    id: ac
                    required property string modelData
                    readonly property var v: root.ents[modelData] || null
                    width: roomCard.width - 24
                    height: 46

                    HoverHandler { id: acHover }
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: acHover.hovered ? Theme.cardHover : "transparent"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.ha.setClimate(ac.modelData, { on: !(ac.v && ac.v.on) })
                    }
                    IconBadge {
                        id: acBadge
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 30
                        implicitHeight: 30
                        icon: "weather-windy-symbolic"
                        active: ac.v ? ac.v.on : false
                    }
                    Column {
                        anchors.left: acBadge.right
                        anchors.leftMargin: 10
                        anchors.right: acBtns.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            width: parent.width
                            text: ac.v ? ac.v.name : ac.modelData
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: ac.v && ac.v.on ? Font.DemiBold : Font.Normal
                        }
                        Text {
                            width: parent.width
                            text: root.climateSub(ac.v)
                            elide: Text.ElideRight
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                    Row {
                        id: acBtns
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        visible: ac.v && ac.v.on && ac.v.target !== null
                        MButton { implicitHeight: 26; icon: "list-remove-symbolic"; onClicked: root.ha.stepClimate(ac.modelData, -1) }
                        MButton { implicitHeight: 26; icon: "list-add-symbolic"; onClicked: root.ha.stepClimate(ac.modelData, 1) }
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
            text: I18n.t("Apri pianta e dettagli luce…")
            onClicked: root.advanced()
        }
    }
}
