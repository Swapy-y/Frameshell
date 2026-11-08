import QtQuick
import QtQuick.Shapes
import qs
import "shapes.js" as Shapes

// ═══════════════════════════════════════════════════════════════════════════
//  Flap.qml - A dark panel that grows out of the frame and is merged into it
//  with concave "ears". The shape follows the rectangle (fx, fy, fw, fh) in
//  overlay coordinates - by default the rectangle of `target`, but a panel
//  can hand in exact fractional numbers so the edges glide instead of
//  stepping from pixel to pixel while it animates.
//
//  It is drawn into two shared layers of the overlay: all outlines go UNDER
//  all fills. That is what makes the panel seamless - the outline is only
//  visible on the outside of the merged silhouette, never between a panel and
//  the frame, and two shapes that touch overlap instead of meeting at an edge.
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    required property Item target       // panel item (x, y, width, height in overlay coordinates)
    required property Item fillLayer
    required property Item strokeLayer

    // which sides of `target` touch the screen edge / frame
    property bool attachTop: false
    property bool attachBottom: false
    property bool attachLeft: false
    property bool attachRight: false

    property real convexRadius: Theme.panelRadius
    property real earRadius: Theme.earRadius

    // where the frame's bottom edge is: the bar, or less while the dock hides
    // (Overlay.qml's fill layer says; auto hide)
    readonly property real frameBottom: fillLayer.frameBottom !== undefined ? fillLayer.frameBottom : Theme.bar

    // the rectangle to draw (exact, may be fractional)
    property real fx: target.x
    property real fy: target.y
    property real fw: target.width
    property real fh: target.height

    // empty while nothing sticks out of the frame yet
    readonly property string pathData: Shapes.flapPath({
        W: fillLayer.width,
        H: fillLayer.height,
        F: Theme.frame,
        B: frameBottom,
        x: fx,
        y: fy,
        w: fw,
        h: fh,
        top: attachTop,
        bottom: attachBottom,
        left: attachLeft,
        right: attachRight,
        rb: convexRadius,
        re: earRadius
    })
    readonly property bool shown: pathData.length > 0

    Shape {
        parent: root.strokeLayer
        x: 0
        y: 0
        width: root.strokeLayer.width
        height: root.strokeLayer.height
        visible: root.shown
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: Theme.border * 2     // half is hidden under the fill
            strokeColor: Config.outline
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: root.pathData
            }
        }
    }

    Shape {
        parent: root.fillLayer
        x: 0
        y: 0
        width: root.fillLayer.width
        height: root.fillLayer.height
        visible: root.shown
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: Config.frame
            PathSvg {
                path: root.pathData
            }
        }
    }
}
