import QtQuick
import QtQuick.Shapes
import qs
import "icons.js" as IconData

// ═══════════════════════════════════════════════════════════════════════════
//  VolumeIcon.qml - Speaker with two sound waves. The waves that the volume
//  has not reached (or all of them when muted) are drawn grey.
//
//    level  0..1          muted  true = grey waves
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    property real level: 1
    property bool muted: false
    property real size: 24
    property color color: Config.text
    property color dim: Config.iconDim

    readonly property var parts: IconData.data["volume"]
    readonly property bool innerLit: !muted && level > 0.001
    readonly property bool outerLit: !muted && level > 0.5

    width: size
    height: size

    Shape {
        width: 100
        height: 100
        scale: root.size / 100
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        // speaker
        ShapePath {
            strokeWidth: -1
            fillColor: root.color
            fillRule: ShapePath.WindingFill
            PathSvg {
                path: root.parts[0]
            }
        }

        // inner wave
        ShapePath {
            strokeWidth: -1
            fillColor: root.innerLit ? root.color : root.dim
            fillRule: ShapePath.WindingFill
            Behavior on fillColor {
                CAnim {}
            }
            PathSvg {
                path: root.parts[1]
            }
        }

        // outer wave
        ShapePath {
            strokeWidth: -1
            fillColor: root.outerLit ? root.color : root.dim
            fillRule: ShapePath.WindingFill
            Behavior on fillColor {
                CAnim {}
            }
            PathSvg {
                path: root.parts[2]
            }
        }
    }
}
