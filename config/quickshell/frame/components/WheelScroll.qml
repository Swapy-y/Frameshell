import QtQuick
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  WheelScroll.qml - the normal wheel scrolling of a list or a Flickable (the
//  clipboard and the quick note), only faster or slower.
//
//  Qt itself slides a list 72 px for one wheel notch (a quick, sharply easing
//  slide of 0.3 s; a new notch starts from wherever the list is), and that
//  distance cannot be changed from QML. This does exactly the same with
//  Config.scrollStep px a notch (the default 100 = a little faster than Qt).
//  Like Qt, every wheel event slides - also from mice that report their scroll
//  in pixels; only a touchpad gesture moves the content with the fingers
//  (scaled the same way).
//
//  Put it in an empty item laid over the list and set the list to
//  `interactive: false` (else the list would take the wheel itself):
//      Item { x: list.x; y: list.y; width: list.width; height: list.height
//             WheelScroll { flickable: list } }
// ═══════════════════════════════════════════════════════════════════════════
WheelHandler {
    id: root

    required property Flickable flickable

    target: null
    // (on Wayland, Qt reports every wheel as coming from a "touchpad")
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    // px one notch scrolls; Qt's own is 72 (3 lines of 24 px)
    readonly property real step: Math.max(1, Theme.px(Config.scrollStep))

    function clampY(v) {
        const f = flickable;
        const top = f.originY;
        const bottom = Math.max(top, f.originY + f.contentHeight - f.height);
        return Math.max(top, Math.min(bottom, v));
    }

    onWheel: event => {
        const f = flickable;
        // Qt's own choice (QQuickFlickable::wheelEvent): only a touchpad gesture
        // (pixels, in a scroll phase) is followed directly; everything else slides
        if (event.pixelDelta.y !== 0 && event.phase !== Qt.NoScrollPhase) {
            // touchpad: follow the fingers
            slide.stop();
            f.contentY = clampY(f.contentY - event.pixelDelta.y * step / 72);
        } else if (event.angleDelta.y !== 0) {
            // wheel: 120 = one notch; slide from where the list is now
            slide.stop();
            slide.to = clampY(f.contentY - event.angleDelta.y / 120 * step);
            slide.restart();
        }
    }

    // Qt's wheel slide (QQuickFlickable::wheelEvent: OutExpo, 3/4 of its 400 ms fixup)
    readonly property NumberAnimation slide: NumberAnimation {
        target: root.flickable
        property: "contentY"
        duration: Theme.ms(300)
        easing.type: Easing.OutExpo
    }
}
