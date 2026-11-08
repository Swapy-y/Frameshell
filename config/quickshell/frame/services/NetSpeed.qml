pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  NetSpeed.qml - network activity from /proc/net/dev and connection state
//  from /proc/net/route. Only the signal icon uses it (no speed text):
//  `level` is how many of its 4 bars light up.
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    property real rx: 0              // download, bytes/s
    property real tx: 0              // upload, bytes/s
    property bool connected: false   // there is a default route

    // 0 = offline, 1..4 = lit signal bars (activity based)
    readonly property int level: {
        if (!connected)
            return 0;
        const total = rx + tx;
        if (total >= 10 * 1024 * 1024)
            return 4;
        if (total >= 1024 * 1024)
            return 3;
        if (total >= 50 * 1024)
            return 2;
        return 1;
    }

    property double _lastTime: 0
    property double _lastRx: -1
    property double _lastTx: -1

    function parseDev(text) {
        const lines = text.split("\n");
        let rxSum = 0;
        let txSum = 0;
        for (let i = 2; i < lines.length; i++) {
            const line = lines[i];
            const colon = line.indexOf(":");
            if (colon < 0)
                continue;
            const name = line.slice(0, colon).trim();
            // skip loopback and virtual interfaces so traffic is not counted twice
            if (name === "lo" || /^(docker|veth|br-|virbr|vnet|tun|tap)/.test(name))
                continue;
            const f = line.slice(colon + 1).trim().split(/\s+/);
            rxSum += Number(f[0]) || 0;
            txSum += Number(f[8]) || 0;
        }

        const now = Date.now();
        if (_lastRx >= 0 && now > _lastTime) {
            const dt = (now - _lastTime) / 1000;
            const r = Math.max(0, (rxSum - _lastRx) / dt);
            const t = Math.max(0, (txSum - _lastTx) / dt);
            // light smoothing so the number does not flicker
            rx = rx * 0.35 + r * 0.65;
            tx = tx * 0.35 + t * 0.65;
        }
        _lastRx = rxSum;
        _lastTx = txSum;
        _lastTime = now;
    }

    function parseRoute(text) {
        const lines = text.split("\n");
        let found = false;
        for (let i = 1; i < lines.length; i++) {
            const f = lines[i].trim().split(/\s+/);
            // Iface Destination Gateway Flags ...  (flags & 1 = up)
            if (f.length > 3 && f[1] === "00000000" && (parseInt(f[3], 16) & 1)) {
                found = true;
                break;
            }
        }
        connected = found;
    }

    FileView {
        id: devFile
        path: "/proc/net/dev"
        printErrors: false
        onLoaded: root.parseDev(devFile.text())
    }

    FileView {
        id: routeFile
        path: "/proc/net/route"
        printErrors: false
        onLoaded: root.parseRoute(routeFile.text())
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            devFile.reload();
            routeFile.reload();
        }
    }
}
