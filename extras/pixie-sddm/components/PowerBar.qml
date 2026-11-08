/**
 * Pixie SDDM - PowerBar Component
 * Author: xCaptaiN09
 *
 * frameshell: every icon and label is centred on the row by its ink (the
 * visible shape) instead of its line box, so they sit exactly on the date's
 * line (Main.qml puts the row there).
 */
import QtQuick

Row {
    id: powerBarRoot
    spacing: 20
    height: 30

    property color textColor: "white"

    // empty space right of the last icon's ink, and the height of the tallest icon
    // (Main.qml makes the space right of the icons as big as the space above them)
    readonly property real rightInset: shutdownIcon.width - (shutdownIcon.inkRect.x + shutdownIcon.inkRect.width)
    readonly property real inkHeight: Math.max(suspendIcon.inkRect.height, restartIcon.inkRect.height, shutdownIcon.inkRect.height)

    FontLoader { id: iconFont; source: "../assets/fonts/MaterialDesignIcons.ttf" }

    // a Text whose ink, not its line box, is centred on its row
    component InkText: Text {
        id: inkText
        readonly property rect inkRect: ink.tightBoundingRect
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: height / 2 - baselineOffset - (inkRect.y + inkRect.height / 2)
        TextMetrics {
            id: ink
            font: inkText.font
            text: inkText.text
        }
    }

    // Battery (With forced live updates)
    Row {
        id: batteryRow
        spacing: 5
        visible: typeof battery !== "undefined" && typeof battery.percent !== "undefined"
        anchors.verticalCenter: parent.verticalCenter

        InkText {
            id: batteryText
            text: (typeof battery !== "undefined" ? battery.percent : "0") + "%"
            color: textColor
            font.pixelSize: 14
            font.weight: Font.Medium
        }
        InkText {
            id: batteryIcon
            text: (typeof battery !== "undefined" && battery.charging) ? "󱐋" : "󰁹"
            color: textColor
            font.pixelSize: 18
            font.family: iconFont.name
        }

        // Bulletproof Live Update: SDDM sometimes fails to emit battery signals,
        // so we force a check every 5 seconds.
        Timer {
            interval: 5000
            running: typeof battery !== "undefined" && battery.present
            repeat: true
            onTriggered: {
                batteryText.text = battery.percent + "%"
                batteryIcon.text = battery.charging ? "󱐋" : "󰁹"
            }
        }
    }

    // Keyboard Layout
    InkText {
        text: (typeof keyboard !== "undefined" && keyboard.layouts[keyboard.currentLayout]) ? keyboard.layouts[keyboard.currentLayout].shortName : "US"
        color: textColor
        font.pixelSize: 14
        font.capitalization: Font.AllUppercase
        visible: typeof keyboard !== "undefined" && keyboard.layouts.length > 1

        MouseArea {
            anchors.fill: parent
            onClicked: {
                keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
            }
        }
    }

    // Suspend
    InkText {
        id: suspendIcon
        text: "󰤄"
        color: textColor
        font.pixelSize: 20
        font.family: iconFont.name
        MouseArea {
            anchors.fill: parent
            onClicked: sddm.suspend()
        }
    }

    // Restart
    InkText {
        id: restartIcon
        text: "󰑐"
        color: textColor
        font.pixelSize: 20
        font.family: iconFont.name
        MouseArea {
            anchors.fill: parent
            onClicked: sddm.reboot()
        }
    }

    // Shutdown
    InkText {
        id: shutdownIcon
        text: "󰐥"
        color: textColor
        font.pixelSize: 20
        font.family: iconFont.name
        MouseArea {
            anchors.fill: parent
            onClicked: sddm.powerOff()
        }
    }
}
