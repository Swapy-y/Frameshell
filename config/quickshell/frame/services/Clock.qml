pragma Singleton

import QtQuick
import Quickshell
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Clock.qml - the time and date strings used by the island and the bottom bar.
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    readonly property var date: clock.date

    // 12-hour mode shows 1:23 / 12:33 (no leading zero, no AM/PM). Qt's own "h"
    // format is 24-hour unless AM/PM is present, so the hour is worked out here.
    readonly property string time: timeOf(clock.date)
    function timeOf(d) {
        if (Config.clock24h)
            return Qt.formatDateTime(d, "HH:mm");
        const h = d.getHours() % 12 === 0 ? 12 : d.getHours() % 12;
        return h + ":" + String(d.getMinutes()).padStart(2, "0");
    }
    // 10/14/2026
    readonly property string dateNumeric: Qt.formatDateTime(clock.date, "MM/dd/yyyy")
    // thu, oct 14
    readonly property string dateWords: Qt.formatDateTime(clock.date, "ddd, MMM d").toLowerCase()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
