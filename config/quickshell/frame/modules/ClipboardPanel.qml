import QtQuick
import Quickshell.Widgets
import qs
import qs.services
import qs.components
import "../components/shapes.js" as Shapes

// ═══════════════════════════════════════════════════════════════════════════
//  ClipboardPanel.qml - the clipboard history, on the left edge of the screen
//  (hover the middle of the left frame), the twin of the quick note on the
//  right.
//
//  Newest first: text (up to three lines, … when there is more)
//  and pictures. Click an entry to copy it again (it moves to the top),
//  middle-click to delete it. Scroll for older ones. The history itself is
//  kept by cliphist (services/Clipboard.qml).
//
//  The round magnifier button next to the title opens the search field: it
//  shows only the text entries with what you type in them. While you type the
//  panel stays open; Esc (or a click outside the shell) clears the search and
//  lets it fold again.
//
//  Something copied since the panel was last open pops in at the top while the
//  others slide down. How far the mouse wheel scrolls: Config.scrollStep.
// ═══════════════════════════════════════════════════════════════════════════
Panel {
    id: root

    // true while the pointer touches the hot strip of the frame (set by Overlay.qml)
    property bool hot: false

    // (not while the power menu is open: they share the left edge)
    HoverLatch {
        id: latch
        input: !Ui.powerOpen && (root.hot || panelHover.hovered || Ui.clipboardSearching)
    }

    open: latch.open
    attachLeft: true

    // Like the quick note: as tall as the entries need, at most
    // Config.noteMaxHeightFraction of the screen (the note's maximum), then it scrolls.
    readonly property real maxHeight: Math.max(Theme.noteMinH, parent.height * Config.noteMaxHeightFraction)
    contentW: Theme.clipW
    contentH: Shapes.clamp(listTop + list.contentHeight + edge, Theme.noteMinH, maxHeight)

    // what is typed in the search field, and the entries shown: all of them, or
    // the text entries that have it in them (any case)
    property string query: ""
    readonly property string needle: query.trim().toLowerCase()
    readonly property var shown: needle === "" ? Clipboard.entries : Clipboard.entries.filter(e => e.kind !== "image" && String(e.text).toLowerCase().indexOf(needle) >= 0)
    onNeedleChanged: list.positionViewAtBeginning()

    // The list shows `rows`, kept in step with `shown` one entry at a time
    // (insert / move / remove) instead of being replaced: entries already on
    // screen stay, and the list can animate the ones that come and go.
    ListModel {
        id: rows
    }

    function syncRows() {
        const wanted = shown;
        const want = {};
        for (let i = 0; i < wanted.length; i++)
            want[String(wanted[i].id)] = true;
        // gone (deleted, filtered out, pushed out by newer ones)
        for (let i = rows.count - 1; i >= 0; i--) {
            if (!want[rows.get(i).eid])
                rows.remove(i);
        }
        // new ones in, moved ones to their place
        for (let i = 0; i < wanted.length; i++) {
            const e = wanted[i];
            const id = String(e.id);
            if (i < rows.count && rows.get(i).eid === id)
                continue;
            let from = -1;
            for (let k = i + 1; k < rows.count; k++) {
                if (rows.get(k).eid === id) {
                    from = k;
                    break;
                }
            }
            if (from >= 0) {
                rows.move(from, i, 1);
            } else {
                const image = e.kind === "image";
                rows.insert(i, {
                    eid: id,
                    kind: String(e.kind),
                    body: image ? "" : String(e.text),
                    path: image ? String(e.path) : "",
                    iw: Number(e.w) || 0,
                    ih: Number(e.h) || 0
                });
            }
        }
    }

    onShownChanged: syncRows()
    Component.onCompleted: syncRows()

    onOpenChanged: {
        if (open) {
            Clipboard.refresh();
            list.positionViewAtBeginning();
        } else {
            // folded: the next time it opens without a search (the button again)
            field.text = "";
            Ui.clipboardSearching = false;
            searchOpen = false;
        }
    }

    HoverHandler {
        id: panelHover
    }

    // the same space on all sides; on the left it counts from the edge of the
    // screen, so everything is centred between the screen's edge and the panel's
    // border
    readonly property real edge: Theme.px(12)
    readonly property real leftPad: edge
    readonly property real listTop: search.y + search.height + Theme.px(15)     // 15 px under the title row

    // ── the title and the search ─────────────────────────────────────────
    // Closed: "Clipboard" and a round magnifier button (the island's buttons:
    // a soft grey circle, a little bigger under the pointer), the
    // two in the middle. A click widens the circle into the search field and
    // the title moves to the left; Esc, folding the panel or leaving the field
    // empty turns it back into the button.
    property bool searchOpen: false
    property real sp: searchOpen ? 1 : 0          // 0 = the button, 1 = the search field
    Behavior on sp {
        Anim {
            duration: Theme.durClose
        }
    }

    readonly property real headerGap: Theme.px(10)
    readonly property real searchH: Theme.px(28)
    readonly property real titleW: Math.ceil(title.width)
    // the title's place: with the button, in the middle (between the edge of the
    // screen and the panel's border); with the field, on the left
    readonly property real titleXClosed: Math.round((Theme.clipW - (titleW + headerGap + searchH)) / 2)
    readonly property real searchWOpen: Theme.clipW - edge - (leftPad + titleW + headerGap)

    function openSearch() {
        searchOpen = true;
        field.forceActiveFocus();
    }

    // the panel's name, like the calendar's month
    Txt {
        id: title
        x: Math.round(Shapes.lerp(root.titleXClosed, root.leftPad, root.sp))
        y: Math.round(search.y + (search.height - height) / 2)
        text: "Clipboard"
        font.pixelSize: Theme.px(21)
        font.weight: Font.DemiBold
    }

    Rectangle {
        id: search
        x: title.x + root.titleW + root.headerGap
        y: root.edge
        width: Math.round(Shapes.lerp(root.searchH, root.searchWOpen, root.sp))
        height: root.searchH
        // a circle that turns into a rounded field
        radius: Shapes.lerp(height / 2, Theme.px(9), root.sp)
        antialiasing: true
        // lighter only while you type in it
        color: field.activeFocus ? Config.outline : Config.selected
        // the button dips when pressed
        scale: root.searchOpen ? 1 : (searchArea.pressed ? 0.9 : 1)

        Behavior on color {
            CAnim {}
        }
        Behavior on scale {
            Anim {
                duration: Theme.durFast
                curve: Theme.curveSpring
            }
        }

        // the button opens the field; on the field: puts the cursor in it (the
        // text itself handles its own clicks)
        MouseArea {
            id: searchArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.searchOpen ? Qt.IBeamCursor : Qt.PointingHandCursor
            onClicked: root.openSearch()
        }

        // the magnifier: in the middle of the button, at the start of the field
        Icon {
            x: Math.round(Shapes.lerp((root.searchH - width) / 2, Theme.px(9), root.sp))
            y: Math.round((parent.height - height) / 2)
            size: Math.round(Shapes.lerp(Theme.px(14), Theme.px(12), root.sp))
            name: "search"
            color: root.searchOpen ? Config.textDim : Config.text
        }

        Txt {
            x: field.x
            y: Math.round((parent.height - height) / 2)
            visible: field.text.length === 0 && opacity > 0.01
            opacity: Shapes.clamp((root.sp - 0.5) / 0.5, 0, 1)
            text: "Search"
            font.pixelSize: Theme.px(13)
            font.weight: Font.Medium
            color: Config.textDim
        }

        TextInput {
            id: field
            x: Theme.px(27)
            y: Math.round((parent.height - height) / 2)
            width: Math.max(0, parent.width - x - Theme.px(9))
            visible: root.searchOpen        // at once: it takes the keyboard right after the click
            clip: true
            font.family: Theme.font
            font.pixelSize: Theme.px(13)
            font.weight: Font.Medium
            color: Config.text
            selectionColor: Config.textSelection
            selectedTextColor: Config.text
            selectByMouse: true
            activeFocusOnPress: true
            cursorDelegate: Rectangle {
                width: Math.max(1, Theme.px(1.5))
                color: Config.text
                visible: field.activeFocus
            }

            onTextChanged: root.query = text
            // searching lasts as long as the field has the keyboard (like the quick
            // note); left empty, it turns back into the button
            onActiveFocusChanged: {
                Ui.clipboardSearching = activeFocus;
                if (!activeFocus && text.length === 0)
                    root.searchOpen = false;
            }
            Keys.onEscapePressed: {
                text = "";
                Ui.clipboardSearching = false;
                focus = false;
                root.searchOpen = false;
            }
        }
    }

    // when searching stops (a click outside the shell ...), drop the text cursor
    Connections {
        target: Ui

        function onClipboardSearchingChanged() {
            if (!Ui.clipboardSearching)
                field.focus = false;
        }
    }

    // nothing to show: a quiet line in the middle of the list
    Txt {
        visible: (Clipboard.loaded && Clipboard.entries.length === 0) || (Clipboard.entries.length > 0 && root.shown.length === 0)
        x: list.x
        width: list.width
        y: root.listTop + Theme.px(10)
        horizontalAlignment: Text.AlignHCenter
        text: Clipboard.entries.length === 0 ? "Nothing copied yet" : "No matches"
        color: Config.textDim
        font.pixelSize: Theme.px(14)
        font.weight: Font.Medium
    }

    ListView {
        id: list
        x: root.leftPad
        y: root.listTop
        width: Theme.clipW - root.leftPad - root.edge
        height: root.contentH - root.listTop - root.edge
        clip: true
        spacing: Theme.px(6)
        boundsBehavior: Flickable.StopAtBounds
        interactive: false          // scrolled by WheelScroll (below)
        model: rows

        // something new pops in: the entries under it slide down to make room,
        // then it fades in and grows from a little smaller; a deleted one fades out
        add: Transition {
            SequentialAnimation {
                PropertyAction {
                    property: "opacity"
                    value: 0
                }
                PropertyAction {
                    property: "scale"
                    value: 0.8
                }
                PauseAnimation {
                    duration: Theme.ms(60)
                }
                ParallelAnimation {
                    Anim {
                        property: "opacity"
                        to: 1
                        duration: Theme.durSmall
                        curve: Theme.curveDecel
                    }
                    Anim {
                        property: "scale"
                        to: 1
                        duration: Theme.durPop
                        curve: Theme.curveSpring
                    }
                }
            }
        }
        displaced: Transition {
            Anim {
                property: "y"
                duration: Theme.durClose
                curve: Theme.curveDecel
            }
            // (an entry pushed down while it was still popping in ends fully shown)
            Anim {
                properties: "opacity,scale"
                to: 1
                duration: Theme.durClose
                curve: Theme.curveDecel
            }
        }
        move: Transition {
            Anim {
                property: "y"
                duration: Theme.durClose
                curve: Theme.curveDecel
            }
        }
        remove: Transition {
            Anim {
                property: "opacity"
                to: 0
                duration: Theme.durSmall
            }
            Anim {
                property: "scale"
                to: 0.9
                duration: Theme.durSmall
            }
        }

        delegate: Item {
            id: entry
            required property string eid
            required property string kind
            required property string body
            required property string path
            required property real iw
            required property real ih
            // the entry as services/Clipboard.qml has it (to copy or delete it)
            readonly property var entryData: ({
                    id: eid,
                    kind: kind,
                    text: body,
                    path: path,
                    w: iw,
                    h: ih
                })

            readonly property bool isImage: kind === "image"
            readonly property real pad: Theme.px(12)         // text: left and right
            readonly property real textPad: Theme.px(9)      // text: top and bottom
            readonly property real picPad: Theme.px(6)       // a picture: all round

            // pictures: as wide as the card allows, at most 160 px tall
            readonly property real aspect: isImage && iw > 0 ? ih / iw : 0
            readonly property real picH: isImage ? Math.round(Math.min((width - 2 * picPad) * aspect, Theme.px(160))) : 0
            readonly property real picW: isImage ? (aspect > 0 ? Math.round(picH / aspect) : 0) : 0

            width: list.width
            height: isImage ? picH + 2 * picPad : textPad + label.height + textPad

            // a solid grey card, a little lighter under the pointer
            Rectangle {
                anchors.fill: parent
                radius: Theme.px(12)
                color: area.containsMouse ? Config.outline : Config.selected
                scale: area.pressed ? 0.98 : 1

                Behavior on color {
                    CAnim {}
                }
                Behavior on scale {
                    Anim {
                        duration: Theme.durFast
                        curve: Theme.curveSpring
                    }
                }
            }

            // text: up to three lines, ending in … when there is more
            Txt {
                id: label
                visible: !entry.isImage
                x: entry.pad
                y: entry.textPad
                width: entry.width - 2 * entry.pad
                text: entry.body
                textFormat: Text.PlainText
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
                verticalAlignment: Text.AlignTop
                font.pixelSize: Theme.px(16)
                font.weight: Font.Medium
            }

            // picture, with rounded corners inside the card
            ClippingRectangle {
                visible: entry.isImage
                x: Math.round((entry.width - width) / 2)
                y: entry.picPad
                width: entry.picW
                height: entry.picH
                radius: Theme.px(12) - entry.picPad
                color: "transparent"

                Image {
                    anchors.fill: parent
                    source: entry.isImage ? "file://" + entry.path : ""
                    sourceSize.width: Math.ceil(entry.picW * 1.5)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton)
                        Clipboard.remove(entry.entryData);
                    else
                        Clipboard.copy(entry.entryData);
                }
            }
        }
    }

    // the wheel over the list: Qt's scrolling, Config.scrollStep px a notch
    Item {
        x: list.x
        y: list.y
        width: list.width
        height: list.height

        WheelScroll {
            flickable: list
        }
    }
}
