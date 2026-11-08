import QtQuick
import Quickshell
import Quickshell.Networking

// ═══════════════════════════════════════════════════════════════════════════
//  WifiBackend.qml - Wi-Fi through NetworkManager (Quickshell.Networking).
//  Loaded by services/Net.qml; if this Quickshell has no network module, the
//  load fails quietly and the popup says so.
//
//  The popup reads `networks` (sorted: connected, known, then by signal) and
//  calls activate() / submit() / forget(). A network that needs a password
//  sets `askNet`; a failed attempt sets `errorNet` + `errorText`.
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    readonly property bool running: Networking.backend === NetworkBackendType.NetworkManager

    // the first Wi-Fi device, and whether a cable is plugged in
    readonly property var allDevices: Networking.devices.values
    readonly property var device: {
        const d = allDevices;
        for (let i = 0; i < d.length; i++) {
            if (d[i].type === DeviceType.Wifi)
                return d[i];
        }
        return null;
    }
    readonly property bool wiredConnected: {
        const d = allDevices;
        for (let i = 0; i < d.length; i++) {
            if (d[i].type === DeviceType.Wired && d[i].connected)
                return true;
        }
        return false;
    }

    readonly property bool enabled: Networking.wifiEnabled
    readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled
    function setEnabled(on) {
        Networking.wifiEnabled = on;
    }

    // true while the popup is open: the device keeps scanning for networks
    property bool scanning: false
    function _applyScan() {
        if (device)
            device.scannerEnabled = scanning && enabled;
    }
    onScanningChanged: {
        // a closed list forgets a half-typed password and the last error
        if (!scanning) {
            askNet = null;
            clearError();
        }
        _applyScan();
        refresh();
    }
    onEnabledChanged: _applyScan()
    onDeviceChanged: _applyScan()

    // ── the list ──────────────────────────────────────────────────────────
    readonly property var raw: device ? device.networks.values : []
    property var networks: []
    readonly property var current: {
        const n = raw;
        for (let i = 0; i < n.length; i++) {
            if (n[i].connected)
                return n[i];
        }
        return null;
    }
    readonly property bool connected: current !== null

    // 0..3 lit arcs for a signal strength of 0..1
    function level(strength) {
        return strength >= 0.66 ? 3 : strength >= 0.4 ? 2 : strength >= 0.15 ? 1 : 0;
    }

    // Sorted on a timer and when networks come or go (not on every signal
    // change), so rows don't jump while you aim at one; frozen while a
    // password is being typed.
    function refresh() {
        if (askNet !== null && raw.indexOf(askNet) >= 0)
            return;
        const list = raw.filter(n => n.name && n.name.length > 0);
        list.sort((a, b) => {
            const ra = a.connected ? 0 : a.stateChanging ? 1 : a.known ? 2 : 3;
            const rb = b.connected ? 0 : b.stateChanging ? 1 : b.known ? 2 : 3;
            if (ra !== rb)
                return ra - rb;
            return b.signalStrength - a.signalStrength;
        });
        networks = list;
    }
    onRawChanged: refresh()
    onCurrentChanged: refresh()

    Timer {
        interval: 2500
        repeat: true
        running: root.scanning
        onTriggered: root.refresh()
    }

    // ── connecting ────────────────────────────────────────────────────────
    property var askNet: null          // waiting for a password
    property var pskNet: null          // a password was just sent to it
    property var errorNet: null
    property string errorText: ""

    function isOpen(net) {
        return net.security === WifiSecurityType.Open || net.security === WifiSecurityType.Owe;
    }
    // WPA / WPA2 / WPA3 personal. "Unknown" counts too: a network that is not open
    // but not recognised (WPA3-only ones, for example) takes a password as well.
    function usesPassword(net) {
        return net.security === WifiSecurityType.WpaPsk || net.security === WifiSecurityType.Wpa2Psk || net.security === WifiSecurityType.Sae || net.security === WifiSecurityType.Unknown;
    }
    function secured(net) {
        return !isOpen(net);
    }

    function clearError() {
        errorNet = null;
        errorText = "";
    }

    // a click on a network
    function activate(net) {
        if (!net || net.stateChanging)
            return;
        clearError();
        if (net.connected) {
            net.disconnect();
            return;
        }
        if (net.known || isOpen(net)) {
            askNet = null;
            net.connect();
            return;
        }
        if (usesPassword(net)) {
            askNet = askNet === net ? null : net;
            if (askNet === null)
                refresh();
            return;
        }
        errorNet = net;
        errorText = "Needs a sign-in: set it up with nmtui";
    }

    function submit(net, password) {
        if (!net || password.length === 0)
            return;
        clearError();
        pskNet = net;
        askNet = null;
        net.connectWithPsk(password);
        refresh();
    }

    function cancelAsk() {
        askNet = null;
        refresh();
    }

    function forget(net) {
        if (!net)
            return;
        if (askNet === net)
            askNet = null;
        clearError();
        net.forget();
        refresh();
    }

    function _failed(net, reason) {
        const afterPassword = pskNet === net;
        pskNet = null;
        if (reason === ConnectionFailReason.NoSecrets || (afterPassword && reason !== ConnectionFailReason.WifiNetworkLost)) {
            // ask (again) for the password
            askNet = usesPassword(net) ? net : null;
            errorNet = net;
            errorText = afterPassword ? "Wrong password" : (usesPassword(net) ? "" : "Needs a sign-in: set it up with nmtui");
        } else {
            errorNet = net;
            errorText = reason === ConnectionFailReason.WifiNetworkLost ? "The network went away" : reason === ConnectionFailReason.WifiAuthTimeout ? "No answer from the network" : "Couldn't connect";
        }
        refresh();
    }

    // listen to every network's failures
    Variants {
        model: root.raw

        Connections {
            required property var modelData
            target: modelData

            function onConnectionFailed(reason) {
                root._failed(modelData, reason);
            }
            function onConnectedChanged() {
                if (modelData.connected && root.errorNet === modelData)
                    root.clearError();
            }
        }
    }
}
