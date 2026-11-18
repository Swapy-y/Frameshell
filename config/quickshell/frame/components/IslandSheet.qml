import QtQuick
import QtQuick.Effects
import qs
import qs.services
import "shapes.js" as Shapes

// ═══════════════════════════════════════════════════════════════════════════
//  IslandSheet.qml - the shell's pop-ups: the launcher (SUPER + R), the app
//  switcher (SUPER + Space), the Wi-Fi / Bluetooth card, "Shut down?" / "Restart?" / "Log out?",
//  the password dialog and the emoji picker. Two ways to show them, by the
//  Settings app's "Island popups" (Island page, Config.dynamicPopups):
//
//  On (the default): it grows out of the island. Drawn in the pop-up's own window
//  (above everything, so it also opens over a fullscreen app), but it looks like
//  the island itself growing: it starts as the closed notch - its exact shape and
//  place (Theme.notchW / notchH / notchShift; with auto hide: nothing at the top
//  edge) - and grows down and out to `sheetW` x `sheetH`, with the same concave
//  ears, the same black (Config.frameColors) and the same soft shadow as the
//  island (Overlay.qml). Closing, it shrinks back into the notch. The shape never
//  fades: it is solid all the way, one black with the notch. So that the notch it
//  starts from is plain black, the island's top row (workspaces, clock, signal +
//  battery) fades away first (Ui.islandSheets, Island.qml's handOff) and the sheet
//  starts growing right after; closing, the row comes back once the sheet is back
//  in the notch.
//
//  Off: a card in the middle of the screen - black like the frame, rounded, with
//  a soft shadow and no border - that fades in while it grows from 94 % to its
//  size, and fades out again.
//
//  Put it in a full-screen window (anchors.fill) and the content into it (it goes
//  into `contentItem`, `sheetW` wide and `sheetH` tall). Grown out of the island,
//  `contentItem`'s top is the top of the screen - put the content from
//  `contentTop` (under the frame; none, frameless) down; as a card it is the
//  card's top, and `contentTop` is 0. The content never reflows: it is revealed as
//  the sheet grows (fading in once the sheet is most of the way open), or comes
//  with the card.
//
//    open        true = open               sheetW, sheetH   its size open
//    centered    shown as a card in the middle (Island popups off); cardRadius its corners
//    area        the sheet on the screen right now (the window's input area while
//                it closes)
//    shown       still on the screen (open, or closing)
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root
    anchors.fill: parent

    property bool open: false
    property real sheetW: Theme.px(600)
    property real sheetH: Theme.px(300)
    property bool centered: !Config.dynamicPopups
    property real cardRadius: Theme.px(26)      // the card's corners (in the middle)

    default property alias content: body.data
    readonly property Item contentItem: body
    readonly property Item area: centered ? cardBox : areaItem
    readonly property real contentTop: centered ? 0 : Theme.frame

    // grown out of the island: the island's top row fades away (Theme.durHandOff)
    // before it starts to grow - until then it waits, not yet drawn (no wait with
    // auto hide: no notch to start from; none as a card)
    property bool growing: false
    onOpenChanged: {
        if (!open)
            growing = false;
        else if (centered || Store.islandHidden || Theme.durHandOff === 0)
            growing = true;
        else
            handOffWait.restart();
    }
    Timer {
        id: handOffWait
        interval: Theme.durHandOff
        onTriggered: root.growing = root.open
    }

    // 0 = closed, 1 = open. Out of the island it shoots out - most of the way in a
    // third of Theme.durSheet - and lands softly on its size, never past it
    // (Theme.curveSheet); closing it eases back into the notch like a panel. As a
    // card, the cards' own timing (Theme.durOpen, curveDecel / durClose, curveAccel).
    property real p: open && growing ? 1 : 0
    Behavior on p {
        NumberAnimation {
            duration: root.open ? (root.centered ? Theme.durOpen : Theme.durSheet) : Theme.durClose
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? (root.centered ? Theme.curveDecel : Theme.curveSheet) : Theme.curveAccel
        }
    }
    readonly property bool shown: p > 0.001

    // counted in Ui.islandSheets while it grows out of the island, open or still
    // closing: the island's top row stays away meanwhile (a card leaves it alone)
    readonly property bool handingOff: !centered && (open || shown)
    onHandingOffChanged: Ui.islandSheets += handingOff ? 1 : -1
    Component.onDestruction: {
        if (handingOff)
            Ui.islandSheets -= 1;
    }

    // ── grown out of the island ───────────────────────────────────────────
    // the shape: from the closed notch to the open size. Its top sits off the screen like
    // the island's (Theme.notchShift); its width keeps the screen's odd/even-ness, so it
    // rests on whole pixels
    readonly property real startW: Store.islandHidden ? 0 : Shapes.sameParity(Theme.notchW, width)
    readonly property real startH: Store.islandHidden ? 0 : Theme.notchH
    readonly property real openW: Shapes.sameParity(sheetW, width)
    readonly property real fw: Shapes.lerp(startW, openW, p)
    readonly property real fh: Shapes.lerp(startH, sheetH + Theme.notchShift, p)
    readonly property real fx: (width - fw) / 2
    readonly property real fy: -Theme.notchShift

    // the shadow comes in over its first quarter (the notch has its own under it)
    readonly property real shadowIn: Shapes.clamp(p / 0.25, 0, 1)

    Item {
        id: areaItem
        x: Math.round(root.fx)
        y: 0
        width: Math.round(root.fw)
        height: Math.max(0, Math.round(root.fy + root.fh))
    }

    // soft shadow: a blurred copy of the shape, as under the island
    Item {
        id: shadowLayer
        anchors.fill: parent
        visible: !root.centered && Config.shadows && Config.shadowStrength > 0 && root.shown
        opacity: root.shadowIn

        ShaderEffectSource {
            id: shadowSource
            anchors.fill: parent
            sourceItem: fills
            textureSize: Qt.size(Math.max(1, width / 2), Math.max(1, height / 2))
            live: shadowLayer.visible
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: shadowSource
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: Math.min(1, Config.shadowStrength)
            shadowBlur: 1.0
            blurMax: 64
            shadowVerticalOffset: Theme.px(3)
            shadowHorizontalOffset: 0
            // see-through (the shell's blur): only round it, not under it
            maskEnabled: Config.shellAlpha < 1
            maskSource: shadowSource
            maskInverted: true
            maskThresholdMin: 0.0
            maskSpreadAtMin: 1.0
        }
    }

    // the shape: its edge, then its fill (one picture when see-through)
    Item {
        id: surfaces
        anchors.fill: parent
        visible: !root.centered && root.shown
        opacity: Config.shellAlpha
        layer.enabled: opacity < 1

        Item {
            id: strokes
            anchors.fill: parent
        }
        Item {
            id: fills
            anchors.fill: parent
        }
    }

    Flap {
        target: areaItem
        fx: root.fx
        fy: root.fy
        fw: root.fw
        fh: root.fh
        fillLayer: fills
        strokeLayer: strokes
        attachTop: true
    }

    // the content, revealed as it grows
    Item {
        id: clipper
        x: areaItem.x
        y: 0
        width: areaItem.width
        height: areaItem.height
        clip: true
        opacity: Shapes.clamp((root.p - 0.3) / 0.5, 0, 1)
        visible: !root.centered && opacity > 0.01
    }

    // ── as a card in the middle ───────────────────────────────────────────
    Item {
        id: cardBox
        width: root.openW
        height: Math.round(root.sheetH)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        visible: root.centered && opacity > 0.01
        // fades in over the first part of opening, grows from 94 % all the way
        opacity: root.centered ? Shapes.clamp(root.p / 0.4, 0, 1) : 0
        scale: 0.94 + 0.06 * root.p

        Rectangle {
            id: cardShape
            anchors.fill: parent
            radius: root.cardRadius
            color: Config.frameSurface           // black like the frame (see-through with the shell's blur)

            Loader {
                z: -1
                anchors.fill: parent
                active: Config.shadows && Config.shadowStrength > 0
                source: "CardShadow.qml"
            }
        }
    }

    // the content: in the card, or (grown out of the island) at its open place,
    // under the clipper
    Item {
        id: body
        parent: root.centered ? cardBox : clipper
        x: root.centered ? 0 : Math.round((root.width - root.openW) / 2) - clipper.x
        y: 0
        width: root.openW
        height: Math.round(root.sheetH)

        // clicks on the sheet stay on it (they would close it on the backdrop behind)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }
    }
}
