import QtQuick
import Quickshell
import Quickshell.Bluetooth

// ═══════════════════════════════════════════════════════════════════════════
//  BtBackend.qml - Bluetooth through BlueZ (Quickshell.Bluetooth).
//  Loaded by services/Net.qml; if this Quickshell has no Bluetooth module,
//  the load fails quietly and the popup says so.
//
//  `devices`: connected first, then paired ones, then new devices found while
//  the popup scans (only ones with a name). activate() connects, disconnects
//  or pairs (then trusts and connects).
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool blocked: available && adapter.state === BluetoothAdapterState.Blocked
    readonly property bool busy: available && (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling)

    function setEnabled(on) {
        if (!available)
            return;
        // a soft rfkill block (airplane mode) has to be lifted first
        if (on && blocked) {
            Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
            enableLater.restart();
            return;
        }
        adapter.enabled = on;
    }

    Timer {
        id: enableLater
        interval: 600
        onTriggered: {
            if (root.available)
                root.adapter.enabled = true;
        }
    }

    // true while the popup is open: look for new devices
    property bool scanning: false
    property bool _started: false      // the search is ours (another app may be searching too)
    function _applyScan() {
        if (!available || !enabled) {
            _started = false;
            return;
        }
        if (scanning && !adapter.discovering) {
            adapter.discovering = true;
            _started = true;
        } else if (!scanning && _started) {
            _started = false;
            if (adapter.discovering)
                adapter.discovering = false;
        }
    }
    onScanningChanged: {
        // a closed list forgets the last error
        if (!scanning) {
            errorDev = null;
            errorText = "";
        }
        _applyScan();
        refresh();
    }
    onEnabledChanged: _applyScan()
    onAdapterChanged: _applyScan()

    // ── the list ──────────────────────────────────────────────────────────
    readonly property var raw: available ? adapter.devices.values : []
    property var devices: []

    function known(d) {
        return d.paired || d.bonded;
    }
    function label(d) {
        return d.name && d.name.length > 0 ? d.name : (d.deviceName && d.deviceName.length > 0 ? d.deviceName : d.address);
    }
    // the shell's icon (components/icons.js) for the kind of device BlueZ reports
    function glyph(d) {
        const i = d.icon || "";
        if (i.startsWith("audio-headset") || i.startsWith("audio-headphones"))
            return "bt-headphones";
        if (i.startsWith("audio-card") || i.startsWith("audio-speakers"))
            return "bt-speaker";
        if (i.startsWith("input-mouse"))
            return "bt-mouse";
        if (i.startsWith("input-keyboard"))
            return "bt-keyboard";
        if (i.startsWith("input-gaming"))
            return "bt-gamepad";
        if (i.startsWith("phone"))
            return "bt-phone";
        if (i.startsWith("computer"))
            return "bt-laptop";
        return "bluetooth";
    }

    readonly property var connectedDevices: raw.filter(d => d.connected)
    readonly property bool connected: connectedDevices.length > 0

    // sorted on a timer and when devices come or go, so rows don't jump
    function refresh() {
        const list = raw.filter(d => d.connected || known(d) || (d.deviceName && d.deviceName.length > 0));
        list.sort((a, b) => {
            const ra = a.connected ? 0 : known(a) ? 1 : 2;
            const rb = b.connected ? 0 : known(b) ? 1 : 2;
            if (ra !== rb)
                return ra - rb;
            return label(a).localeCompare(label(b));
        });
        devices = list;
    }
    onRawChanged: refresh()
    onConnectedDevicesChanged: refresh()

    Timer {
        interval: 2500
        repeat: true
        running: root.scanning
        onTriggered: root.refresh()
    }

    // ── connecting / pairing ──────────────────────────────────────────────
    property var pairing: null         // being paired by a click in the list
    property var connecting: null      // being connected by a click in the list
    property var errorDev: null
    property string errorText: ""

    function _connect(d) {
        connecting = d;
        d.connect();
    }

    function busyDevice(d) {
        return d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting;
    }
    // what the popup shows on the right of a device
    function stateText(d) {
        return d.pairing ? "Pairing…" : d.state === BluetoothDeviceState.Connecting ? "Connecting…" : d.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…" : "";
    }

    // a click on a device
    function activate(d) {
        if (!d)
            return;
        errorDev = null;
        errorText = "";
        if (d.pairing) {
            d.cancelPair();
            pairing = null;
            return;
        }
        if (busyDevice(d))
            return;
        if (d.connected) {
            d.disconnect();
        } else if (known(d)) {
            _connect(d);
        } else {
            // new device: pair, then trust it (so it can reconnect by itself) and connect
            pairing = d;
            pairTimeout.restart();
            d.pair();
        }
    }

    function forget(d) {
        if (!d)
            return;
        if (pairing === d)
            pairing = null;
        if (connecting === d)
            connecting = null;
        errorDev = null;
        errorText = "";
        d.forget();
        refresh();
    }

    Connections {
        target: root.pairing

        // pairing ended without success (the device refused, or wants a PIN)
        function onPairingChanged() {
            const d = root.pairing;
            if (d && !d.pairing && !d.paired)
                pairCheck.restart();
        }
        function onPairedChanged() {
            const d = root.pairing;
            if (d && d.paired) {
                pairTimeout.stop();
                root.pairing = null;
                d.trusted = true;
                root._connect(d);
                root.refresh();
            }
        }
    }

    // a connection attempt that ended without a connection (device off, out of range)
    Connections {
        target: root.connecting

        function onStateChanged() {
            const d = root.connecting;
            if (!d || d.state === BluetoothDeviceState.Connecting)
                return;
            root.connecting = null;
            if (!d.connected) {
                root.errorDev = d;
                root.errorText = "Couldn't connect. Is it on and nearby?";
            }
        }
    }

    Timer {
        id: pairCheck
        interval: 1500
        onTriggered: {
            const d = root.pairing;
            if (d && !d.pairing && !d.paired) {
                pairTimeout.stop();
                root.pairing = null;
                root.errorDev = d;
                root.errorText = "Couldn't pair. Is it in pairing mode?";
            }
        }
    }

    Timer {
        id: pairTimeout
        interval: 30000
        onTriggered: {
            const d = root.pairing;
            if (d && !d.paired) {
                d.cancelPair();
                root.errorDev = d;
                root.errorText = "Couldn't pair. Is it in pairing mode?";
            }
            root.pairing = null;
        }
    }
}
