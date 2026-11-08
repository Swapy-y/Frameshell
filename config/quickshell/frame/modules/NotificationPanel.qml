import QtQuick
import Quickshell
import qs
import qs.services
import qs.components
import "../components/shapes.js" as Shapes

// ═══════════════════════════════════════════════════════════════════════════
//  NotificationPanel.qml - notification card in the top-right corner.
//
//  One card at a time (see services/Notifs.qml). The card is only as big as
//  its text needs (16 px around it), between a minimum and Theme.notifMaxW /
//  notifMaxH.
//  Hover it to keep it open, click it to dismiss it (or to do what the app
//  offers on a click, e.g. show a screenshot in the file manager).
// ═══════════════════════════════════════════════════════════════════════════
Panel {
    id: root

    // keep showing the last card while the panel folds away
    property var card: null
    open: Notifs.current !== null

    onOpenChanged: {
        if (open)
            card = Notifs.current;
    }

    Connections {
        target: Notifs

        function onCurrentChanged() {
            if (Notifs.current !== null)
                root.card = Notifs.current;
        }
    }

    attachTop: true
    attachRight: true

    readonly property var c: card

    // ── text of the card ──────────────────────────────────────────────────
    readonly property string headText: c ? (c.appName.length > 0 ? c.appName : c.summary) : ""
    readonly property string bodyString: {
        if (!c)
            return "";
        const first = c.appName.length > 0 ? c.summary : "";
        const rest = c.body;
        return first.length > 0 && rest.length > 0 ? first + "\n" + rest : (first.length > 0 ? first : rest);
    }

    // ── size ──────────────────────────────────────────────────────────────
    // 16 px all round between the card's content (the icon and the text) and its
    // edges: the edge of the screen on the top and the right, the card's border
    // on the left and the bottom. The card is as wide as the text really is once
    // it wraps (at most Theme.notifMaxW), as tall as its lines.
    readonly property real pad: Theme.px(16)
    readonly property real maxTextW: Theme.notifMaxW - 2 * pad
    readonly property real iconSize: Theme.px(24)
    readonly property real iconGap: Theme.px(7)
    readonly property real headH: Theme.px(26)
    readonly property real bodyGap: Theme.px(4)
    // from the bottom of the text's box up to its last line's baseline: the 16 px
    // under the text count from the letters, not from the empty box under them
    readonly property real bodyTrim: Theme.px(2)
    // the last letter of a line ends a little before its box (its side bearing and
    // the rounding up): the 16 px on the right count from the letters too
    readonly property real inkTrim: Theme.px(2)

    FontMetrics {
        id: headMetrics
        font.family: Theme.font
        font.pixelSize: Theme.px(20)
        font.weight: Font.Medium
    }

    // the body laid out at the widest it may be, to find how wide its lines end up
    Text {
        id: bodyMeasure
        visible: false
        width: root.maxTextW
        wrapMode: Text.Wrap
        maximumLineCount: 4
        lineHeight: 0.95
        font: bodyText.font
        text: root.bodyString
    }

    readonly property real headW: iconSize + iconGap + Math.ceil(headMetrics.advanceWidth(headText))
    readonly property bool hasBody: bodyString.length > 0
    // the text's boxes: as wide as the widest line (so it wraps exactly as measured)
    readonly property real textW: Math.min(maxTextW, Math.ceil(Math.max(headW, hasBody ? bodyMeasure.contentWidth : 0)))
    // the width the card makes room for: up to where the letters end
    readonly property real inkW: textW - inkTrim
    // the header row starts a little above the 16 px: its letters (centred in the
    // row) begin 16-17 px under the edge of the screen
    readonly property real headTop: pad - Theme.px(4)
    readonly property real naturalH: headTop + headH + (hasBody ? bodyGap + bodyText.height - bodyTrim : 0) + pad

    // (never narrower than its two rounded corners need)
    contentW: Shapes.clamp(inkW + 2 * pad, Math.max(Theme.notifMinW, 2 * Theme.panelRadius), Theme.notifMaxW)
    contentH: Shapes.clamp(naturalH, Theme.px(70), Theme.notifMaxH)

    // the content's place: 16 px in, or in the middle when the card is bigger than
    // it needs (a very short notification)
    readonly property real contentX: Math.round((contentW - inkW) / 2)
    readonly property real contentY: Math.round((contentH - naturalH) / 2) + headTop

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                Notifs.pause();
            else
                Notifs.resume();
        }
    }

    // header: icon + app name
    Row {
        id: head
        x: root.contentX
        y: root.contentY
        width: root.textW
        spacing: root.iconGap
        height: root.headH

        AppIcon {
            size: root.iconSize
            anchors.verticalCenter: parent.verticalCenter
            source: root.c ? (root.c.image.length > 0 ? root.c.image : IconPacks.path(root.c.icon)) : ""
            label: root.headText
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - root.iconSize - root.iconGap
            text: root.headText
            font.pixelSize: Theme.px(20)
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    // summary + body
    Txt {
        id: bodyText
        x: root.contentX
        y: head.y + head.height + root.bodyGap
        width: root.textW
        visible: root.hasBody
        wrapMode: Text.Wrap
        maximumLineCount: 4
        elide: Text.ElideRight
        lineHeight: 0.95
        font.pixelSize: Theme.px(17)
        color: Config.notificationText
        text: root.bodyString
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Notifs.activateCurrent()      // the app's "default" action, or just dismiss
    }
}
