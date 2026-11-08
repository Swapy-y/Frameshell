import QtQuick
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  PanelAnim.qml - Open / close animation of a panel's progress value
//  (0 = closed, 1 = open). Opening starts quickly and settles softly into place;
//  closing eases off and lands softly in the frame (Theme.curveDecel / curveAccel).
//
//    Behavior on p { PanelAnim { opening: root.open } }
// ═══════════════════════════════════════════════════════════════════════════
NumberAnimation {
    property bool opening: true

    duration: opening ? Theme.durOpen : Theme.durClose
    easing.type: Easing.BezierSpline
    easing.bezierCurve: opening ? Theme.curveDecel : Theme.curveAccel
}
