import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  FSlider.qml - Horizontal slider in Apple's style: a rounded bar with no knob,
//  the part up to the value filled (the theme's slider colour on a Config.inactive
//  track; in the frame its colours, Config.paletteFor - the slider colour still
//  from the theme). The fill has a straight end and is
//  cut off by the bar's rounded ends. While you drag it the bar grows a little
//  taller, out of its middle.
//
//    value        0..1 shown by the slider      interactive  false = greyed out
//    moved(v)     emitted while dragging, clicking or scrolling
//    steps        0 = any value; n = only 0, 1/n, 2/n ... 1 (the fill glides
//                 between them)
//    trackHeight  the bar's height (it is a bit taller while you drag it)
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    // the frame's colours inside the frame (Overlay.qml), else the theme's (Config.paletteFor)
    readonly property var pal: Config.paletteFor(QsWindow.window)

    property real value: 0          // 0..1 (from outside)
    property bool interactive: true
    property color trackColor: root.pal.inactive
    property color fillColor: root.pal.sliderFill
    property real trackHeight: Theme.px(8)
    property real wheelStep: 0.05
    property int steps: 0

    // emitted while the user drags / clicks / scrolls
    signal moved(real value)
    signal released

    readonly property bool dragging: area.pressed
    property real _dragValue: 0
    readonly property real shown: dragging ? _dragValue : Math.max(0, Math.min(1, value))

    // room for the bar while it is grown (a quarter taller), so nothing round it moves
    readonly property real grownHeight: Math.round(trackHeight * 1.25)
    implicitHeight: grownHeight + Theme.px(6)
    implicitWidth: Theme.px(200)

    function _fromX(x) {
        return _snap(Math.max(0, Math.min(1, x / Math.max(1, width))));
    }
    function _snap(v) {
        return steps > 0 ? Math.round(v * steps) / steps : v;
    }

    ClippingRectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: area.pressed ? root.grownHeight : root.trackHeight
        radius: height / 2
        color: root.trackColor
        opacity: root.interactive ? 1 : 0.45

        Behavior on height {
            Anim {
                duration: Theme.durFast
                curve: Theme.curveSpring
            }
        }

        // the value: from the left end up to it, cut off by the bar's round ends
        // - its own right end round too ("Flat sliders", Config.flatSliders: square)
        Rectangle {
            width: root.shown * track.width
            height: track.height
            radius: Config.flatSliders ? 0 : height / 2
            color: root.fillColor

            // with steps it glides to the next one
            Behavior on width {
                enabled: root.steps > 0
                Anim {
                    duration: Theme.durFast
                }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: false
        cursorShape: Qt.PointingHandCursor

        function apply(mouse) {
            root._dragValue = root._fromX(mouse.x);
            root.moved(root._dragValue);
        }

        onPressed: mouse => apply(mouse)
        onPositionChanged: mouse => {
            if (pressed)
                apply(mouse);
        }
        onReleased: root.released()
        onWheel: wheel => {
            const dir = wheel.angleDelta.y > 0 ? 1 : -1;
            root.moved(root._snap(Math.max(0, Math.min(1, root.value + dir * (root.steps > 0 ? 1 / root.steps : root.wheelStep)))));
            root.released();
        }
    }
}
