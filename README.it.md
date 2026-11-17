# macish · tema Segnale

[English](README.md) · **Italiano**

![Segnale: barra con il pallino dell'agente che respira, launcher e pannello rapido](docs/screenshot.png)

Il desktop come uno strumento di misura: superfici piene, valori e ora nel carattere a
puntini, etichette in monospazio e un solo colore di segnale per ciò che è attivo.
Due varianti: **scura** (nero, bianco carta, arancio-rosso) e **chiara** (palette Carta,
blu inchiostro, ombre nette). La variante segue l'aspetto di sistema
(`org.gnome.desktop.interface color-scheme`) e con lei cambiano icone, colore d'accento
GNOME, bordo delle finestre e sfondo.

Gira come istanza Quickshell separata (`qs -c macish`), accanto a `omarchy-shell`.

## Installazione

    unzip macish-segnale.zip && cd segnale
    ./install.sh                    # oppure: ./install.sh --keep-omarchy-bar

Requisiti: `quickshell` 0.2+, Qt 6.9+, Hyprland. Facoltativi: `nmcli`, `wpctl`,
`brightnessctl`, `bluetoothctl`, `hyprsunset`. I caratteri (Doto, Geist, Geist Mono)
vengono scaricati dal repository di Google Fonts.

Se avevi installato Brina, questo pacchetto lo sostituisce: per tornare indietro basta
rilanciare l'installer di Brina.

## Cosa installa

| Dove | Cosa |
|---|---|
| `~/.config/quickshell/macish` | Barra, binario (dock), launcher, pannello rapido con Wi-Fi/Bluetooth/Audio, notifiche, OSD, sfondo a puntini con l'ora |
| `~/.config/hypr/macish.lua` o `macish.conf` | Angoli, ombre, bordo, scorciatoie, tasti multimediali (Lua se usi `hyprland.lua`) |
| `~/.local/share/icons/Segnale-Scuro`, `Segnale-Chiaro` | Temi di icone con cartelle Tinta, 80+ tipi di file, dispositivi, cestino (il resto da Yaru) |
| `~/.local/bin/agente` | Stato degli agenti per il pannello; hook per Claude Code |
| `~/.local/share/fonts/brina` | Doto, Geist, Geist Mono |
| `~/.config/omarchy/shell.toml` | Ritocchi ai menu di Omarchy |

L'installer disattiva i plugin notifiche e OSD di Omarchy e ne nasconde la barra.

## Scorciatoie

| Tasti | Azione |
|---|---|
| Super + Spazio | Launcher |
| Super + Ctrl + C | Pannello rapido (anche clic su stato e ora nella barra) |
| Super + Ctrl + A | Agenti (anche clic su `AG` nella barra) |
| Super + Ctrl + M | Notifiche (anche clic sul pallino in alto a sinistra) |
| Super + Ctrl + N | Tema scuro / chiaro |
| Tasti volume, luminosità, microfono | OSD di Segnale |

## Notifiche

Il pallino in alto a sinistra, prima dei workspace, è la spia delle notifiche:

- **pieno, colore del testo**: niente da leggere;
- **rosso fisso**: notifiche non lette;
- **solo contorno**: Non disturbare attivo (rosso se nel frattempo è arrivato qualcosa).

Un clic apre il cassetto a sinistra: notifiche raggruppate per app (tre in vista, le altre
con "Altre N"), Cancella per gruppo o tutto, e Non disturbare in cima. Aprendolo, il
pallino torna del colore del testo. I banner compaiono in alto a sinistra
(non con Non disturbare, salvo quelli critici).

Regola dei colori: **rosso fisso** = c'è qualcosa da leggere, **rosso che lampeggia** =
qualcuno (un agente) aspetta te.

Il cassetto, il pannello rapido, il menu Agenti e il binario delle app condividono la
curvatura del launcher (angoli da 20 px).

## Agenti

La barra mostra `AG` con un puntino per agente: **bianco che respira** = lavora,
**rosso che lampeggia** = aspetta te, **grigio** = ha finito. Il numero del workspace
dove sta l'agente prende lo stesso puntino rosso. Il pannello (clic su `AG`, o
Super + Ctrl + A) elenca gli agenti con cartella, workspace, tempo, ultima azione e
attività degli ultimi 10 minuti.

Quando un agente chiede qualcosa:
- la spia lampeggia lenta (una volta al secondo) finché non apri il pannello o vai sulla
  sua finestra, poi resta rossa fissa finché non rispondi;
- arriva una notifica critica con "Vai al terminale" (passa anche con Non disturbare);
- il bordo della sua finestra diventa rosso;
- se aspetta da più di 5 minuti, ogni minuto la spia lampeggia veloce per qualche secondo.

**Claude Code** è collegato da solo: l'installer aggiunge gli hook in
`~/.claude/settings.json` (con backup). Per toglierli: `agente-hooks-claude --rimuovi`.

**Altri agenti**: lanciali con `agente avvia codex -- codex` (o qualsiasi comando).
Uno script può segnalare un'attesa con `agente attende ID "messaggio"`.
Tutto il resto: `agente --help`.

Le richieste di permesso si approvano nel terminale dell'agente: il pannello ti avvisa
e ti ci porta, ma non approva a distanza.

## Lingua

L'interfaccia è in italiano e inglese e segue `LANG` (`it_*` → italiano, altro → inglese). Per forzarla:
`readonly property string language: "it"` (o `"en"`) in `Config.qml`. Le traduzioni stanno in `I18n.qml`: per
aggiungere una lingua basta un'altra tabella. Anche `agente` segue `LANG` (o `MACISH_LANG`).

## Personalizzare

`~/.config/quickshell/macish/Config.qml`: app fissate, parti da mostrare (`showBar`,
`showWallpaper`, `wallpaperClock`), gestione di icone e accento, comandi.
Agenti: `agentBlink` (false = rosso fisso), `agentNudgeAfter`, `agentNotify`,
`agentWindowBorder`, `newAgentCommand`.
Colori in `Theme.qml`.

## Disinstallare

    ./uninstall.sh

## Se qualcosa non va

- `qs -c macish log` mostra gli errori QML.
- La barra di Omarchy è ancora visibile: `touch ~/.local/state/omarchy/toggles/bar-off && omarchy-restart-shell`.
- Notifiche doppie o assenti: `./replace-omarchy-osd.sh` e controlla `omarchy plugin list`.
- La spia degli agenti non si accende: controlla `agente lista` e che `~/.claude/settings.json` contenga gli hook.
- Il bordo della finestra attiva non cambia colore: con la configurazione Lua `hyprctl keyword`
  potrebbe non essere supportato.
