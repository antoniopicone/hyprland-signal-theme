pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Server delle notifiche (org.freedesktop.Notifications).
// Funziona solo se il plugin notifiche di Omarchy è disattivato: il nome sul bus è uno solo.
Singleton {
    id: root

    property bool dnd: false
    property int unread: 0                 // si azzera aprendo il cassetto

    function markRead() { unread = 0; }
    property var popups: []                 // notifiche mostrate come banner
    property var history: []                // tutte quelle ancora aperte, dalla più vecchia
    property var times: ({})                // id -> Date di arrivo

    function toArray(list) {
        const out = [];
        for (let i = 0; i < list.length; i++) out.push(list[i]);
        return out;
    }

    function syncHistory() {
        history = toArray(server.trackedNotifications.values);
        if (history.length === 0) unread = 0;
    }
    function removePopup(n) { popups = popups.filter(p => p !== n); }

    // Uscita animata dal cassetto: si segnano come "in uscita", poi si chiudono davvero
    property var leaving: ({})
    property var pendingDismiss: []
    function isLeaving(n) { return !!n && leaving[n.id] === true; }
    function dismissAnimated(list) {
        const l = Object.assign({}, leaving);
        for (const n of list) l[n.id] = true;
        leaving = l;
        pendingDismiss = pendingDismiss.concat(list);
        leaveTimer.restart();
    }
    Timer {
        id: leaveTimer
        interval: 240
        onTriggered: {
            const list = root.pendingDismiss;
            root.pendingDismiss = [];
            root.leaving = ({});
            for (const n of list) n.dismiss();
        }
    }

    function clearAll() {
        dismissAnimated(history.slice());
        popups = [];
    }

    function timeOf(n) {
        const d = n ? times[n.id] : null;
        if (!d) return "";
        const mins = Math.floor((Date.now() - d.getTime()) / 60000);
        return mins < 1 ? I18n.t("ora") : mins < 60 ? I18n.t("%1 min fa", mins) : Qt.formatTime(d, "HH:mm");
    }

    function iconFor(n) {
        if (!n) return "";
        const pick = s => {
            if (!s) return "";
            if (s.startsWith("/")) return "file://" + s;
            if (s.indexOf(":/") >= 0) return s;
            return Quickshell.iconPath(s, true);
        };
        let fromEntry = "";
        const key = n.desktopEntry || n.appName;
        if (key) {
            const e = DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(key) : DesktopEntries.byId(key);
            if (e) fromEntry = e.icon;
        }
        return pick(n.image) || pick(n.appIcon) || pick(fromEntry) || Quickshell.iconPath("dialog-information", true);
    }

    function actionsOf(n) {
        return n ? toArray(n.actions) : [];
    }

    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            if (!Ui.notificationsOpen) root.unread++;
            root.times[n.id] = new Date();
            n.closed.connect(() => root.removePopup(n));

            // Teniamo al massimo 30 notifiche nello storico
            const tracked = server.trackedNotifications.values;
            if (tracked.length > 30) tracked[0].dismiss();

            const critical = n.urgency === NotificationUrgency.Critical;
            if (!root.dnd || critical)
                root.popups = [n].concat(root.popups).slice(0, Config.maxPopups);
        }
    }

    Connections {
        target: server.trackedNotifications
        function onValuesChanged() { root.syncHistory(); }
    }
}
