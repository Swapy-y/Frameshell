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
    // Laid out like Apple's notifications: a small header - the app's icon, its
    // name in grey and "now" on the right - then the title (the summary) in
    // semibold and the message under it. Without an app name the summary is the
    // header (the icon and the summary, in semibold).
    readonly property bool headIsApp: c !== null && c.appName.length > 0
    readonly property string headText: c ? (headIsApp ? c.appName : c.summary) : ""
    readonly property string titleString: c && headIsApp ? c.summary : ""
    readonly property string bodyString: c ? c.body : ""

    // ── size ──────────────────────────────────────────────────────────────
    // 16 px all round between the card's content (the icon and the text) and its
    // edges: the edge of the screen on the top and the right, the card's border
    // on the left and the bottom. The card is as wide as the text really is once
    // it wraps (at most Theme.notifMaxW), as tall as its lines.
    readonly property real pad: Theme.px(16)
    readonly property real maxTextW: Theme.notifMaxW - 2 * pad
    readonly property real iconSize: Theme.px(20)
    readonly property real iconGap: Theme.px(8)
    readonly property real headH: Theme.px(22)
    readonly property real nowGap: Theme.px(12)       // at least this between the app's name and "now"
    readonly property real titleGap: Theme.px(6)      // under the header
    readonly property real bodyGap: Theme.px(1)       // between the title and the message
    // from the bottom of the text's box up to its last line's baseline: the 16 px
    // under the text count from the letters, not from the empty box under them
    readonly property real bodyTrim: Theme.px(3)
    // the last letter of a line ends a little before its box (its side bearing and
    // the rounding up): the 16 px on the right count from the letters too
    readonly property real inkTrim: Theme.px(2)

    TextMetrics {
        id: headMetrics
        font: headLabel.font
        text: root.headText
    }
    TextMetrics {
        id: nowMetrics
        font: nowLabel.font
        text: nowLabel.text
    }

    // the title and the message laid out at the widest they may be, to find how
    // wide their lines end up
    Text {
        id: titleMeasure
        visible: false
        width: root.maxTextW
        wrapMode: Text.Wrap
        maximumLineCount: 2
        textFormat: Text.PlainText
        font: titleText.font
        text: root.titleString
    }
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

    readonly property bool hasTitle: titleString.length > 0
    readonly property bool hasBody: bodyString.length > 0
    readonly property real headW: iconSize + iconGap + Math.ceil(headMetrics.advanceWidth) + (headIsApp ? nowGap + Math.ceil(nowMetrics.advanceWidth) : 0)
    // the text's boxes: as wide as the widest line (so it wraps exactly as measured)
    readonly property real textW: Math.min(maxTextW, Math.ceil(Math.max(headW, hasTitle ? titleMeasure.contentWidth : 0, hasBody ? bodyMeasure.contentWidth : 0)))
    // the width the card makes room for: up to where the letters end
    readonly property real inkW: textW - inkTrim
    // the header row starts a little above the 16 px: its letters (centred in the
    // row) begin 16-17 px under the edge of the screen
    readonly property real headTop: pad - Theme.px(3)
    readonly property real textH: (hasTitle ? titleGap + titleText.height : 0) + (hasBody ? (hasTitle ? bodyGap : titleGap) + bodyText.height : 0)
    readonly property real naturalH: headTop + headH + textH - (hasTitle || hasBody ? bodyTrim : 0) + pad

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

    // header: icon + app name (grey) + "now"
    Item {
        id: head
        x: root.contentX
        y: root.contentY
        width: root.textW
        height: root.headH

        AppIcon {
            id: headIcon
            size: root.iconSize
            anchors.verticalCenter: parent.verticalCenter
            source: root.c ? (root.c.image.length > 0 ? root.c.image : IconPacks.path(root.c.icon)) : ""
            label: root.headText
        }

        Txt {
            id: headLabel
            x: root.iconSize + root.iconGap
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - (nowLabel.visible ? root.nowGap + nowLabel.implicitWidth : 0)
            text: root.headText
            textFormat: Text.PlainText
            font.pixelSize: root.headIsApp ? Theme.px(14) : Theme.px(16)
            font.weight: root.headIsApp ? Font.Medium : Font.DemiBold
            color: root.headIsApp ? Config.frameColors.textSecondary : Config.text
            elide: Text.ElideRight
        }

        // it is always new: the card only shows while it comes in
        Txt {
            id: nowLabel
            visible: root.headIsApp
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "now"
            font.pixelSize: Theme.px(13)
            color: Config.frameColors.textSecondary
        }
    }

    // the title (the summary)
    Txt {
        id: titleText
        x: root.contentX
        y: head.y + head.height + root.titleGap
        width: root.textW
        visible: root.hasTitle
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        textFormat: Text.PlainText
        font.pixelSize: Theme.px(16)
        font.weight: Font.DemiBold
        color: Config.text
        text: root.titleString
    }

    // the message
    Txt {
        id: bodyText
        x: root.contentX
        y: root.hasTitle ? titleText.y + titleText.height + root.bodyGap : head.y + head.height + root.titleGap
        width: root.textW
        visible: root.hasBody
        wrapMode: Text.Wrap
        maximumLineCount: 4
        elide: Text.ElideRight
        lineHeight: 0.95
        font.pixelSize: Theme.px(16)
        color: Config.frameColors.notificationText
        text: root.bodyString
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Notifs.activateCurrent()      // the app's "default" action, or just dismiss
    }
}
