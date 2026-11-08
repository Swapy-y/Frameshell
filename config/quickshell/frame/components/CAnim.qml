import QtQuick
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  CAnim.qml - Colour animation with the shell's standard curve.
//  Use it as:  Behavior on color { CAnim {} }
// ═══════════════════════════════════════════════════════════════════════════
ColorAnimation {
    duration: Theme.durFast
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curveStandard
}
