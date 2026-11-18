import QtQuick
import Quickshell
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Toggle.qml - an on/off switch in the theme's colours: on, a track in the
//  text colour with a knob in the frame colour; off, like the shell's buttons -
//  a track in the selected colour (Config.controlBackground) with a knob in the text
//  colour, the same under the pointer.
//
//    checked   on / off (from outside)       toggled(bool)  emitted on click
//    enabled   false = greyed out, no clicks
//    offColor  the track when off (on something in Config.controlBackground: another colour)
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    // the frame's colours inside the frame (Overlay.qml), else the theme's (Config.paletteFor)
    readonly property var pal: Config.paletteFor(QsWindow.window)

    property bool checked: false
    property color offColor: root.pal.controlBackground
    signal toggled(bool on)

    implicitWidth: Theme.px(38)
    implicitHeight: Theme.px(22)
    width: implicitWidth
    height: implicitHeight
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Config.text : root.offColor

        Behavior on color {
            CAnim {}
        }
    }

    Rectangle {
        id: knob
        readonly property real pad: Theme.px(3)
        width: root.height - 2 * pad
        height: width
        radius: width / 2
        y: pad
        x: root.checked ? root.width - width - pad : pad
        color: root.checked ? root.pal.background : Config.text
        scale: area.pressed ? 0.88 : 1

        Behavior on x {
            Anim {
                duration: Theme.durSmall
                curve: Theme.curveStandard
            }
        }
        Behavior on color {
            CAnim {}
        }
        Behavior on scale {
            Anim {
                duration: Theme.durFast
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -Theme.px(4)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
