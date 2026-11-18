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
//
//  A panel that comes out when the pointer touches it (the sound / brightness
//  block, the quick note, the clipboard, the colour picker) sets `peekable` and,
//  instead of `open`, `hovering`: the pointer is on it or on its hot zone (or
//  something keeps it out - typing, a slider being dragged). It is open while
//  `hovering` is. With "Click to expand" (Config.clickToExpand, the Settings
//  app's Experimental page) it only peeks out of the frame then (`peeking`: its
//  smaller side stands peekDepth out of it, none of its content shows yet); a
//  click on it opens it all the way, until `hovering` ends.
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    required property Item fillLayer
    required property Item strokeLayer

    property bool peekable: false
    property bool hovering: false
    // Click to expand: a peeking panel was clicked (until `hovering` ends)
    property bool clicked: false
    onHoveringChanged: {
        if (!hovering)
            clicked = false;
    }
    readonly property bool clickToExpand: peekable && Config.clickToExpand
    property bool open: hovering && (!clickToExpand || clicked)
    readonly property bool peeking: hovering && clickToExpand && !clicked
    property real contentW: Theme.px(200)
    property real contentH: Theme.px(100)

    property bool attachTop: false
    property bool attachBottom: false
    property bool attachLeft: false
    property bool attachRight: false
    property real convexRadius: Theme.panelRadius

    // content goes into the body
    default property alias content: body.data

    // 0 = closed, 1 = fully open (peeking: peekP - its smaller side as long as
    // peekDepth: the frame's width and 14 px past it; frameless, where it moves a frame's
    // width off the screen, 14 px from the edge of the screen)
    readonly property real peekDepth: Theme.edge + Theme.px(14)
    readonly property real peekP: Math.min(0.45, peekDepth / Math.max(1, Math.min(w, h)))
    property real p: open ? 1 : (peeking ? peekP : 0)
    Behavior on p {
        PanelAnim {
            opening: root.open || root.peeking
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
    // Frameless (Theme.frameShift) the panel moves a frame's width out towards the left /
    // top / right edge it sits on - partly off the screen, like the island - so it keeps
    // the shape it has against the frame. (Not towards the bottom: that is the bar.)
    readonly property real shiftX: (attachRight ? Theme.frameShift : 0) - (attachLeft ? Theme.frameShift : 0)
    readonly property real shiftY: attachTop ? -Theme.frameShift : 0
    readonly property real rx: (attachRight ? parent.width - rw : (attachLeft ? 0 : (parent.width - rw) / 2)) + shiftX
    readonly property real ry: (attachBottom ? parent.height - rh : (attachTop ? 0 : (parent.height - rh) / 2)) + shiftY

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
    readonly property real bodyX: (attachRight ? parent.width - w : (attachLeft ? 0 : (parent.width - w) / 2)) + shiftX
    readonly property real bodyY: (attachBottom ? parent.height - h : (attachTop ? 0 : (parent.height - h) / 2)) + shiftY

    Item {
        id: body
        width: root.w
        height: root.h
        x: Math.round(root.bodyX) - root.x
        y: Math.round(root.bodyY) - root.y
        // (Click to expand: nothing of it while it only peeks - a small panel's peek is more
        // than 0.3 of it)
        readonly property real fadeFrom: root.clickToExpand ? Math.max(0.3, root.peekP) : 0.3
        opacity: Shapes.clamp((root.p - fadeFrom) / (1 - fadeFrom), 0, 1)
    }

    // Click to expand: the click that opens a peeking panel - over its content, which
    // does not show yet (and must not take the click). It takes no hover: the panel's
    // own HoverHandler (in its content) keeps seeing the pointer.
    MouseArea {
        anchors.fill: parent
        visible: root.peeking
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked = true
    }
}
