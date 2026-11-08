import QtQuick
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  HoverLatch.qml - Turns a flickery "is the pointer over it" signal into a
//  calm open / closed state: it opens immediately and closes as soon as the
//  pointer has left. The tiny `closeDelay` (Theme.hoverClose, 40 ms - too
//  short to notice) only swallows the moment the pointer crosses from the
//  frame's edge into the panel, so a panel never flickers shut on the way in.
// ═══════════════════════════════════════════════════════════════════════════
QtObject {
    id: root

    property bool input: false
    property int closeDelay: Theme.hoverClose
    property bool open: false

    onInputChanged: {
        if (input) {
            timer.stop();
            open = true;
        } else {
            timer.restart();
        }
    }

    property Timer _timer: Timer {
        id: timer
        interval: root.closeDelay
        onTriggered: root.open = false
    }
}
