import QtQuick

// ═══════════════════════════════════════════════════════════════════════════
//  HotZone.qml - Invisible strip of the frame that reacts to the pointer
//  (used to open the slider and quick-note panels).
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    // a zone that is switched off is not there at all: a disabled item still keeps
    // the pointer's hover from what is under it (the dock's own edge, a button)
    visible: enabled

    readonly property bool hovered: handler.hovered

    HoverHandler {
        id: handler
    }
}
