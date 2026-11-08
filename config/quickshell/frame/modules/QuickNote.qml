import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.components
import "../components/shapes.js" as Shapes

// ═══════════════════════════════════════════════════════════════════════════
//  QuickNote.qml - a note that opens on the right edge of the screen (hover
//  the middle of the right frame). It grows with the text, stays centred
//  vertically, and stops at Config.noteMaxHeightFraction of the screen height
//  (then it scrolls). Click into it to type; Esc or clicking elsewhere stops
//  editing. The text is saved automatically (services/Notes.qml).
//
//  The round button next to the title: Save (a copy of the note in a text
//  file you pick; the file dialog is zenity's, scripts/note.sh).
// ═══════════════════════════════════════════════════════════════════════════
Panel {
    id: root

    // true while the pointer touches the hot strip of the frame (set by Overlay.qml)
    property bool hot: false

    HoverLatch {
        id: latch
        // the calendar closes the note right away and keeps it closed while it is open
        input: !Ui.calendarOpen && (root.hot || panelHover.hovered || Ui.noteEditing)
    }

    open: latch.open && !Ui.calendarOpen
    attachRight: true
    resizeDuration: Theme.durFast        // follow typing quickly

    // the header like the clipboard's: a 28 px row 12 px from the top, the note
    // starting 15 px under it
    readonly property real headerTop: Theme.px(12)
    readonly property real buttonSize: Theme.px(28)
    readonly property real titleBlock: headerTop + buttonSize + Theme.px(15)
    readonly property real maxHeight: Math.max(Theme.noteMinH, parent.height * Config.noteMaxHeightFraction)

    // the text sits on a grey card like a clipboard entry: the card 12 px from the
    // panel's border, the edge of the screen and the bottom (centred between the
    // border and the screen's edge), the text 12 px / 9 px inside it
    readonly property real edge: Theme.px(12)
    readonly property real textPadX: Theme.px(12)
    readonly property real textPadY: Theme.px(9)

    contentW: Theme.noteW
    contentH: Shapes.clamp(titleBlock + 2 * textPadY + edit.contentHeight + edge, Theme.noteMinH, maxHeight)

    HoverHandler {
        id: panelHover
    }


    // "Quick note" and its Save button (the island's round buttons), the two in
    // the middle (between the panel's border and the edge of the screen)
    Item {
        id: header
        readonly property real gap: Theme.px(10)
        x: Math.round((Theme.noteW - width) / 2)
        y: root.headerTop
        width: Math.ceil(title.width) + gap + saveButton.width
        height: root.buttonSize

        Txt {
            id: title
            y: Math.round((parent.height - height) / 2)
            text: "Quick note"
            font.pixelSize: Theme.px(21)
            font.weight: Font.DemiBold
        }

        RingButton {
            id: saveButton
            x: Math.ceil(title.width) + header.gap
            width: root.buttonSize
            icon: "note-save"
            iconSize: Theme.px(16)
            outline: false
            offColor: Config.selected
            hoverColor: offColor             // no change under the pointer
            iconColor: Config.text
            onClicked: root.save()
        }
    }

    // ── Save ──────────────────────────────────────────────────────────────
    // scripts/note.sh shows the "Save As" dialog and prints the file picked; the
    // shell writes the note into it
    function save() {
        if (!picker.running)
            picker.running = true;
    }

    Process {
        id: picker
        command: ["bash", Quickshell.shellPath("scripts/note.sh"), "pick-save"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path.length === 0)
                    return;                 // cancelled
                saveFile.path = path;
                saveFile.setText(edit.text);
            }
        }
    }

    FileView {
        id: saveFile
        preload: false          // only written
        atomicWrites: true
        printErrors: false
    }

    Rectangle {
        id: card
        x: root.edge
        y: root.titleBlock
        width: Theme.noteW - 2 * root.edge
        height: root.contentH - root.titleBlock - root.edge
        radius: Theme.px(12)
        color: Config.selected

        // a click anywhere on the card (around the text too) starts typing at the end
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: {
                edit.forceActiveFocus();
                edit.cursorPosition = edit.length;
            }
        }

        Flickable {
            id: flick
            x: root.textPadX
            y: root.textPadY
            width: card.width - 2 * root.textPadX
            height: card.height - 2 * root.textPadY
            contentWidth: width
            contentHeight: edit.contentHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: false          // scrolled by WheelScroll (below) and by the text cursor

            function ensureVisible(r) {
                if (contentY >= r.y)
                    contentY = r.y;
                else if (contentY + height <= r.y + r.height)
                    contentY = r.y + r.height - height;
            }

            TextEdit {
                id: edit
                width: flick.width
                color: Config.text
                selectionColor: Config.textSelection
                selectedTextColor: Config.text
                // the clipboard entries' text: Clarity City Medium, 16 px
                font.family: Theme.font
                font.pixelSize: Theme.px(16)
                font.weight: Font.Medium
                renderType: Text.QtRendering
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                selectByMouse: true
                persistentSelection: false
                activeFocusOnPress: true
                cursorDelegate: Rectangle {
                    width: Math.max(1, Theme.px(1.5))
                    color: Config.text
                    visible: edit.activeFocus
                }

                // one-way: the stored note is loaded once, afterwards edits are saved
                onTextChanged: {
                    if (root.synced)
                        Notes.edit(text);
                }
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)

                // editing lasts exactly as long as the editor has the keyboard; losing it
                // (click elsewhere, another window takes focus) lets the panel fold again
                onActiveFocusChanged: Ui.noteEditing = activeFocus

                Keys.onEscapePressed: {
                    Ui.noteEditing = false;
                    focus = false;
                }
            }

            Txt {
                visible: edit.text.length === 0 && !edit.activeFocus
                text: "Click to write a note…"
                color: Config.textFaint
                font.pixelSize: Theme.px(16)
                font.weight: Font.Medium
            }
        }

        // the wheel over the text: Qt's scrolling, Config.scrollStep px a notch
        Item {
            anchors.fill: flick

            WheelScroll {
                flickable: flick
            }
        }
    }

    // load the stored note into the editor once
    property bool synced: false

    function sync() {
        if (Notes.loaded && !synced) {
            edit.text = Notes.text;
            synced = true;
        }
    }

    Component.onCompleted: sync()

    Connections {
        target: Notes

        function onLoadedChanged() {
            root.sync();
        }
    }

    // when editing stops, drop the text cursor
    Connections {
        target: Ui

        function onNoteEditingChanged() {
            if (!Ui.noteEditing)
                edit.focus = false;
        }
    }
}
