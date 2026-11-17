pragma Singleton
import Quickshell
import QtQuick

// Localizzazione / localization. Le stringhe nel codice sono in italiano e fanno da chiave;
// `t("testo")` restituisce la traduzione inglese quando la lingua è "en".
// Segnaposto: t("%1 min fa", 5). Lingua: Config.language ("auto", "it", "en").
Singleton {
    readonly property string lang: {
        if (Config.language === "it" || Config.language === "en") return Config.language;
        const l = (Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "").toLowerCase();
        return l.indexOf("it") === 0 ? "it" : "en";
    }
    readonly property string locale: lang === "it" ? "it_IT" : "en_US"

    function t(s) {
        let r = s;
        if (lang !== "it" && en[s] !== undefined) r = en[s];
        for (let i = 1; i < arguments.length; i++) r = r.split("%" + i).join(arguments[i]);
        return r;
    }

    readonly property var en: ({
        // Agenti
        "Agente": "Agent", "Attende": "Waiting", "Lavora": "Working", "Finito": "Done", "Errore": "Error",
        "Chiede la tua conferma": "Needs your confirmation", "Vai al terminale": "Go to terminal",
        "Più tardi": "Later", "Vai": "Go", "Chiudi": "Close",
        "%1 · %2 attende": "%1 · %2 is waiting",
        "AGENTI": "AGENTS", "nessuno attivo": "none active", "tutti fermi": "all idle",
        "%1 lavora": "%1 working", "%1 lavorano": "%1 working",
        "%1 attende": "%1 waiting", "%1 attendono": "%1 waiting",
        "Avvia Claude Code in un terminale (con gli hook installati) oppure un altro agente con  agente avvia <nome> -- <comando>: comparirà qui.":
            "Start Claude Code in a terminal (with the hooks installed) or another agent with  agente avvia <name> -- <command>: it will show up here.",
        "+ Nuovo agente": "+ New agent", "Pulisci finiti": "Clear finished", "Nuovo agente": "New agent",
        // Audio
        "Uscita": "Output", "Ingresso": "Input", "Disattivato": "Muted", "Applicazioni": "Applications",
        "Impostazioni audio…": "Audio settings…",
        // Bluetooth
        "Associazione…": "Pairing…", "Connessione…": "Connecting…", "Disconnessione…": "Disconnecting…",
        "Connesso": "Connected", " · batteria ": " · battery ", "Non connesso": "Not connected",
        "I miei dispositivi": "My devices", "Dimentica": "Forget",
        "Altri dispositivi · ricerca…": "Other devices · scanning…", "Altri dispositivi": "Other devices",
        "Nessun dispositivo trovato nelle vicinanze": "No devices found nearby",
        "Impostazioni Bluetooth…": "Bluetooth settings…",
        // Casa
        "Non configurata": "Not configured", "Token non valido": "Invalid token", "Non raggiungibile": "Unreachable",
        "%1 luci accese su %2": "%1 of %2 lights on", "Tutte le luci spente": "All lights off",
        "Freddo": "Cool", "Caldo": "Heat", "Deumidifica": "Dry", "Ventola": "Fan",
        "Spento": "Off", "Non disponibile": "Unavailable", "Spenta": "Off", "Accesa": "On", "Acceso": "On",
        "Casa": "Home", "Spegni tutto": "Turn all off", "Scene": "Scenes", "Altro": "Other", " accese": " on",
        "Apri pianta e dettagli luce…": "Open floor plan and light details…",
        // Pannello rapido
        " · in carica": " · charging", "Schermo": "Display", "Microfono": "Microphone", "Muto": "Muted",
        "Attivo": "On", "Luce notturna": "Night light", "Suono e luce": "Sound and light", "Luce": "Bri",
        "In riproduzione": "Now playing", "Senza titolo": "Untitled", "Sospendi": "Suspend",
        // Schermo
        "Orizzontale": "Landscape", "Verticale 90°": "Portrait 90°", "Capovolto": "Flipped", "Verticale 270°": "Portrait 270°",
        "Luminosità": "Brightness", "Scala": "Scale", "Orientamento": "Orientation",
        "Altre impostazioni dello schermo…": "More display settings…",
        // Launcher
        "Pannello rapido": "Quick panel", "Azione": "Action", "Passa al tema chiaro": "Switch to light theme",
        "Passa al tema scuro": "Switch to dark theme", "Aspetto": "Appearance",
        "Agenti · %1 in attesa": "Agents · %1 waiting", "Agenti": "Agents",
        "Notifiche · da leggere": "Notifications · unread", "Notifiche": "Notifications",
        "Disattiva Non disturbare": "Turn off Do Not Disturb", "Attiva Non disturbare": "Turn on Do Not Disturb",
        "Blocca schermo": "Lock screen", "Cerca app e azioni": "Search apps and actions",
        "Fissate e azioni": "Pinned and actions", "Risultati": "Results", "Nessun risultato": "No results",
        "↵ Apri": "↵ Open", "↑↓ Scegli": "↑↓ Select", "Esc Chiudi": "Esc Close",
        // Rete
        "Password errata": "Wrong password", "Connessione non riuscita": "Connection failed",
        "Connesso · ": "Connected · ", "Rete aziendale: apri le impostazioni di rete": "Enterprise network: open network settings",
        "Salvata": "Saved", "Ricerca delle reti…": "Scanning for networks…", "Altre reti": "Other networks",
        "Disconnetti": "Disconnect", "Password per ": "Password for ", "Impostazioni di rete…": "Network settings…",
        "Password": "Password", "Connetti": "Connect",
        // Notifiche
        "Sistema": "System", "NOTIFICHE": "NOTIFICATIONS", "%1 in tutto": "%1 total", "nessuna": "none",
        "Non disturbare": "Do Not Disturb", "Tutto letto.": "All caught up.", "Mostra meno": "Show less",
        "Altre %1": "%1 more", "Cancella": "Clear", "Cancella tutto": "Clear all",
        "ora": "now", "%1 min fa": "%1 min ago",
        // OSD
        "Audio disattivato": "Sound off", "Volume": "Volume", "Microfono disattivato": "Microphone off", "Microfono attivo": "Microphone on",
        // Tailscale
        "Accesso richiesto": "Login required", "Controllo dello stato…": "Checking status…",
        "Accesso richiesto: esegui «tailscale up» in un terminale.": "Login required: run “tailscale up” in a terminal.",
        "Tailscale è spento.": "Tailscale is off.", " · questo dispositivo": " · this device",
        "Macchine · %1 online su %2": "Machines · %1 online of %2", "Apri il pannello Tailscale…": "Open the Tailscale panel…",
        "workspace ": "workspace "
    })
}
