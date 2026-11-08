pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// ═══════════════════════════════════════════════════════════════════════════
//  Battery.qml - Battery. On a desktop (no battery) it always reports "full",
//  as in the concept.
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    readonly property var device: UPower.displayDevice

    readonly property bool present: device !== null && device.ready && device.isPresent

    // 0..1
    readonly property real level: present ? Math.max(0, Math.min(1, device.percentage)) : 1
    readonly property bool charging: present && device.state === UPowerDeviceState.Charging
}
