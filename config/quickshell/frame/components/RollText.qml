import QtQuick
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  RollText.qml - a line of text whose changed end rolls, like the digits of
//  Apple's clocks (the island's clock: 10:35 -> 10:36). When the text changes,
//  what stays the same stays put; from the first changed letter on, the old text
//  slides up and fades out while the new one comes up from below and fades in.
//  At rest it is one plain Txt, exactly as before.
//
//  The changed part is cut from the whole line, not drawn letter by letter, so
//  every letter keeps its place and shape in the line (the clock's colon sits at
//  the digits' middle only between digits).
//
//    text      the text          pixelSize, weight, color   its look (as Txt)
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    property string text
    property real pixelSize: Theme.fsBody
    property int weight: Font.Normal
    property color color: Config.text

    // what is shown now, and (while it rolls) what was there before
    property string shownText: ""
    property string oldText: ""
    // where the first changed letter starts
    property real split: 0
    // 0 = the old text, 1 = the new one in place
    property real roll: 1
    readonly property bool rolling: roll < 1

    // as wide as the text; going wider / narrower ("9:59" -> "10:00") it eases there
    implicitWidth: widthNow
    implicitHeight: whole.implicitHeight
    property real widthNow: whole.implicitWidth
    Behavior on widthNow {
        enabled: root.rolling
        Anim {
            duration: Theme.durOpen
            curve: Theme.curveDecel
        }
    }

    Component.onCompleted: shownText = text
    onTextChanged: {
        if (shownText === "" || Theme.durOpen === 0) {
            shownText = text;
            return;
        }
        if (text === shownText)
            return;
        // the letters both have in common at the start stay put
        let k = 0;
        while (k < text.length && k < shownText.length && text[k] === shownText[k])
            k++;
        roll = 0;       // (first: the width eases to the new one)
        oldText = shownText;
        shownText = text;
        split = metrics.advanceWidth(text.substring(0, k));
        rollAnim.restart();
    }

    NumberAnimation {
        id: rollAnim
        target: root
        property: "roll"
        from: 0
        to: 1
        duration: Theme.durOpen
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveDecel
    }

    FontMetrics {
        id: metrics
        font: whole.font
    }

    // how far the letters travel: about half their height
    readonly property real travel: Math.round(height * 0.55)

    // ── at rest: the whole line ─────────────────────────────────────────────
    Txt {
        id: whole
        visible: !root.rolling
        text: root.shownText
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        color: root.color
    }

    // ── rolling: the part that stays, then the changed part (old out, new in).
    // The clipping boxes reach far above and below, so only the left / right edge
    // at `split` cuts; the letters fade rather than being cut off at the top.
    Item {
        visible: root.rolling
        x: 0
        y: -root.height
        width: Math.ceil(root.split)
        height: 3 * root.height
        clip: true

        Txt {
            y: root.height
            text: root.shownText
            font.pixelSize: root.pixelSize
            font.weight: root.weight
            color: root.color
        }
    }

    Item {
        visible: root.rolling
        x: Math.ceil(root.split)
        y: -root.height
        width: Math.max(root.width, oldMetrics.advanceWidth) + root.height
        height: 3 * root.height
        clip: true

        TextMetrics {
            id: oldMetrics
            font: whole.font
            text: root.oldText
        }

        Txt {
            x: -Math.ceil(root.split)
            y: root.height - root.travel * root.roll
            text: root.oldText
            font.pixelSize: root.pixelSize
            font.weight: root.weight
            color: root.color
            opacity: Math.max(0, 1 - root.roll * 1.6)
        }

        Txt {
            x: -Math.ceil(root.split)
            y: root.height + root.travel * (1 - root.roll)
            text: root.shownText
            font.pixelSize: root.pixelSize
            font.weight: root.weight
            color: root.color
            opacity: Math.min(1, root.roll * 1.4)
        }
    }
}
