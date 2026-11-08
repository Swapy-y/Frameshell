import QtQuick
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  RingButton.qml - the round button of the island (Bluetooth, Wi-Fi, the
//  bell) and of the panels that go with it (power menu, calendar, the bar).
//
//  On: a white circle with a dark icon. Off: a thin grey ring, the icon inside
//  in `iconColor`, the inside a little lighter under the pointer. It is a little
//  bigger while its card / panel is open, and dips when pressed.
//
//    on            white (`onColor`) with a dark icon
//    fillOnHover   off, but filled like "on" under the pointer (the power menu rows)
//    active        its card / panel is open: a little bigger
//    outline       false: no grey ring when off (just the icon; the inside still
//                  lights up under the pointer)
//    offColor      the inside when off (the island's colour: invisible)
//    interactive   false: no mouse area of its own - set `hot` / `down` from
//                  outside (a whole row that reacts)
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    property bool on: false
    property bool fillOnHover: false
    property bool active: false
    property string icon: ""
    property real iconSize: Theme.px(22)
    property color iconColor: Config.textDim         // icon when off
    property color iconHotColor: iconColor           // ... under the pointer
    property color onColor: Config.text              // the fill when on
    property real hotScale: 1.06                     // the size while `active`
    property bool outline: true                      // false: no grey ring when off (the bar's buttons)
    property color offColor: Config.frame            // the inside when off ...
    property color hoverColor: Config.hover          // ... and under the pointer

    property bool interactive: true
    property bool hot: interactive && area.containsMouse
    property bool down: interactive && area.pressed

    readonly property bool filled: on || (fillOnHover && hot)

    signal clicked

    width: Theme.px(42)
    height: width

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        // off: the island's own colour (a little lighter under the pointer), so
        // whatever is behind - an outline - never shows through
        color: root.filled ? root.onColor : (root.hot ? root.hoverColor : root.offColor)
        border.width: root.outline ? Theme.px(1.5) : 0
        border.color: root.filled ? root.onColor : Config.iconDim
        antialiasing: true
        scale: root.down ? 0.9 : (root.active ? root.hotScale : 1)

        Behavior on color {
            CAnim {}
        }
        Behavior on border.color {
            CAnim {}
        }
        Behavior on scale {
            Anim {
                duration: Theme.durFast
                curve: Theme.curveSpring
            }
        }

        Icon {
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            size: root.iconSize
            name: root.icon
            color: root.filled ? Config.frame : (root.hot ? root.iconHotColor : root.iconColor)
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
