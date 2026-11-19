import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris

// Pannello rapido Segnale. Si apre dalla barra o con:  qs -c macish ipc call cc toggle
Scope {
    id: root

    property bool open: false
    property double lastClosed: 0
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    property bool mapped: false     // finestra presente (resta finché finisce la dissolvenza)
    property bool reveal: false     // guida l'animazione

    // Sottopannelli: "" = pagina principale, oppure "wifi", "bluetooth", "audio"
    property string page: ""
    property string shownPage: ""   // resta caricata mentre si torna indietro

    function openPage(p) {
        shownPage = p;
        page = p;
    }

    function advanced(cmd) {
        open = false;
        Sys.sh(cmd);
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Connections {
        target: Ui
        function onToggleControlCenter() { root.toggle(); }
    }

    onOpenChanged: {
        Sys.active = open;
        Ui.controlCenterOpen = open;
        if (open) {
            hideTimer.stop();
            mapped = true;
            Qt.callLater(() => root.reveal = root.open);
        } else {
            reveal = false;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: Theme.animSlow
        onTriggered: {
            root.mapped = false;
            root.page = "";
            root.shownPage = "";
        }
    }


    function toggle() {
        // Se il clic che chiede l'apertura è lo stesso che ha appena chiuso il pannello, ignoralo.
        if (!open && Date.now() - lastClosed < 250) return;
        open = !open;
    }

    IpcHandler {
        target: "cc"
        function toggle(): void { root.toggle(); }
        function show(): void { root.open = true; }
        function hide(): void { root.open = false; }
        function wifi(): void { root.openPage("wifi"); root.open = true; }
        function bluetooth(): void { root.openPage("bluetooth"); root.open = true; }
        function audio(): void { root.openPage("audio"); root.open = true; }
        function tailscale(): void { root.openPage("tailscale"); root.open = true; }
        function casa(): void { root.openPage("casa"); root.open = true; }
        function schermo(): void { root.openPage("display"); root.open = true; }
    }

    PanelWindow {
        id: win

        readonly property int pad: 22   // margine trasparente per l'ombra

        visible: root.mapped
        screen: Sys.focusedScreen()
        color: "transparent"
        exclusiveZone: 0
        implicitWidth: Config.ccWidth + pad * 2
        implicitHeight: Math.max(content.implicitHeight, sub.item ? sub.item.implicitHeight : 0) + 24 + pad * 2

        anchors { top: true; right: true }

        WlrLayershell.namespace: "macish-cc"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: Region { item: panel }

        HyprlandFocusGrab {
            windows: [win]
            active: root.open
            onCleared: {
                root.lastClosed = Date.now();
                root.open = false;
            }
        }

        Glass {
            radius: 20
            id: panel
            x: win.pad
            y: win.pad - 14
            width: Config.ccWidth
            height: pages.height + 24
            focus: true
            Keys.onEscapePressed: {
                if (root.page !== "") root.page = "";
                else root.open = false;
            }

            opacity: root.reveal ? 1 : 0
            scale: root.reveal ? 1 : 0.96
            transformOrigin: Item.TopRight
            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

            Item {
                id: pages
                x: 12
                y: 12
                width: parent.width - 24
                height: root.page === "" ? content.implicitHeight : (sub.item ? sub.item.implicitHeight : 0)
                clip: true
                Behavior on height { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

            Column {
                id: content
                x: root.page === "" ? 0 : -(pages.width + 24)
                width: pages.width
                spacing: 10
                opacity: root.page === "" ? 1 : 0
                Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }

                // Ora, data e batteria
                Item {
                    width: parent.width
                    height: 60
                    ClockText {
                        x: 4
                        anchors.bottom: parent.bottom
                        pixelSize: 54
                        lineHeight: 0.85
                        date: clock.date
                    }
                    Column {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        Mono { anchors.right: parent.right; text: Qt.locale(I18n.locale).toString(clock.date, "ddd d MMM") }
                        Mono {
                            anchors.right: parent.right
                            visible: Sys.hasBattery
                            text: "Bat " + Math.round(Sys.batteryLevel * 100) + "%" + (Sys.charging ? I18n.t(" · in carica") : "")
                        }
                    }
                }

                // Moduli: acceso = pieno. La freccia apre il dettaglio.
                Grid {
                    width: parent.width
                    columns: 2
                    spacing: 8

                    MTile {
                        width: (content.width - 8) / 2
                        icon: Sys.wifiOn ? "network-wireless-signal-excellent-symbolic" : "network-wireless-offline-symbolic"
                        title: "Wi-Fi"
                        subtitle: Sys.wifiOn ? (Sys.wifiName !== "" ? Sys.wifiName : I18n.t("Non connesso")) : I18n.t("Spento")
                        active: Sys.wifiOn
                        expandable: true
                        onClicked: Sys.setWifi(!Sys.wifiOn)
                        onOpened: root.openPage("wifi")
                    }
                    MTile {
                        width: (content.width - 8) / 2
                        icon: Sys.btOn ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
                        title: "Bluetooth"
                        subtitle: !Sys.btOn ? I18n.t("Spento")
                                : Sys.btConnected.length > 0 ? (Sys.btConnected[0].name || Sys.btConnected[0].deviceName) : I18n.t("Acceso")
                        active: Sys.btOn
                        expandable: true
                        onClicked: Sys.setBluetooth(!Sys.btOn)
                        onOpened: root.openPage("bluetooth")
                    }
                    MTile {
                        width: (content.width - 8) / 2
                        icon: "network-vpn-symbolic"
                        title: "Tailscale"
                        subtitle: Tail.headline
                        active: Tail.running
                        expandable: true
                        onClicked: Tail.toggle()
                        onOpened: root.openPage("tailscale")
                    }
                    MTile {
                        width: (content.width - 8) / 2
                        icon: "video-display-symbolic"
                        title: I18n.t("Schermo")
                        subtitle: Math.round(Sys.brightness * 100) + "%" + (Disp.monitors.length > 0 ? " · " + Disp.monitors[0].scale + "×" : "")
                        active: false
                        expandable: true
                        onClicked: root.openPage("display")
                        onOpened: root.openPage("display")
                    }
                    MTile {
                        width: (content.width - 8) / 2
                        icon: Sys.micMuted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic"
                        title: I18n.t("Microfono")
                        subtitle: Sys.micMuted ? I18n.t("Muto") : I18n.t("Attivo")
                        active: !Sys.micMuted
                        onClicked: Sys.setMicMuted(!Sys.micMuted)
                    }
                    MTile {
                        width: (content.width - 8) / 2
                        icon: "night-light-symbolic"
                        title: I18n.t("Luce notturna")
                        subtitle: Sys.nightOn ? I18n.t("Accesa") : I18n.t("Spenta")
                        active: Sys.nightOn
                        onClicked: Sys.setNight(!Sys.nightOn)
                    }
                }

                // Ethernet: compare solo con il cavo collegato
                MTile {
                    width: content.width
                    visible: Sys.ethOn
                    icon: "network-wired-symbolic"
                    title: "Ethernet"
                    subtitle: [Sys.ethIp, Sys.ethSpeedText].filter(x => x !== "").join(" · ") || I18n.t("Connesso")
                    active: true
                }
                MTile {
                    width: content.width
                    icon: "user-home-symbolic"
                    title: I18n.t("Casa")
                    subtitle: Casa.headline
                    active: Casa.client.online && Casa.client.lightsOn > 0
                    expandable: true
                    onClicked: root.openPage("casa")
                    onOpened: root.openPage("casa")
                }

                // Volume e luminosità a puntini
                Card {
                    width: parent.width
                    title: I18n.t("Suono e luce")
                    chevron: true
                    onTitleClicked: root.openPage("audio")

                    MSlider {
                        width: parent.width
                        label: "Vol"
                        value: Sys.muted ? 0 : Sys.volume
                        onMoved: v => Sys.setVolume(v)
                    }
                    MSlider {
                        width: parent.width
                        label: I18n.t("Luce")
                        value: Sys.brightness
                        onMoved: v => Sys.setBrightness(v)
                    }
                }

                // In riproduzione
                Card {
                    width: parent.width
                    visible: root.player !== null
                    title: I18n.t("In riproduzione")

                    Item {
                        width: parent.width
                        height: 38
                        Column {
                            anchors.left: parent.left
                            anchors.right: controls.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                width: parent.width
                                text: root.player ? (root.player.trackTitle || I18n.t("Senza titolo")) : ""
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                text: root.player ? (root.player.trackArtist || "") : ""
                                visible: text !== ""
                                elide: Text.ElideRight
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }
                        }
                        Row {
                            id: controls
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            MButton { icon: "media-skip-backward-symbolic"; onClicked: if (root.player) root.player.previous() }
                            MButton {
                                hot: true
                                icon: root.player && root.player.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                                onClicked: if (root.player) root.player.togglePlaying()
                            }
                            MButton { icon: "media-skip-forward-symbolic"; onClicked: if (root.player) root.player.next() }
                        }
                    }
                }

                // Piede
                Item {
                    width: parent.width
                    height: 36
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        MButton {
                            icon: Theme.dark ? "weather-clear-night-symbolic" : "weather-clear-symbolic"
                            onClicked: Sys.setDark(!Theme.dark)
                        }
                        MButton { icon: "emblem-system-symbolic"; onClicked: root.advanced(Config.settingsCommand) }
                        MButton { icon: "system-lock-screen-symbolic"; onClicked: root.advanced(Config.lockCommand) }
                        MButton { primary: true; text: I18n.t("Sospendi"); onClicked: root.advanced(Config.suspendCommand) }
                    }
                }
            }

            Loader {
                id: sub
                x: root.page !== "" ? 0 : pages.width + 24
                width: pages.width
                opacity: root.page !== "" ? 1 : 0
                active: root.mapped && root.shownPage !== ""
                Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }

                sourceComponent: root.shownPage === "wifi" ? wifiPage
                               : root.shownPage === "bluetooth" ? btPage
                               : root.shownPage === "audio" ? audioPage
                               : root.shownPage === "tailscale" ? tailPage
                               : root.shownPage === "display" ? displayPage
                               : root.shownPage === "casa" ? casaPage : null
            }
            }
        }
    }

    Component {
        id: wifiPage
        WifiPage {
            onBack: root.page = ""
            onAdvanced: root.advanced(Config.networkPanelCommand)
        }
    }
    Component {
        id: btPage
        BluetoothPage {
            onBack: root.page = ""
            onAdvanced: root.advanced(Config.bluetoothPanelCommand)
        }
    }
    Component {
        id: tailPage
        TailscalePage {
            onBack: root.page = ""
            onAdvanced: root.advanced(Config.tailscaleCommand)
        }
    }
    Component {
        id: displayPage
        DisplayPage {
            onBack: root.page = ""
            onAdvanced: root.advanced(Config.displayCommand)
        }
    }
    Component {
        id: casaPage
        CasaPage {
            onBack: root.page = ""
            onAdvanced: root.advanced(Config.casaCommand)
        }
    }
    Component {
        id: audioPage
        AudioPage {
            onBack: root.page = ""
            onAdvanced: root.advanced(Config.audioPanelCommand)
        }
    }
}
