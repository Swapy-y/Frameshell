pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Notifs.qml - Notification daemon. Shows one card at a time (top-right
//  panel). While "Do not disturb" is active (Store.notificationsOn == false)
//  nothing is shown.
//
//  Every notification - also one that came in during "Do not disturb" - goes
//  into the history: the last 50, newest first (the Settings app shows them).
//  It is kept in ~/.local/state/quickshell/by-shell/<id>/notifications.json.
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    // ── the history ───────────────────────────────────────────────────────
    readonly property int historyMax: 50
    // { time (ms since 1970), appName, summary, body, icon (an icon name), image (a
    // picture file, "file://...") }, newest first
    property var history: []

    FileView {
        id: historyFile
        path: Quickshell.statePath("notifications.json")
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onLoaded: {
            try {
                const a = JSON.parse(text());
                if (Array.isArray(a))
                    root.history = a.filter(e => e && typeof e === "object" && typeof e.time === "number").slice(0, root.historyMax).map(e => Object.assign({}, e, root._picture(e.image || "", e.icon || "")));
            } catch (e) {
                root.history = [];
            }
        }
    }

    // saved a moment later, so a burst of notifications is one write
    Timer {
        id: historySave
        interval: 500
        onTriggered: historyFile.setText(JSON.stringify(root.history))
    }

    // what the history can show later: { image, icon }. A picture file stays a file (if it
    // is gone by then, the app's icon is shown, not Qt's "missing" pattern); an icon
    // (notify-send -i firefox) becomes its name; an image sent inside the notification is
    // gone with it.
    function _picture(image, icon) {
        const prefix = "image://icon/";
        if (image.startsWith(prefix)) {
            const ref = image.slice(prefix.length);
            if (ref.startsWith("/"))
                return { image: "file://" + ref, icon: icon };
            return { image: "", icon: icon.length > 0 ? icon : ref };
        }
        return { image: image.startsWith("file://") ? image : "", icon: icon };
    }

    function _remember(c) {
        // (a notification right at the start: the saved history is read first, so
        // it is added to, not written over)
        historyFile.text();
        const p = _picture(c.image, c.icon);
        root.history = [{
                time: Date.now(),
                appName: c.appName,
                summary: c.summary,
                body: c.body,
                icon: p.icon,
                image: p.image
            }].concat(root.history).slice(0, root.historyMax);
        historySave.restart();
    }

    function clearHistory() {
        historyFile.text();
        if (history.length === 0)
            return;
        history = [];
        historySave.restart();
    }

    // The card that is on screen right now (plain copy, safe after the real
    // notification object has been destroyed) or null.
    property var current: null
    property var _queue: []

    // a card is on screen or waiting to come (the colour picker block makes room)
    readonly property bool busy: current !== null || _queue.length > 0

    // How long a card stays, in ms. Apps send their wish in milliseconds and
    // Quickshell passes that number on as it is (its docs say seconds, so a
    // small number is read as seconds, in case that ever changes). 0 or -1 =
    // "up to the server": Config.notificationTimeout. Never shorter than 2 s,
    // never longer than 30 s (or your notificationTimeout, if that is longer),
    // so every card goes away on its own.
    function _timeoutMs(n) {
        const t = Number(n.expireTimeout);
        let ms;
        if (t > 0)
            ms = t < 100 ? t * 1000 : t;
        else
            ms = n.urgency === NotificationUrgency.Critical ? 12000 : Config.notificationTimeout;
        return Math.max(2000, Math.min(Math.max(30000, Config.notificationTimeout), Math.round(ms)));
    }

    function _take(n) {
        let icon = n.appIcon && n.appIcon.length > 0 ? n.appIcon : "";
        let image = n.image || "";
        // an icon given as a file (notify-send -i /path/picture.png, e.g. a
        // screenshot) is shown as that picture
        if (image.length === 0 && (icon.startsWith("/") || icon.startsWith("file://"))) {
            image = icon.startsWith("/") ? "file://" + icon : icon;
            icon = "";
        }
        return {
            ref: n,
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            icon: icon,
            image: image,
            urgency: n.urgency,
            timeout: root._timeoutMs(n),
            desktopEntry: n.desktopEntry || ""
        };
    }

    function _showNext() {
        if (current !== null || _queue.length === 0)
            return;
        const next = _queue[0];
        _queue = _queue.slice(1);
        current = next;
        life.interval = next.timeout;
        life.restart();
    }

    function _finish(dismissed) {
        life.stop();
        const c = current;
        current = null;
        if (c && c.ref) {
            try {
                if (dismissed)
                    c.ref.dismiss();
                else
                    c.ref.expire();
            } catch (e) {
            }
        }
        gap.restart();
    }

    function dismissCurrent() {
        if (current !== null)
            _finish(true);
    }

    // A click on the card: the app's "default" action if it has one (e.g. a
    // screenshot opens in the file manager, a chat jumps to the message),
    // otherwise the card is just dismissed.
    function activateCurrent() {
        const c = current;
        if (c === null)
            return;
        try {
            const acts = c.ref ? c.ref.actions : [];
            for (let i = 0; i < acts.length; i++) {
                if (acts[i].identifier === "default") {
                    const resident = c.ref.resident;
                    acts[i].invoke();
                    if (!resident)
                        c.ref = null;       // invoke() already closed it
                    break;
                }
            }
        } catch (e) {
        }
        _finish(true);
    }

    function pause() {
        life.stop();
    }

    function resume() {
        if (current !== null)
            life.restart();
    }

    Timer {
        id: life
        onTriggered: root._finish(false)
    }

    // short pause between two cards so the panel can fold away first
    Timer {
        id: gap
        interval: 320
        onTriggered: root._showNext()
    }

    NotificationServer {
        keepOnReload: false
        bodySupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: n => {
            const c = root._take(n);
            root._remember(c);
            if (!Store.notificationsOn)
                return;
            n.tracked = true;
            root._queue = root._queue.concat([c]);
            root._showNext();
        }
    }
}
