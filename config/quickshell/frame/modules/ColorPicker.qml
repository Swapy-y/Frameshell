import QtQuick
import Quickshell
import qs
import qs.services
import qs.components

// ═══════════════════════════════════════════════════════════════════════════
//  ColorPicker.qml - the small colour picker block in the top-right corner.
//  It pops out while the pointer is on the top-right corner of the frame (or
//  on the block itself), like the volume / brightness panel top left. Click
//  it, then click anywhere on the screen (hyprpicker): the colour's hex code
//  is copied and shown in a notification (scripts/colorpicker.sh).
//  Right-click or Esc cancels.
//
//  It shares the corner with the notification card, so it stays away while a
//  notification is on screen.
// ═══════════════════════════════════════════════════════════════════════════
Panel {
    id: root

    // true while the pointer touches the corner of the frame (set by Overlay.qml)
    property bool hot: false
    // a notification card is on screen (or about to be): set by Overlay.qml
    property bool blocked: false

    HoverLatch {
        id: latch
        input: Config.colorPicker && !root.blocked && (root.hot || panelHover.hovered)
    }

    HoverHandler {
        id: panelHover
    }

    open: latch.open && !root.blocked
    attachTop: true
    attachRight: true

    contentW: Theme.pickerW
    contentH: Theme.pickerH

    readonly property string script: Quickshell.shellPath("scripts/colorpicker.sh")

    Icon {
        id: icon
        // centred where the concept has it (a little towards the corner)
        x: root.contentW - Theme.px(20.75) - size / 2
        y: Theme.px(18.75) - size / 2
        size: Theme.px(22)
        name: "picker"
        color: area.containsMouse ? Config.text : Config.pickerIcon
        scale: area.pressed ? 0.88 : 1

        Behavior on scale {
            Anim {
                duration: Theme.durFast
                curve: Theme.curveSpring
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["bash", root.script])
    }
}
