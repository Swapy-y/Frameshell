pragma Singleton

import QtQuick
import Quickshell
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Net.qml - Wi-Fi and Bluetooth for the island and its popup.
//
//  The real work is in net/WifiBackend.qml (NetworkManager) and
//  net/BtBackend.qml (BlueZ). They are loaded here on their own, so a
//  Quickshell built without its network or Bluetooth module only loses that
//  part: `wifi` / `bt` stay null and the popup explains it.
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    readonly property var wifi: wifiLoader.item
    readonly property var bt: btLoader.item

    // true while the popup shows that page: scan for networks / devices
    property bool scanWifi: false
    property bool scanBt: false
    // true while the Settings app shows its Wi-Fi / Bluetooth page: scan there too
    property bool scanWifiSettings: false
    property bool scanBtSettings: false

    LazyLoader {
        id: wifiLoader
        active: true
        source: "net/WifiBackend.qml"
    }

    LazyLoader {
        id: btLoader
        active: true
        source: "net/BtBackend.qml"
    }

    Binding {
        target: root.wifi
        property: "scanning"
        value: root.scanWifi || root.scanWifiSettings
        when: root.wifi !== null
    }

    Binding {
        target: root.bt
        property: "scanning"
        value: root.scanBt || root.scanBtSettings
        when: root.bt !== null
    }
}
