import QtQuick
import Quickshell
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  SignalIcon.qml - Signal / internet icon: 4 bars, the first `level` of them
//  lit, the rest grey.
//
//    level  0..4          size  height in pixels (about as wide)
//
//  The bars are drawn on whole screen pixels - every bar equally wide, every
//  gap equally wide, every bar the same step taller than the one before - so
//  the icon stays sharp and even when small (scaling the drawing of icons.js
//  down put the bars between two pixels: some crisp, some blurred).
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    property int level: 4
    property real size: 14
    property color color: Config.text
    property color dim: Config.iconDim

    // screen pixels per pixel (2 on a 4K screen at scale 2)
    readonly property real dpr: QsWindow.window && QsWindow.window.devicePixelRatio > 0 ? QsWindow.window.devicePixelRatio : 1

    // everything below in screen pixels, in the proportions of the drawing
    readonly property int s: Math.max(4, Math.round(size * dpr))
    readonly property int bar: Math.max(1, Math.round(s * 0.18))         // width of a bar
    readonly property int gap: Math.max(1, Math.round(s * 0.09))         // space between two bars
    readonly property int step: Math.max(1, Math.round(s * 0.18))   // each bar this much taller than the one before
    readonly property int lowest: Math.max(1, Math.min(Math.round(s * 0.37), s - 3 * step))
    readonly property int tallest: lowest + 3 * step
    readonly property int foot: Math.floor((s + tallest) / 2)       // where the bars stand (centred in the icon)

    // whole pixels wide, so whatever lines it up next to other items keeps the
    // bars on screen pixels
    width: Math.ceil((4 * bar + 3 * gap) / dpr)
    height: size

    Repeater {
        model: 4

        Rectangle {
            required property int index

            x: index * (root.bar + root.gap) / root.dpr
            width: root.bar / root.dpr
            height: (root.lowest + index * root.step) / root.dpr
            y: root.foot / root.dpr - height
            radius: width / 2
            color: root.level > index ? root.color : root.dim

            Behavior on color {
                CAnim {}
            }
        }
    }
}
