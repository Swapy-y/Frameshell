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
//  app's Experimental page) it only peeks out of the frame then (`peeking`: a
//  small block, the same size for every one of them - Theme.peekSize past the
//  frame each way - with a chevron in it pointing the way it opens, none of its
//  content showing yet); a click on it opens it all the way, until `hovering` ends.
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

    // Peeking (Click to expand) it is a small block of the same size whatever the panel:
    // Theme.peekSize past the frame each way - on a side it sits against, the frame's width
    // more (frameless, where it moves a frame's width off the screen: Theme.peekSize from
    // the edge of the screen). Never more than the open panel. Centred on an axis (the quick
    // note, the clipboard: up and down) it is Theme.peekLength long there - taller than the
    // corner blocks - and keeps the screen's odd/even-ness, like `w` / `h` below, so it sits
    // on whole pixels.
    readonly property real peekW: Math.min(w, attachLeft || attachRight ? Theme.peekSize + Theme.edge : Shapes.sameParity(Theme.peekLength, parent.width))
    readonly property real peekH: Math.min(h, attachTop ? Theme.peekSize + Theme.edge : (attachBottom ? Theme.peekSize : Shapes.sameParity(Theme.peekLength, parent.height)))
    // How far open it is across (pw) and down (ph): 0 = closed, 1 = fully open. Apart from
    // peeking the two are the same; peeking each is its own share of the panel, so the block
    // is peekW x peekH whatever shape the open panel has.
    property real pw: open ? 1 : (peeking ? peekW / Math.max(1, w) : 0)
    property real ph: open ? 1 : (peeking ? peekH / Math.max(1, h) : 0)
    Behavior on pw {
        PanelAnim {
            opening: root.open || root.peeking
        }
    }
    Behavior on ph {
        PanelAnim {
            opening: root.open || root.peeking
        }
    }
    // the larger of the two: how far it is out (peekP: the peek's share)
    readonly property real peekP: Math.max(peekW / Math.max(1, w), peekH / Math.max(1, h))
    readonly property real p: Math.max(pw, ph)

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
    readonly property real rw: w * pw
    readonly property real rh: h * ph
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
        readonly property real fadeFrom: root.clickToExpand ? Shapes.clamp(root.peekP, 0.3, 0.9) : 0.3
        opacity: Shapes.clamp((root.p - fadeFrom) / (1 - fadeFrom), 0, 1)
    }

    // Click to expand: a chevron in the middle of the peeking block (the part past the
    // frame), pointing the way the panel opens - into the screen, slanted from a corner - so
    // it is clear a click opens it. It fades in once the block is out and away as it opens.
    Icon {
        id: chevron
        readonly property real dx: root.attachLeft ? 1 : (root.attachRight ? -1 : 0)
        readonly property real dy: root.attachTop ? 1 : (root.attachBottom ? -1 : 0)
        // the middle of the block past the frame, measured from the sides it sits against
        // (so it stays put while the panel grows round it)
        readonly property real half: Theme.peekSize / 2
        readonly property real cx: root.attachLeft ? Theme.edge + half : (root.attachRight ? root.width - Theme.edge - half : root.width / 2)
        readonly property real cy: root.attachTop ? Theme.edge + half : (root.attachBottom ? root.height - half : root.height / 2)

        visible: root.clickToExpand && opacity > 0.01
        name: "chev-right"
        size: Theme.px(12)
        color: Config.frameColors.colorPickerIcon
        rotation: Math.atan2(dy, dx) * 180 / Math.PI
        x: Math.round(cx - size / 2)
        y: Math.round(cy - size / 2)
        opacity: root.peeking ? 1 : 0

        Behavior on opacity {
            Anim {
                duration: Theme.durSmall
            }
        }
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
