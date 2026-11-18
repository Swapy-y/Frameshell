import QtQuick
import Quickshell
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  BatteryIcon.qml - Battery, drawn like Apple's: a rounded outline and the charge
//  (white; orange while charging, red when nearly empty) filling it from the left,
//  right up to it (full: one solid shape); a small round cap on the right. Built
//  from plain rectangles on whole pixels, so its thin lines stay sharp.
//  "Detailed battery icon" (Config.detailedBattery, off at first): a gap inside the
//  outline, and in it the charge as a rounded bar from the left.
//
//    level  0..1          size  width in pixels (the height follows: about half,
//                                or `bodyHeight`)
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    // the frame's colours inside the frame (Overlay.qml), else the theme's (Config.paletteFor)
    readonly property var pal: Config.paletteFor(QsWindow.window)

    property real level: 1
    property bool charging: false
    property real size: 24
    property color color: Config.text

    readonly property color litColor: charging ? root.pal.batteryCharging : (level < 0.15 ? root.pal.warning : color)

    // proportions of the drawing (at 24 px: a 21 x 11 body, a 2 px cap 1 px away;
    // 1 px outline, 1 px air, a 17 x 7 charge bar)
    readonly property real k: size / 24
    // (bigger, the lines stay as fine as in Apple's: about 7 % of the height)
    readonly property int line: Math.max(1, Math.round(0.7 * k))
    readonly property int air: Math.max(1, Math.round(0.6 * k))
    readonly property int capGap: Math.max(1, Math.round(k))
    readonly property int capW: Math.max(2, Math.round(2 * k))
    readonly property int capH: Math.max(3, Math.round(4 * k))
    readonly property int bodyW: Math.round(size) - capGap - capW
    // its height (a little under half its width); set it to match something beside it
    property int bodyHeight: Math.round(11 * k)
    readonly property int bodyH: bodyHeight
    readonly property int inset: line + air
    readonly property int barW: bodyW - 2 * inset
    readonly property int barH: bodyH - 2 * inset

    width: Math.round(size)
    height: bodyH

    readonly property bool seamless: !Config.detailedBattery
    readonly property real bodyRadius: Math.round(3 * root.k)

    // seamless: the charge is the body's own shape, cut off at the level
    Item {
        visible: root.seamless && width > 0
        width: root.level > 0.01 ? Math.max(2 * root.line, root.bodyW * Math.min(1, root.level)) : 0
        height: root.bodyH
        clip: true

        Behavior on width {
            Anim {}
        }

        Rectangle {
            width: root.bodyW
            height: root.bodyH
            radius: root.bodyRadius
            color: root.litColor
            antialiasing: true
        }
    }

    // the outline
    Rectangle {
        width: root.bodyW
        height: root.bodyH
        radius: root.bodyRadius
        color: "transparent"
        border.width: root.line
        border.color: root.color
        antialiasing: true
    }

    // the charge (at least a sliver while there is any), inside the gap
    Rectangle {
        visible: !root.seamless && width > 0
        x: root.inset
        y: root.inset
        height: root.barH
        width: root.level > 0.01 ? Math.max(Math.min(root.barH, 2 * root.k), root.barW * Math.min(1, root.level)) : 0
        radius: Math.max(1, Math.round(1.6 * root.k))
        color: root.litColor
        antialiasing: true

        Behavior on width {
            Anim {}
        }
    }

    // the cap: round on its right, flat against the body
    Item {
        x: root.bodyW + root.capGap
        y: Math.round((root.bodyH - root.capH) / 2)
        width: root.capW
        height: root.capH
        clip: true

        Rectangle {
            x: -width / 2
            width: 2 * root.capW
            height: root.capH
            radius: Math.min(width, height) / 2
            color: root.color
            antialiasing: true
        }
    }
}
