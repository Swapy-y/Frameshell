import QtQuick
import QtQuick.Effects
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  CardShadow.qml - Soft drop shadow for a floating rounded card (the app
//  switcher, the launcher and the pop-ups). Put it inside the card (through a
//  Loader, below); it fills it and is drawn behind it.
//
//  With the shell's blur the card is see-through (Config.shellAlpha < 1): then
//  the part of the shadow under the card is cut out - it would darken the card
//  from behind - and only the shadow round it stays.
//
//  It needs Qt 6.9 or newer (RectangularShadow). That is why it is loaded
//  through a Loader: with Config.shadows = false it is never touched, so an
//  older Qt still runs the shell.
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root
    anchors.fill: parent

    // the card it belongs to (the Loader's parent), for the shape of the cut-out
    readonly property Item card: parent && parent.parent ? parent.parent : null
    readonly property real cardRadius: card && card.radius !== undefined ? card.radius : Theme.pop(26)
    readonly property real blurSize: Theme.pop(34)
    readonly property real offsetY: Theme.pop(8)
    // room round the card for the soft edge (and the offset)
    readonly property real reach: blurSize + offsetY
    readonly property bool cut: Config.shellAlpha < 1

    Item {
        id: area
        x: -root.reach
        y: -root.reach
        width: root.width + 2 * root.reach
        height: root.height + 2 * root.reach
        layer.enabled: root.cut
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: hole
            maskThresholdMin: 0.0
            maskSpreadAtMin: 1.0
        }

        RectangularShadow {
            x: root.reach
            y: root.reach
            width: root.width
            height: root.height
            radius: Theme.pop(26)                          // the radius of the cards
            blur: root.blurSize
            offset: Qt.vector2d(0, root.offsetY)
            color: Qt.rgba(0, 0, 0, Math.min(1, Config.shadowStrength))
        }
    }

    // the card's shape: there the shadow is cut out (only while the card is see-through)
    Item {
        id: hole
        width: area.width
        height: area.height
        visible: false
        layer.enabled: root.cut

        Rectangle {
            x: root.reach
            y: root.reach
            width: root.width
            height: root.height
            radius: root.cardRadius
        }
    }
}
