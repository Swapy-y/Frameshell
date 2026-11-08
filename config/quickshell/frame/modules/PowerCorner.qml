import QtQuick
import qs
import qs.services
import qs.components

// ═══════════════════════════════════════════════════════════════════════════
//  PowerCorner.qml - notch mode (the Settings app's Dock page, Store.dockNotch):
//  the power button as a small block in the bottom-left corner, like the colour
//  picker top right. It comes out while the pointer is on that corner of the
//  frame (or on the block); a click opens the power menu. While the menu is open
//  it stays: the button then sits in the menu's corner, right where the bar has
//  it (the block is as tall as the bar, the button in the same place).
// ═══════════════════════════════════════════════════════════════════════════
Panel {
    id: root

    // true while the pointer touches the corner of the frame (set by Overlay.qml)
    property bool hot: false

    HoverLatch {
        id: latch
        input: Store.dockNotch && (root.hot || blockHover.hovered || Ui.powerOpen)
    }

    HoverHandler {
        id: blockHover
    }

    open: latch.open
    attachBottom: true
    attachLeft: true

    readonly property real buttonH: Theme.px(32)
    readonly property real sideGap: Theme.px(8)        // as in the bar (BottomBar.qml)

    contentW: sideGap + buttonH + Theme.px(10)
    contentH: Theme.bar

    // the bar's power button
    RingButton {
        x: root.sideGap
        y: Math.round((Theme.bar - height) / 2)
        width: root.buttonH
        // like the bar's: the Frameshell logo, or the power sign (Store.powerLogo)
        icon: Store.powerLogo ? "power-logo" : "power"
        iconSize: Store.powerLogo ? Theme.px(16) : Theme.px(18)
        iconColor: Config.text
        outline: false
        // no fill, also while the power menu is open
        offColor: "transparent"
        hoverColor: offColor
        interactive: false
        hot: area.containsMouse
        down: area.pressed
    }

    // the whole block, into the corner of the screen
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.togglePower()
    }
}
