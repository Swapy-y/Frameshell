import QtQuick
import qs
import "shapes.js" as Shapes

// ═══════════════════════════════════════════════════════════════════════════
//  Panel.qml - base of every panel that grows out of the frame
//  (power menu, calendar, sliders, notification, note).
//
//  How to use it:
//    1. set `open` (true = shown)
//    2. set `contentW` / `contentH` to the size your content wants. They can
//       change at any time; the panel follows smoothly (that is what makes
//       panels grow and shrink with their content).
//    3. say which screen edges it touches with attachTop / Bottom / Left / Right
//    4. put your content inside - it is placed in a body of that size.
//
//  The panel places itself against the attached edges (centred on the others);
//  a panel can still override x / y.
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    required property Item fillLayer
    required property Item strokeLayer

    property bool open: false
    property real contentW: Theme.px(200)
    property real contentH: Theme.px(100)

    property bool attachTop: false
    property bool attachBottom: false
    property bool attachLeft: false
    property bool attachRight: false
    property real convexRadius: Theme.panelRadius

    // content goes into the body
    default property alias content: body.data

    // 0 = closed, 1 = fully open
    property real p: open ? 1 : 0
    Behavior on p {
        PanelAnim {
            opening: root.open
        }
    }

    // the size the panel is heading for; follows contentW / contentH smoothly.
    // Whole numbers at rest (sharp edges); a panel that is centred on an axis
    // also keeps the same odd/even-ness as the screen so it lands on whole pixels.
    property int resizeDuration: Theme.durOpen
    property real w: attachLeft || attachRight ? Math.round(contentW) : Shapes.sameParity(contentW, parent.width)
    property real h: attachTop || attachBottom ? Math.round(contentH) : Shapes.sameParity(contentH, parent.height)
    Behavior on w {
        Anim {
            curve: Theme.curveDecel
            duration: root.resizeDuration
        }
    }
    Behavior on h {
        Anim {
            curve: Theme.curveDecel
            duration: root.resizeDuration
        }
    }

    // The exact rectangle (fractional while animating). The shape is drawn from
    // this, so its edges glide smoothly. The item itself uses whole pixels.
    readonly property real rw: w * p
    readonly property real rh: h * p
    readonly property real rx: attachRight ? parent.width - rw : (attachLeft ? 0 : (parent.width - rw) / 2)
    readonly property real ry: attachBottom ? parent.height - rh : (attachTop ? 0 : (parent.height - rh) / 2)

    width: Math.round(rw)
    height: Math.round(rh)
    x: Math.round(rx)
    y: Math.round(ry)
    clip: true
    visible: p > 0.001

    Flap {
        target: root
        fx: root.rx
        fy: root.ry
        fw: root.rw
        fh: root.rh
        fillLayer: root.fillLayer
        strokeLayer: root.strokeLayer
        attachTop: root.attachTop
        attachBottom: root.attachBottom
        attachLeft: root.attachLeft
        attachRight: root.attachRight
        convexRadius: root.convexRadius
    }

    // The body has the full size, the panel only reveals part of it while
    // growing, so the content never reflows during the animation.
    // Its place on the screen is where it sits when the panel is fully open, so it
    // stays still while the panel grows around it. (Placing it inside the rounded
    // panel instead rounded twice, and a centred panel's content hopped by 1 px
    // near the end of the opening.)
    readonly property real bodyX: attachRight ? parent.width - w : (attachLeft ? 0 : (parent.width - w) / 2)
    readonly property real bodyY: attachBottom ? parent.height - h : (attachTop ? 0 : (parent.height - h) / 2)

    Item {
        id: body
        width: root.w
        height: root.h
        x: Math.round(root.bodyX) - root.x
        y: Math.round(root.bodyY) - root.y
        opacity: Shapes.clamp((root.p - 0.3) / 0.7, 0, 1)
    }
}
