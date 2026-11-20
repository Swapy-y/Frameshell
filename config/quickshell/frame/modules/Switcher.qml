import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.components

// ═══════════════════════════════════════════════════════════════════════════
//  Switcher.qml - app switcher ("Switch between open windows", Super+Space).
//
//  Hyprland binds call it through IPC (see hyprland.lua):
//    qs -c frame ipc call switcher next      (Super+Space)
//    qs -c frame ipc call switcher prev      (not bound by default)
//    qs -c frame ipc call switcher release   (Super released -> switch to the selected window)
//
//  Hold Super and tap Space to walk through the apps, let go of Super to
//  switch. Alt works the same way if you bind the switcher to Alt+Tab instead.
//
//  Any other shortcut closes it, without switching (SUPER + arrow keys,
//  SUPER + Q ...): hyprland.lua does that while it knows the switcher is open
//  (frameshell_switcher). So does a click anywhere outside it (SUPER held: Hyprland's
//  SUPER + drag is off meanwhile).
//
//  The island grows into it (components/IslandSheet.qml): its clock row becomes
//  the title, the apps come out under it (with Island popups off,
//  Config.dynamicPopups: a card in the middle of the screen, the title on top). It fits its content: with 2 open apps
//  it shows 2 rows, with more than Config.switcherMaxRows the list scrolls (Space,
//  Tab, arrow keys or the mouse wheel). Its width follows the longest app name.
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    id: root

    property bool open: false
    property var items: []

    // hyprland.lua closes the switcher when another shortcut is used while it is open:
    // tell it when it opens and closes (a hyprland.lua without frameshell_switcher: nothing)
    onOpenChanged: {
        if (Hyprland.usingLua)
            Hyprland.dispatch("(frameshell_switcher or function() return function() end end)(" + open + ")");
    }
    property int index: 0

    // Every IPC call is a separate `qs` process, so on a very quick Super+Space
    // tap the "Super released" call can arrive *before* the "Space pressed" call. We
    // remember a release that found the switcher closed, and if a step follows
    // right after it, we switch immediately instead of opening a switcher that
    // would wait for a release which has already happened.
    property double lastRelease: 0

    function step(dir) {
        if (!open) {
            const list = Apps.ordered.slice();
            if (list.length === 0)
                return;
            const start = list.length > 1 ? (dir > 0 ? 1 : list.length - 1) : 0;
            if (Date.now() - lastRelease < 250) {
                lastRelease = 0;
                Apps.activate(list[start]);
                return;
            }
            items = list;
            index = start;
            open = true;
        } else if (items.length > 0) {
            index = (index + dir + items.length) % items.length;
        }
    }

    // Switch to the selected window. While the switcher holds the keyboard
    // (an "exclusive" layer) Hyprland refuses to give it to a window, and when
    // the switcher lets go it hands the keyboard back to the previous window.
    // So the window is focused right away (the workspace changes at once) and
    // once more a moment later, after the switcher has let go: then it really
    // gets the keyboard and you can type into it straight away.
    property var pending: null

    function confirm() {
        if (!open)
            return;
        open = false;
        const t = items[index];
        if (t) {
            Apps.activate(t);
            pending = t;
            refocus.restart();
        }
    }

    Timer {
        id: refocus
        interval: 120
        onTriggered: {
            const t = root.pending;
            root.pending = null;
            if (t && Apps.ordered.indexOf(t) >= 0)
                Apps.focusOnly(t);
        }
    }

    // Super (or Alt) was released
    function released() {
        if (open)
            confirm();
        else
            lastRelease = Date.now();
    }

    function cancel() {
        open = false;
    }

    IpcHandler {
        target: "switcher"

        function next(): void {
            root.step(1);
        }

        function prev(): void {
            root.step(-1);
        }

        function release(): void {
            root.released();
        }

        function confirm(): void {
            root.confirm();
        }

        function cancel(): void {
            root.cancel();
        }
    }

    // geometry: the launcher's rows and sides; the title sits where the island's clock is
    readonly property real rowH: Theme.pop(52)
    readonly property real rowGap: Theme.pop(4)
    readonly property real pad: Theme.pop(14)          // the sides and the bottom
    readonly property real gap: Theme.pop(6)           // title row - first row
    readonly property real minW: Theme.pop(420)
    readonly property real maxW: Theme.pop(620)        // the launcher's width
    function listHeight(rows) {
        return rows * rowH + (rows - 1) * rowGap;
    }

    FontMetrics {
        id: fm
        font.family: Theme.font
        font.pixelSize: Theme.pop(17)
        font.weight: Font.Medium
    }

    // width: icon + longest name + paddings (as AppRow lays them out)
    readonly property real wantedW: {
        let longest = 0;
        for (let i = 0; i < items.length; i++)
            longest = Math.max(longest, fm.advanceWidth(Apps.info(items[i]).name));
        return Math.min(maxW, Math.max(minW, Math.ceil(2 * pad + Theme.pop(13 + 32 + 16 + 16) + longest)));
    }
    readonly property real shownRows: Math.max(1, Math.min(items.length, Config.switcherMaxRows))

    // The island grows into it (components/IslandSheet.qml): its clock row becomes the
    // title, the open apps come out under it, and it shrinks back into the notch. In its
    // own window above everything (it also opens over a fullscreen app), with the
    // island's colours (framePalette).
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
            WlrLayershell.namespace: "frame-switcher"
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            // the whole screen; while open everything outside it is a click-catcher that
            // closes it (without switching), like the launcher's
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            mask: Region {
                item: root.open ? backdrop : sheet.area
            }

            Item {
                id: backdrop
                anchors.fill: parent

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onPressed: root.cancel()
                }
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.cancel();
                    } else if (event.key === Qt.Key_Space && (event.modifiers & (Qt.MetaModifier | Qt.AltModifier))) {
                        // Super+Space reached the switcher itself: next app
                        root.step((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.confirm();
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        root.step((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                        root.step(-1);
                    }
                    event.accepted = true;
                }

                // letting go of Super (or Alt) confirms (when this window already has the keyboard)
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta || event.key === Qt.Key_Alt) {
                        root.confirm();
                        event.accepted = true;
                    }
                }
            }

            IslandSheet {
                id: sheet

                // the title's row: out of the island, the island's clock row (what you see of the
                // closed notch); as a card in the middle (Island popups off), its own row on top
                readonly property real titleRowH: centered ? Theme.pop(48) : Theme.notchH - Theme.notchShift
                readonly property real titleY: centered ? Theme.pop(24) : Theme.notchH / 2 - Theme.notchShift
                readonly property real listTop: titleRowH + root.gap

                open: root.open
                sheetW: root.wantedW
                sheetH: listTop + root.listHeight(root.shownRows) + root.pad

                // the title, where the island's clock is (or on top of the card)
                Txt {
                    x: Math.round((parent.width - width) / 2)
                    y: Math.round(sheet.titleY - height / 2)
                    text: "Switch app"
                    font.pixelSize: Theme.fsClock
                    font.weight: Font.DemiBold
                }

                ListView {
                    id: list
                    x: root.pad
                    y: sheet.listTop
                    width: parent.width - 2 * root.pad
                    height: root.listHeight(root.shownRows)
                    interactive: root.items.length > Config.switcherMaxRows     // wheel / drag scrolling
                    clip: true
                    spacing: root.rowGap
                    model: root.items
                    currentIndex: root.index
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0

                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: AppRow {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property var inf: Apps.info(modelData)

                        width: list.width
                        height: root.rowH
                        name: inf.name
                        icon: inf.icon
                        selected: index === root.index
                        faded: Apps.isMinimized(modelData)      // minimized (SUPER + H): faded, as on the dock
                        onClicked: {
                            root.index = row.index;
                            root.confirm();
                        }
                    }
                }
            }
        }
    }
}
