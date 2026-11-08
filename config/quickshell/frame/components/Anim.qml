import QtQuick
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Anim.qml - Number animation with the shell's standard curve.
//
//  Use it as:  Behavior on x { Anim {} }
//  Options:    Anim { duration: Theme.durFast }
//              Anim { curve: Theme.curveDecel }
// ═══════════════════════════════════════════════════════════════════════════
NumberAnimation {
    property var curve: Theme.curveStandard

    duration: Theme.durSmall
    easing.type: Easing.BezierSpline
    easing.bezierCurve: curve
}
