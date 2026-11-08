import QtQuick
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  FSlider.qml - Thin horizontal slider (Config.slider fill on a Config.iconDim
//  track, round knob) as in the concept.
//
//    value        0..1 shown by the slider      interactive  false = greyed out
//    moved(v)     emitted while dragging, clicking or scrolling
//    steps        0 = any value; n = only 0, 1/n, 2/n ... 1 (the knob jumps
//                 between them; the Settings app's border widths)
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    property real value: 0          // 0..1 (from outside)
    property bool interactive: true
    property color trackColor: Config.iconDim
    property color fillColor: Config.slider
    property real knobSize: Theme.px(10)
    property real trackHeight: Theme.px(4)
    property real wheelStep: 0.05
    property int steps: 0

    // emitted while the user drags / clicks / scrolls
    signal moved(real value)
    signal released

    readonly property bool dragging: area.pressed
    property real _dragValue: 0
    readonly property real shown: dragging ? _dragValue : Math.max(0, Math.min(1, value))

    implicitHeight: Math.max(knobSize, trackHeight) + Theme.px(6)
    implicitWidth: Theme.px(200)

    function _fromX(x) {
        const usable = Math.max(1, width - knobSize);
        return _snap(Math.max(0, Math.min(1, (x - knobSize / 2) / usable)));
    }
    function _snap(v) {
        return steps > 0 ? Math.round(v * steps) / steps : v;
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        radius: height / 2
        color: root.trackColor

        Rectangle {
            width: knob.x + knob.width / 2
            height: parent.height
            radius: parent.radius
            color: root.fillColor
            opacity: root.interactive ? 1 : 0.45
        }
    }

    Rectangle {
        id: knob
        width: root.knobSize
        height: root.knobSize
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.shown * (root.width - width)
        color: root.fillColor

        // with steps it glides to the next one
        Behavior on x {
            enabled: root.steps > 0
            Anim {
                duration: Theme.durFast
            }
        }
        opacity: root.interactive ? 1 : 0.45

        // grows a little while you drag it
        scale: area.pressed ? 1.35 : 1
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
