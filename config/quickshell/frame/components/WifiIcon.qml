import QtQuick
import QtQuick.Shapes
import qs
import "icons.js" as IconData

// ═══════════════════════════════════════════════════════════════════════════
//  WifiIcon.qml - the Wi-Fi icon with its arcs lit by signal strength
//  (the dot is always lit, then `level` of the 3 arcs, the rest grey).
//
//    level  0..3          size  width and height in pixels
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    property int level: 3
    property real size: 16
    property color color: Config.text
    property color dim: Config.iconDim

    readonly property var parts: IconData.data["wifi-arcs"]

    width: size
    height: size

    component Arc: ShapePath {
        required property int index
        strokeWidth: -1
        fillColor: index === 0 || root.level >= index ? root.color : root.dim
        fillRule: ShapePath.WindingFill

        Behavior on fillColor {
            CAnim {}
        }
    }

    Shape {
        width: 100
        height: 100
        scale: root.size / 100
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        Arc {
            index: 0
            PathSvg {
                path: root.parts[0]
            }
        }
        Arc {
            index: 1
            PathSvg {
                path: root.parts[1]
            }
        }
        Arc {
            index: 2
            PathSvg {
                path: root.parts[2]
            }
        }
        Arc {
            index: 3
            PathSvg {
                path: root.parts[3]
            }
        }
    }
}
