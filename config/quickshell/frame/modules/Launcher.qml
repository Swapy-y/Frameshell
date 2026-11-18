import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.components
import "../components/search.js" as Search

// ═══════════════════════════════════════════════════════════════════════════
//  Launcher.qml - app launcher: the island grows into it - a search field on
//  top, the apps under it (components/IslandSheet.qml; with Island popups off,
//  Config.dynamicPopups, a card in the middle of the screen instead).
//
//  Open it with Super+R (hyprland.lua calls it through IPC):
//    qs -c frame ipc call launcher toggle | open | close
//
//  Type to search (several words must all match, "chrm" finds Chromium).
//  Up / Down / Tab move, Enter launches, Esc closes, the mouse wheel scrolls.
//  Often used apps float to the top. It is only as tall as the results:
//  few matches = small, more than Config.launcherMaxRows = scrolling.
//
//  Any other shortcut closes it (SUPER + arrow keys, SUPER + Q, SUPER + Space ...):
//  hyprland.lua does that while it knows the launcher is open (frameshell_launcher).
//  A click outside it closes it - also with SUPER held: hyprland.lua switches its
//  SUPER + drag off while the launcher is open.
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    id: root

    property bool open: false
    property string query: ""

    // hyprland.lua closes the launcher when another shortcut is used while it is open:
    // tell it when it opens and closes (a hyprland.lua without frameshell_launcher: nothing)
    onOpenChanged: {
        if (Hyprland.usingLua)
            Hyprland.dispatch("(frameshell_launcher or function() return function() end end)(" + open + ")");
    }
    property int index: 0

    // ── apps and ranking ──────────────────────────────────────────────────
    // launch counts, kept in ~/.local/state/quickshell/by-shell/<id>/launcher.json
    property var counts: ({})

    readonly property var apps: {
        const out = [];
        const list = DesktopEntries.applications.values;
        for (let i = 0; i < list.length; i++) {
            const e = list[i];
            if (e.noDisplay)
                continue;
            out.push({
                id: e.id,
                name: e.name,
                generic: e.genericName,
                keywords: e.keywords ? e.keywords.join(";") : "",
                comment: e.comment,
                exec: e.execString,
                entry: e
            });
        }
        return out;
    }

    readonly property var results: Search.rank(apps, query, counts)

    onQueryChanged: index = 0

    // sent by show() so every search bar empties itself, even when the
    // launcher was already open
    signal cleared

    // ── actions ───────────────────────────────────────────────────────────
    function show() {
        Ui.closePopups();
        query = "";
        index = 0;
        cleared();
        open = true;
    }

    function hide() {
        open = false;
    }

    function toggle() {
        if (open)
            hide();
        else
            show();
    }

    function move(dir) {
        if (results.length > 0)
            index = (index + dir + results.length) % results.length;
    }

    function launch(app) {
        if (!app)
            return;
        const e = app.entry;
        open = false;
        if (e.runInTerminal)
            Quickshell.execDetached([Config.terminal, "-e"].concat(Array.from(e.command)));
        else
            e.execute();

        // remember it, so it ranks higher next time
        const next = Object.assign({}, counts);
        next[app.id] = (next[app.id] || 0) + 1;
        counts = next;
        store.setText(JSON.stringify(next));
    }

    function launchSelected() {
        launch(results[index]);
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.show();
        }

        function close(): void {
            root.hide();
        }
    }

    FileView {
        id: store
        path: Quickshell.statePath("launcher.json")
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                root.counts = JSON.parse(text());
            } catch (e) {
                root.counts = {};
            }
        }
    }

    // ── window ────────────────────────────────────────────────────────────
    // The island grows into it (components/IslandSheet.qml): from the closed notch down
    // and out to the launcher - a search field, the apps under it - and back into the
    // notch when it closes. In its own window above everything (it also opens over a
    // fullscreen app), with the island's colours (framePalette).
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            // the island's colours for its pieces (Config.paletteFor)
            readonly property bool framePalette: true

            // stays alive until it has shrunk back into the notch
            visible: root.open || sheet.shown

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "frame-launcher"
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // while open, everything outside it is a click-catcher that closes it
            mask: Region {
                item: root.open ? backdrop : sheet.area
            }

            onVisibleChanged: {
                if (visible)
                    input.forceActiveFocus();
            }

            Item {
                id: backdrop
                anchors.fill: parent

                MouseArea {
                    anchors.fill: parent
                    onPressed: root.hide()
                }
            }

            IslandSheet {
                id: sheet

                // (a little more compact than the switcher)
                readonly property real rowH: Theme.pop(47)
                readonly property real rowGap: Theme.pop(4)        // between two rows
                readonly property real pad: Theme.pop(12)          // the sides and the bottom
                readonly property real padTop: centered ? pad : Theme.pop(9)  // above the search field (under the frame; a card: as at the sides)
                readonly property real searchH: Theme.pop(40)
                readonly property real gap: Theme.pop(9)           // search field - first row
                readonly property real emptyH: Theme.pop(47)       // "No apps found"
                function listHeight(rows) {
                    return rows > 0 ? rows * rowH + (rows - 1) * rowGap : emptyH;
                }
                readonly property int shownRows: Math.min(root.results.length, Config.launcherMaxRows)
                readonly property real listTop: sheet.contentTop + padTop + searchH + gap

                open: root.open
                sheetW: Theme.pop(550)
                sheetH: listTop + listHeight(shownRows) + pad

                // it grows / shrinks with the number of results - while it is open
                // (opening, it is at once as tall as the empty search makes it: the last
                // search is cleared while it is closed)
                Behavior on sheetH {
                    enabled: root.open
                    Anim {
                        curve: Theme.curveDecel
                        duration: Theme.durOpen
                    }
                }

                // ── search field ──────────────────────────────────────────
                Rectangle {
                    id: searchBar
                    x: sheet.pad
                    y: sheet.contentTop + sheet.padTop
                    width: parent.width - 2 * sheet.pad
                    height: sheet.searchH
                    radius: height / 2
                    color: Config.frameColors.controlBackground

                    // the whole field: the text cursor, and a click puts the cursor in it (the text
                    // itself handles its own clicks)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: input.forceActiveFocus()
                    }

                    Icon {
                        id: magnifier
                        x: Theme.pop(14)
                        y: Math.round((parent.height - height) / 2)
                        size: Theme.pop(16)
                        name: "search"
                        color: Config.frameColors.textSecondary
                    }

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: magnifier.x + magnifier.width + Theme.pop(10)
                        anchors.rightMargin: Theme.pop(16)
                        verticalAlignment: TextInput.AlignVCenter
                        color: Config.text
                        selectionColor: Config.frameColors.selectionBackground
                        selectedTextColor: Config.text
                        font.family: Theme.font
                        font.pixelSize: Theme.pop(16)
                        font.weight: Font.Medium
                        renderType: Text.QtRendering
                        clip: true
                        focus: true
                        onTextChanged: root.query = text

                        // every opening starts with an empty field
                        Connections {
                            target: root

                            function onCleared() {
                                input.text = "";
                                input.forceActiveFocus();
                            }
                        }

                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            if (event.key === Qt.Key_Escape) {
                                root.hide();
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launchSelected();
                            } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) || (ctrl && event.key === Qt.Key_N)) {
                                root.move(1);
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_P)) {
                                // (Shift+Tab: some systems send Tab + Shift instead of Backtab)
                                root.move(-1);
                            } else if (event.key === Qt.Key_PageDown) {
                                root.index = Math.min(root.results.length - 1, root.index + Config.launcherMaxRows);
                            } else if (event.key === Qt.Key_PageUp) {
                                root.index = Math.max(0, root.index - Config.launcherMaxRows);
                            } else {
                                return;     // normal typing
                            }
                            event.accepted = true;
                        }
                    }

                    Txt {
                        anchors.fill: input
                        visible: input.text.length === 0
                        text: "Search apps…"
                        color: Config.frameColors.textSecondary
                        font.pixelSize: Theme.pop(16)
                        font.weight: Font.Medium
                    }
                }

                // ── results ───────────────────────────────────────────────
                ListView {
                    id: list
                    x: sheet.pad
                    y: sheet.listTop
                    width: parent.width - 2 * sheet.pad
                    // no taller than the sheet is right now: while it grows (the search
                    // emptied) the rows come into view with it, never below it
                    height: Math.max(0, Math.min(sheet.listHeight(sheet.shownRows), parent.height - y - sheet.pad))
                    interactive: root.results.length > Config.launcherMaxRows     // wheel / drag scrolling
                    clip: true
                    spacing: sheet.rowGap
                    model: root.results
                    currentIndex: root.index
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0

                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: AppRow {
                        id: row
                        required property var modelData
                        required property int index

                        width: list.width
                        height: sheet.rowH
                        name: modelData.name
                        icon: IconPacks.path(modelData.entry.icon)
                        iconSize: Theme.pop(29)
                        fontSize: Theme.pop(16)
                        selected: index === root.index
                        onClicked: root.launch(modelData)
                    }
                }

                Txt {
                    visible: root.results.length === 0
                    x: sheet.pad
                    y: sheet.listTop
                    width: parent.width - 2 * sheet.pad
                    height: sheet.emptyH
                    horizontalAlignment: Text.AlignHCenter
                    text: "No apps found"
                    color: Config.frameColors.textSecondary
                    font.pixelSize: Theme.pop(16)
                    font.weight: Font.Medium
                }
            }
        }
    }
}
