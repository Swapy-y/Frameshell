import QtQuick
import QtQuick.Shapes
import qs
import "icons.js" as IconData

// ═══════════════════════════════════════════════════════════════════════════
//  BatteryIcon.qml - Battery: the whole shape is grey, the charged part is
//  drawn over it in white (orange while charging, red when nearly empty).
//
//    level  0..1          size  width in pixels (the height follows the shape)
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    property real level: 1
    property bool charging: false
    property real size: 24
    property color color: Config.text
    property color dim: Config.iconDim

    readonly property color litColor: charging ? Config.accent : (level < 0.15 ? Config.warning : color)
    readonly property var parts: IconData.data["battery"]

    // geometry of the icon on its 100 x 100 grid
    readonly property real gridTop: 28.58        // the shape starts 28.58 down ...
    readonly property real gridH: 42.84     // ... and is 42.84 tall
    readonly property real gridBodyW: 90.3       // the little terminal on the right starts here
    readonly property real k: size / 100

    // width of the lit part, in grid units (the terminal lights up when full)
    readonly property real litW: level >= 0.985 ? 100 : (level > 0.01 ? Math.max(8, level * gridBodyW) : 0)

    width: size
    height: gridH * k

    component Body: Shape {
        id: shape
        property color fill
        y: -root.gridTop * root.k
        width: 100
        height: 100
        scale: root.k
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: shape.fill
            fillRule: ShapePath.WindingFill
            PathSvg {
                path: root.parts[0]
            }
        }
    }

    Body {
        fill: root.dim
    }

    Item {
        width: root.litW * root.k
        height: parent.height
        clip: true
        visible: width > 0

        Behavior on width {
            Anim {}
        }

        Body {
            fill: root.litColor
        }
    }
}
