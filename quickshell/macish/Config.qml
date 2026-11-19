pragma Singleton
import Quickshell
import QtQuick

// Tutto ciò che ha senso personalizzare sta qui.
Singleton {
    // App fissate nel binario: id del file .desktop (senza estensione) o nome simile.
    readonly property var pinned: [
        "org.gnome.Nautilus",
        "firefox",
        "org.gnome.Ptyxis",
        "code",
        "org.gnome.TextEditor",
        "spotify"
    ]

    // Lingua dell'interfaccia: "auto" (segue LANG), "it" o "en"
    readonly property string language: "auto"

    // Temi Omarchy applicati cambiando aspetto (colori di terminale, zapfast e altre app).
    // Vuoti = cambia solo il color-scheme di GNOME. Nomi come in `omarchy-theme-list`.
    readonly property string lightTheme: "Segnale Chiaro"
    readonly property string darkTheme: "Segnale Scuro"

    // Parti della shell
    readonly property bool showBar: true          // barra in alto di Segnale (nasconde quella di Omarchy all'installazione)
    readonly property bool showWallpaper: true    // sfondo a puntini di Segnale
    readonly property bool wallpaperClock: true   // ora grande a puntini sullo sfondo
    readonly property bool manageIcons: true      // icone Segnale-Scuro / Segnale-Chiaro seguono l'aspetto
    readonly property bool manageAccent: false    // colore d'accento GNOME e bordo finestre seguono l'aspetto

    // Misure
    readonly property int barHeight: 44           // oltre il notch (40 px logici a scala 1.6)
    readonly property int notchHalf: 130          // mezza larghezza riservata al notch, al centro
    readonly property int railIcon: 40
    readonly property int ccWidth: 340
    readonly property int launcherWidth: 560

    // Notifiche
    readonly property int notifWidth: 360
    readonly property int notifTimeout: 5000
    readonly property int maxPopups: 3
    readonly property int historyItems: 3

    // OSD
    readonly property int osdTimeout: 1500

    // Comandi
    // Agenti
    readonly property bool agentBlink: true           // false = rosso fisso, senza lampeggio
    readonly property int agentNudgeAfter: 300         // secondi di attesa dopo cui il lampeggio ogni tanto accelera
    readonly property bool agentNotify: false          // notifica critica quando un agente chiede qualcosa
    readonly property bool agentWindowBorder: true     // bordo rosso sulla finestra dell'agente in attesa
    readonly property string agentCli: Quickshell.env("HOME") + "/.local/bin/agente"
    readonly property string newAgentCommand: "cd ~ && xdg-terminal-exec claude"

    readonly property string settingsCommand: "omarchy-shell shell summon antonio.menu '{\"menu\":\"setup\"}'"
    readonly property string networkPanelCommand: "omarchy-shell shell summon omarchy.network '{}'"
    readonly property string bluetoothPanelCommand: "omarchy-shell shell summon omarchy.bluetooth '{}'"
    readonly property string audioPanelCommand: "omarchy-shell shell summon omarchy.audio '{}'"
    readonly property string displayCommand: "omarchy-shell shell summon corico.monitor '{}'"
    readonly property string tailscaleCommand: "omarchy-shell shell summon omarchy.tailscale '{}'"
    readonly property string casaCommand: "omarchy-shell shell summon antoniopicone.home-control '{}'"
    readonly property string lockCommand: "loginctl lock-session"
    readonly property string suspendCommand: "systemctl suspend"
    readonly property int nightTemperature: 4000
    readonly property int dayTemperature: 6500     // "spento": hyprsunset ricorda l'ultima temperatura
}
