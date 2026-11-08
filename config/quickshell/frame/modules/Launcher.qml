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
//  Launcher.qml - app launcher: the app switcher's look with a search bar on
//  top.
//
//  Open it with Super+R (hyprland.lua calls it through IPC):
//    qs -c frame ipc call launcher toggle | open | close
//
//  Type to search (several words must all match, "chrm" finds Chromium).
//  Up / Down / Tab move, Enter launches, Esc closes, the mouse wheel scrolls.
//  Often used apps float to the top. The panel is only as tall as the results:
//  few matches = small panel, more than Config.launcherMaxRows = scrolling.
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
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            // stays alive until the fade-out has finished
            visible: root.open || panel.opacity > 0.01

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

            // while open, everything outside the panel is a click-catcher that closes it
            mask: Region {
                item: root.open ? backdrop : panel
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

            Rectangle {
                id: panel

                readonly property real rowH: Theme.pop(52)
                readonly property real rowGap: Theme.pop(4)        // between two rows
                readonly property real pad: Theme.pop(16)
                readonly property real searchH: Theme.pop(44)
                readonly property real gap: Theme.pop(12)          // search field - first row
                readonly property real emptyH: Theme.pop(52)       // "No apps found"
                function listHeight(rows) {
                    return rows > 0 ? rows * rowH + (rows - 1) * rowGap : emptyH;
                }
                readonly property int shownRows: Math.min(root.results.length, Config.launcherMaxRows)
                readonly property real listH: listHeight(shownRows)

                // In the middle of the screen at the size it opens with (an empty search:
                // all apps, up to Config.launcherMaxRows). While you type, the top - the
                // search field - stays where it is and the panel shrinks from the bottom.
                readonly property int openRows: Math.min(root.apps.length, Config.launcherMaxRows)
                readonly property real openH: pad + searchH + gap + listHeight(openRows) + pad

                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round((parent.height - openH) / 2)
                width: Theme.pop(580)
                height: pad + searchH + gap + listH + pad
                radius: Theme.pop(24)
                color: Config.surface               // see-through with the shell's blur
                border.width: Theme.border
                border.color: Config.outline

                // soft shadow (follows the panel while it fades and scales)
                Loader {
                    z: -1
                    anchors.fill: parent
                    active: Config.shadows && Config.shadowStrength > 0
                    source: "../components/CardShadow.qml"
                }

                // the panel grows / shrinks with the number of results - while it is open
                // (opening, it is at once as tall as the empty search makes it: the last
                // search is cleared while it is closed)
                Behavior on height {
                    enabled: root.open
                    Anim {
                        curve: Theme.curveDecel
                        duration: Theme.durOpen
                    }
                }

                opacity: root.open ? 1 : 0
                scale: root.open ? 1 : 0.94     // grows from its centre, like the password dialog
                // opening: a quick fade + grow (Theme.durPop); closing as before
                Behavior on opacity {
                    Anim {
                        curve: root.open ? Theme.curveDecel : Theme.curveStandard
                        duration: root.open ? Theme.durPopFade : Theme.durFast
                    }
                }
                Behavior on scale {
                    Anim {
                        curve: root.open ? Theme.curveDecel : Theme.curveAccel
                        duration: root.open ? Theme.durPop : Theme.durClose
                    }
                }

                // swallow clicks on the panel so they do not reach the backdrop
                MouseArea {
                    anchors.fill: parent
                }

                // ── search bar ────────────────────────────────────────────
                Rectangle {
                    id: searchBar
                    x: panel.pad
                    y: panel.pad
                    width: parent.width - 2 * panel.pad
                    height: panel.searchH
                    radius: Theme.pop(14)
                    color: Config.selected

                    // the whole field: the text cursor, and a click puts the cursor in it (the text
                    // itself handles its own clicks)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: input.forceActiveFocus()
                    }

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: Theme.pop(17)
                        anchors.rightMargin: Theme.pop(17)
                        verticalAlignment: TextInput.AlignVCenter
                        color: Config.text
                        selectionColor: Config.textSelection
                        selectedTextColor: Config.text
                        font.family: Theme.font
                        font.pixelSize: Theme.pop(17)
                        font.weight: Font.Medium
                        renderType: Text.QtRendering
                        clip: true
                        focus: true
                        onTextChanged: root.query = text

                        // every opening starts with an empty bar
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
                        color: Config.textDim
                        font.pixelSize: Theme.pop(17)
                        font.weight: Font.Medium
                    }
                }

                // ── results ───────────────────────────────────────────────
                ListView {
                    id: list
                    x: panel.pad
                    y: panel.pad + panel.searchH + panel.gap
                    width: parent.width - 2 * panel.pad
                    // no taller than the panel is right now: while it grows (the search
                    // emptied) the rows come into view with it, never below it
                    height: Math.max(0, Math.min(panel.listH, panel.height - y - panel.pad))
                    interactive: root.results.length > Config.launcherMaxRows     // wheel / drag scrolling
                    clip: true
                    spacing: panel.rowGap
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
                        height: panel.rowH
                        name: modelData.name
                        icon: IconPacks.path(modelData.entry.icon)
                        selected: index === root.index
                        onClicked: root.launch(modelData)
                    }
                }

                Txt {
                    visible: root.results.length === 0
                    x: panel.pad
                    y: panel.pad + panel.searchH + panel.gap
                    width: parent.width - 2 * panel.pad
                    height: panel.emptyH
                    horizontalAlignment: Text.AlignHCenter
                    text: "No apps found"
                    color: Config.textDim
                    font.pixelSize: Theme.pop(17)
                    font.weight: Font.Medium
                }
            }
        }
    }
}
