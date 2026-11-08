pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// ═══════════════════════════════════════════════════════════════════════════
//  Media.qml - Media controls for whatever is playing (Firefox, Spotify, mpv,
//  Vesktop ...).
//
//  Which player: the one that is playing; when several play, the one that
//  started last; when none plays, the one that played last (so pausing a video
//  and pressing play again goes back to that video, not to some other app).
//
//  Where it is: Quickshell reads a player's position only when it starts or
//  stops playing (or reports a jump), and guesses in between. Browsers often
//  don't report a jump - seeking on the page, the next video starting - so the
//  bar fell behind until you paused and played again. While the bar is on
//  screen (the island open) the real position is asked for every second.
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    readonly property var players: Mpris.players.values

    // D-Bus names of the players that played, the latest first
    property var recent: []

    function played(p) {
        if (!p)
            return;
        const name = p.dbusName;
        recent = [name].concat(recent.filter(n => n !== name)).slice(0, 20);
    }

    readonly property var player: {
        const list = players;
        const rank = p => {
            const i = recent.indexOf(p.dbusName);
            return i < 0 ? recent.length : i;
        };
        let best = null;
        // playing: the one that started last
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying && (best === null || rank(list[i]) < rank(best)))
                best = list[i];
        }
        if (best !== null)
            return best;
        // none playing: the one that played last
        for (let i = 0; i < list.length; i++) {
            if (recent.indexOf(list[i].dbusName) >= 0 && (best === null || rank(list[i]) < rank(best)))
                best = list[i];
        }
        if (best !== null)
            return best;
        // never played since the shell started: one with something loaded, else the first
        for (let i = 0; i < list.length; i++) {
            if (list[i].trackTitle !== "")
                return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }

    readonly property bool has: player !== null
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string title: player !== null ? player.trackTitle : ""
    readonly property string artist: player !== null ? player.trackArtist : ""
    // the cover, or the video's picture: a file:// or https:// address, "" if none
    readonly property string artUrl: player !== null ? player.trackArtUrl : ""
    // the app that plays ("Mozilla Firefox", "Spotify" ...)
    readonly property string playerName: player !== null ? player.identity : ""

    // a player starting to play becomes the one the controls are for
    Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property var modelData

            target: modelData

            function onIsPlayingChanged() {
                if (modelData.isPlaying)
                    root.played(modelData);
                if (modelData === root.player)
                    root.ask();                  // paused / playing: where exactly
            }

            Component.onCompleted: {
                if (modelData.isPlaying)
                    root.played(modelData);
            }
        }
    }

    // ── position ──────────────────────────────────────────────────────────
    // the island shows the bar (modules/Island.qml sets this)
    property bool shown: false
    onShownChanged: {
        if (shown)
            updateProgress();
    }

    // 0..1
    property real progress: 0

    // the last known position: `known` seconds at `knownAt` (ms), of player `knownFor`
    property real known: 0
    property real knownAt: 0
    property string knownFor: ""

    function remember(s) {
        known = Math.max(0, s);
        knownAt = Date.now();
        knownFor = player ? player.dbusName : "";
        updateProgress();
    }

    // seconds, now
    function seconds() {
        if (!player)
            return 0;
        if (knownFor !== player.dbusName)
            return player.position;
        const rate = player.rate > 0 ? player.rate : 1;
        return known + (playing ? (Date.now() - knownAt) / 1000 * rate : 0);
    }

    function updateProgress() {
        if (!player || !player.lengthSupported || player.length <= 0) {
            progress = 0;
            return;
        }
        progress = Math.max(0, Math.min(1, seconds() / player.length));
    }

    // ask the player itself where it is (busctl comes with systemd)
    function ask() {
        if (!player || !player.positionSupported || reader.running)
            return;
        reader.asked = player.dbusName;
        reader.startedAt = Date.now();
        reader.command = ["busctl", "--user", "--timeout=1", "get-property", player.dbusName, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Position"];
        reader.running = true;
    }

    Process {
        id: reader

        property string asked: ""
        property real startedAt: 0

        // answer: "x <microseconds>"
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /^x\s+(-?\d+)/.exec(text.trim());
                // (not if something newer came in meanwhile - a seek, play / pause)
                if (!m || !root.player || root.player.dbusName !== reader.asked || reader.startedAt < root.knownAt)
                    return;
                const rate = root.player.rate > 0 ? root.player.rate : 1;
                // it answered somewhere between asking and now: count from the middle
                const late = root.playing ? (Date.now() - reader.startedAt) / 2000 * rate : 0;
                root.remember(Number(m[1]) / 1000000 + late);
            }
        }
    }

    // a jump Quickshell heard about (a seek it was told of, a new track, play / pause)
    Connections {
        target: root.player

        function onPositionChanged() {
            if (root.player)
                root.remember(root.player.position);
        }

        function onTrackTitleChanged() {
            root.ask();
        }
    }

    onPlayerChanged: {
        if (player)
            remember(player.position);
        else
            progress = 0;
        ask();
    }

    // the real position every second while the bar is on screen
    Timer {
        interval: 1000
        repeat: true
        running: root.shown && root.has
        triggeredOnStart: true
        onTriggered: root.ask()
    }

    // move the bar along in between
    Timer {
        interval: 250
        repeat: true
        running: root.shown && root.playing
        onTriggered: root.updateProgress()
    }

    // ── controls ──────────────────────────────────────────────────────────
    function togglePlaying() {
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }

    function next() {
        if (player && player.canGoNext)
            player.next();
    }

    function previous() {
        if (player && player.canGoPrevious)
            player.previous();
    }

    function seekTo(fraction) {
        if (player && player.canSeek && player.positionSupported && player.length > 0) {
            const target = Math.max(0, Math.min(1, fraction)) * player.length;
            player.position = target;
            remember(target);
            settle.restart();
        }
    }

    // after a seek: check where the player really went
    Timer {
        id: settle
        interval: 400
        onTriggered: root.ask()
    }
}
