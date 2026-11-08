import QtQuick
import qs
import qs.services
import qs.components

// ═══════════════════════════════════════════════════════════════════════════
//  DateCorner.qml - notch mode (the Settings app's Dock page, Store.dockNotch):
//  the date as a small block in the bottom-right corner, like the colour picker
//  top right. It comes out while the pointer is on that corner of the frame (or
//  on the block); a click opens the calendar. While the calendar is open it
//  stays: the date then sits in the calendar's corner, right where the bar has it
//  (the block is as tall as the bar, the date in the same place).
// ═══════════════════════════════════════════════════════════════════════════
Panel {
    id: root

    // true while the pointer touches the corner of the frame (set by Overlay.qml)
    property bool hot: false

    HoverLatch {
        id: latch
        input: Store.dockNotch && (root.hot || blockHover.hovered || Ui.calendarOpen)
    }

    HoverHandler {
        id: blockHover
    }

    open: latch.open
    attachBottom: true
    attachRight: true

    readonly property real buttonH: Theme.px(32)
    readonly property real sideGap: Theme.px(8)        // as in the bar (BottomBar.qml)
    readonly property real pillW: dateText.implicitWidth + 2 * Theme.px(12)

    contentW: pillW + 2 * sideGap
    contentH: Theme.bar

    // the bar's date: a pill without an outline or fill; it dips when pressed
    Rectangle {
        id: pill
        x: root.sideGap
        y: Math.round((Theme.bar - height) / 2)
        width: root.pillW
        height: root.buttonH
        radius: height / 2
        color: "transparent"
        antialiasing: true
        scale: area.pressed ? 0.94 : 1

        Behavior on color {
            CAnim {}
        }
        Behavior on scale {
            Anim {
                duration: Theme.durFast
                curve: Theme.curveSpring
            }
        }

        Txt {
            id: dateText
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            text: Clock.dateNumeric
            font.pixelSize: Theme.px(17)
            font.weight: Font.DemiBold
        }
    }

    // the whole block, into the corner of the screen
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.toggleCalendar()
    }
}
