import QtQuick
import QtQuick.Shapes
import Quickshell
import qs
import "icons.js" as IconData

// ═══════════════════════════════════════════════════════════════════════════
//  Icon.qml - One of the shell's own icons (path data lives in icons.js),
//  tintable.
//
//    name   icon name, e.g. "power", "bell", "play"   (see icons.js for the list)
//    color  fill colour
//    size   width and height in pixels
//
//  Icons made of long straight lines ("logout") are drawn on whole screen
//  pixels instead, so they stay sharp and even when small (icons.js, sharp()).
//  Those and the ones with long slanted edges ("bluetooth") are drawn 4 x as
//  big and scaled down, so their edges come out smooth and even.
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    property string name: "power"
    property color color: Config.text
    property real size: 24

    readonly property var parts: IconData.data[name] || []

    // screen pixels per pixel (2 on a 4K screen at scale 2)
    readonly property real dpr: QsWindow.window && QsWindow.window.devicePixelRatio > 0 ? QsWindow.window.devicePixelRatio : 1
    // the sharp version for this size, "" if the icon has none
    readonly property string sharpPath: IconData.sharp(name, size * dpr)
    // drawn 4 x as big and scaled down (smooth slanted edges)
    // (the Settings app's icons too: the curve renderer left a light dot in the
    // middle of "set-island"'s top edge)
    readonly property bool smoothEdges: ["bluetooth", "chev-left", "chev-right", "search", "set-island", "set-dock", "set-wallpaper", "set-theme", "set-appearance", "set-blur", "set-system", "set-devices", "set-keybinds", "power-logo", "mic", "note-save", "bin", "apps", "info"].indexOf(name) >= 0

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    Behavior on color {
        CAnim {}
    }

    // Both kinds below are drawn by the curve renderer, except the sharp and
    // the smooth-edged icons: those are drawn 4 x as big and scaled down evenly -
    // every screen pixel the average of 4 x 4 - which gives exact, even edges
    // (the curve renderer, small, makes a few edge pixels too light or too
    // dark: a bump here, a step there). Lines on whole pixels stay sharp.
    Item {
        id: art

        readonly property bool sampled: root.smoothEdges || root.sharpPath !== ""
        readonly property int big: Math.ceil(root.size * root.dpr) * 4

        width: root.size
        height: root.size
        layer.enabled: sampled
        layer.textureSize: Qt.size(big, big)
        layer.smooth: true
        layer.mipmap: true

        // icons are drawn on a 100 x 100 grid and scaled down to `size`
        Shape {
            visible: root.sharpPath === ""
            width: 100
            height: 100
            scale: root.size / 100
            transformOrigin: Item.TopLeft
            preferredRendererType: art.sampled ? Shape.GeometryRenderer : Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillColor: root.color
                fillRule: ShapePath.WindingFill
                PathSvg {
                    path: root.parts.length > 0 ? root.parts[0] : ""
                }
            }
        }

        // the sharp version: drawn in screen pixels, then scaled to `size`
        Shape {
            visible: root.sharpPath !== ""
            width: root.size * root.dpr
            height: root.size * root.dpr
            scale: 1 / root.dpr
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.GeometryRenderer

            ShapePath {
                strokeWidth: -1
                fillColor: root.color
                fillRule: ShapePath.WindingFill
                PathSvg {
                    path: root.sharpPath
                }
            }
        }
    }
}
