import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.components
import "../components/emoji.js" as Emoji

// ═══════════════════════════════════════════════════════════════════════════
//  EmojiPicker.qml - the emoji picker (SUPER + .): the launcher's look, a grid
//  of emoji under a search field, on the screen with the focused window.
//
//  Type to search, by name and by keywords ("heart", "thumbsup", "flag
//  poland"; several words must all match). The arrow keys move through the
//  grid, Page Up / Down by a page, Tab / Shift + Tab jump to the next /
//  previous group. Enter or a click picks one; Esc, SUPER + . or a click beside
//  it closes it. The row at the bottom jumps to a group; the ones you picked
//  last come first ("Recently used", Store.emojiRecent).
//
//  A picked emoji is copied to the clipboard and, when you were typing in a
//  text field, put into it right away, the way an input method does it
//  (scripts/emoji.sh, scripts/emoji-insert.py: GTK and Qt apps, Firefox,
//  kitty ...). Apps that don't say whether a text field has the focus
//  (Electron apps like VS Code or Discord, X11 apps) get it typed with wtype
//  instead, if it is installed; otherwise paste it with Ctrl + V.
//
//  Like the launcher, any other shortcut closes it first (hyprland.lua, which
//  the picker tells when it opens and closes: frameshell_emoji), and SUPER +
//  drag is off while it is open, so a click with SUPER held closes it too.
//
//  Started by hyprland.lua with an event on Hyprland's socket
//  ("custom>>frameshell-emoji toggle": at once), or by hand:
//    qs -c frame ipc call emoji toggle | open | close
//  The emoji are in components/emoji.js (made by tools/make-emoji.py).
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    id: root

    property bool open: false
    property string query: ""
    property int index: 0                   // the selected one (a place in `shown`)
    property int hovered: -1                // the one under the pointer (its name shows)
    property string screenName: ""          // the screen it is on

    readonly property int cols: 11          // emoji in a row
    readonly property int recentMax: 22     // two rows

    // tell hyprland.lua (any other shortcut closes the picker first, SUPER + drag is off);
    // a hyprland.lua without frameshell_emoji: nothing
    onOpenChanged: {
        if (Hyprland.usingLua)
            Hyprland.dispatch("(frameshell_emoji or function() return function() end end)(" + open + ")");
    }

    // lower-case name + keywords of each emoji, for the search
    readonly property var hay: Emoji.list.map(e => (e[1] + " " + e[3]).toLowerCase())
    // emoji -> its place in the list
    readonly property var where: {
        const m = {};
        for (let i = 0; i < Emoji.list.length; i++)
            m[Emoji.list[i][0]] = i;
        return m;
    }
    // the recent ones as they were when it opened (picking one does not reshuffle the
    // grid while it fades out)
    property var recent: []
    readonly property bool searching: query.trim() !== ""

    // the grid without a search: the recent ones, then all by group, each group starting a
    // new row (-1: an empty place at the end of a group's last row)
    //   items   places in Emoji.list
    //   groups  the group of each place (-1 recently used)
    //   starts  where each group starts: {group, at}
    readonly property var whole: {
        const items = [], groups = [], starts = [];
        function endRow(g) {
            while (items.length % cols !== 0) {
                items.push(-1);
                groups.push(g);
            }
        }
        if (recent.length > 0) {
            starts.push({
                group: -1,
                at: 0
            });
            for (const i of recent) {
                items.push(i);
                groups.push(-1);
            }
            endRow(-1);
        }
        let last = -2;
        for (let i = 0; i < Emoji.list.length; i++) {
            const g = Emoji.list[i][2];
            if (g !== last) {
                endRow(last);
                starts.push({
                    group: g,
                    at: items.length
                });
                last = g;
            }
            items.push(i);
            groups.push(g);
        }
        return {
            items: items,
            groups: groups,
            starts: starts
        };
    }
    readonly property var groupStarts: whole.starts

    // the grid: places in Emoji.list (-1: an empty place) - all of them, or the search's matches
    readonly property var shown: {
        if (!searching)
            return whole.items;
        const words = query.toLowerCase().split(/\s+/).filter(w => w.length > 0);
        const first = words[0];
        const hits = [];
        for (let i = 0; i < hay.length; i++) {
            const h = hay[i];
            if (words.every(w => h.indexOf(w) >= 0)) {
                const name = Emoji.list[i][1].toLowerCase();
                // first the ones with every word in the name (those starting with the first word
                // first), then the ones with the first word in the name, then the rest
                const all = words.every(w => name.indexOf(w) >= 0);
                hits.push({
                    i: i,
                    rank: all ? (name.startsWith(first) ? 0 : 1) : (name.indexOf(first) >= 0 ? 2 : 3)
                });
            }
        }
        hits.sort((a, b) => a.rank - b.rank || a.i - b.i);
        return hits.map(h => h.i);
    }

    // the group of a place in the grid: -1 recently used, -2 none (searching)
    function groupAt(k) {
        if (searching || k < 0 || k >= whole.groups.length)
            return -2;
        return whole.groups[k];
    }

    function groupName(g) {
        return g === -1 ? "Recently used" : (g >= 0 ? Emoji.groups[g] : "");
    }

    // a new search: from its first one (and the name shows the selected one again)
    onQueryChanged: {
        index = 0;
        hovered = -1;
    }

    // sent by show(): the search field empties itself
    signal cleared

    function show() {
        Ui.closePopups();
        const names = Quickshell.screens.map(s => s.name);
        const fm = Hyprland.focusedMonitor;
        screenName = fm && names.indexOf(fm.name) >= 0 ? fm.name : (names.length ? names[0] : "");
        recent = (Store.emojiRecent || []).map(c => root.where[c]).filter(i => i !== undefined);
        query = "";
        index = 0;
        hovered = -1;
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

    // select place k; an empty place: the emoji before it (forward: the one after it, Right)
    function select(k, forward) {
        const n = shown.length;
        if (n === 0)
            return;
        k = Math.max(0, Math.min(n - 1, k));
        if (forward)
            while (k < n - 1 && shown[k] < 0)
                k++;
        while (k > 0 && shown[k] < 0)
            k--;
        index = k;
        hovered = -1;           // the keys: the name of the selected one, not the one under the pointer
    }

    // Tab / Shift + Tab: the first one of the next / previous group (Shift + Tab inside a
    // group: its first one)
    function jumpGroup(dir) {
        if (searching)
            return;
        const s = groupStarts;
        let cur = 0;
        for (let i = 0; i < s.length; i++)
            if (s[i].at <= index)
                cur = i;
        const next = dir > 0 ? Math.min(s.length - 1, cur + 1) : (s[cur].at < index ? cur : Math.max(0, cur - 1));
        index = s[next].at;
        hovered = -1;
        jumped(index);
    }

    // a jump to a group (Tab, a click on the row at the bottom): its first row at the top
    signal jumped(int at)

    function pick(k) {
        if (!open || k < 0 || k >= shown.length || shown[k] < 0)
            return;
        const ch = Emoji.list[shown[k]][0];
        open = false;
        // to the front of the recent ones
        Store.emojiRecent = [ch].concat((Store.emojiRecent || []).filter(c => c !== ch)).slice(0, recentMax);
        // copied, and - once the window you were in has the keyboard back - put into its
        // text field (scripts/emoji.sh)
        Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/emoji.sh"), ch]);
    }

    IpcHandler {
        target: "emoji"

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

    // hyprland.lua: SUPER + . sends "custom>>frameshell-emoji toggle", another shortcut "... close"
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "custom")
                return;
            if (event.data === "frameshell-emoji toggle")
                root.toggle();
            else if (event.data === "frameshell-emoji close")
                root.hide();
        }
    }

    // one window per screen, only the one on root.screenName shows
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property bool here: modelData.name === root.screenName

            screen: modelData
            // stays until the fade-out has finished
            visible: here && (root.open || panel.opacity > 0.01)

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "frame-emoji"
            WlrLayershell.keyboardFocus: root.open && here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // while open, everything beside the panel is a click-catcher that closes it
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

                readonly property real pad: Theme.pop(16)
                readonly property real searchH: Theme.pop(44)
                readonly property real gap: Theme.pop(10)
                readonly property real headH: Theme.pop(30)      // the group / name line
                readonly property int rows: 6
                readonly property real cell: Math.floor((width - 2 * pad) / root.cols)
                readonly property real tabsH: Theme.pop(40)

                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round((parent.height - height) / 2)
                width: Theme.pop(580)
                height: pad + searchH + gap + headH + rows * cell + gap + tabsH + pad
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

                opacity: root.open && win.here ? 1 : 0
                scale: root.open && win.here ? 1 : 0.94     // grows from its centre, like the launcher
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

                // clicks on the panel stay on it
                MouseArea {
                    anchors.fill: parent
                }

                // ── search field ──────────────────────────────────────────
                Rectangle {
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

                        Connections {
                            target: root

                            function onCleared() {
                                input.text = "";
                                input.forceActiveFocus();
                            }
                        }

                        Keys.onPressed: event => {
                            const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                            if (event.key === Qt.Key_Escape) {
                                root.hide();
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.pick(root.index);
                            } else if (event.key === Qt.Key_Left) {
                                root.select(root.index - 1);
                            } else if (event.key === Qt.Key_Right) {
                                root.select(root.index + 1, true);
                            } else if (event.key === Qt.Key_Up) {
                                root.select(root.index - root.cols);
                            } else if (event.key === Qt.Key_Down) {
                                root.select(root.index + root.cols);
                            } else if (event.key === Qt.Key_PageUp) {
                                root.select(root.index - root.cols * panel.rows);
                            } else if (event.key === Qt.Key_PageDown) {
                                root.select(root.index + root.cols * panel.rows);
                            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && shift)) {
                                // (Shift + Tab: some systems send Tab + Shift instead of Backtab)
                                root.jumpGroup(-1);
                            } else if (event.key === Qt.Key_Tab) {
                                root.jumpGroup(1);
                            } else {
                                return;     // normal typing
                            }
                            event.accepted = true;
                        }
                    }

                    Txt {
                        anchors.fill: input
                        visible: input.text.length === 0
                        text: "Search emoji…"
                        color: Config.textDim
                        font.pixelSize: Theme.pop(17)
                        font.weight: Font.Medium
                    }
                }

                // ── the group at the top of the grid (or how many were found), and the name
                //    of the emoji under the pointer - else of the selected one ──
                Item {
                    id: head
                    x: panel.pad + Theme.pop(8)
                    y: panel.pad + panel.searchH + panel.gap
                    width: parent.width - 2 * panel.pad - Theme.pop(16)
                    height: panel.headH

                    Txt {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.42
                        elide: Text.ElideRight
                        text: root.searching ? (root.shown.length === 0 ? "No emoji found" : root.shown.length + (root.shown.length === 1 ? " result" : " results")) : root.groupName(root.groupAt(grid.topIndex))
                        color: Config.textDim
                        font.pixelSize: Theme.pop(13)
                        font.weight: Font.DemiBold
                    }
                    Txt {
                        readonly property int k: root.hovered >= 0 ? root.hovered : root.index

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.56
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: k >= 0 && k < root.shown.length && root.shown[k] >= 0 ? Emoji.list[root.shown[k]][1] : ""
                        color: Config.text
                        font.pixelSize: Theme.pop(13)
                    }
                }

                // ── the emoji ─────────────────────────────────────────────
                GridView {
                    id: grid

                    // the first one of the row at the top (for the group name above it)
                    readonly property int topIndex: Math.min(count - 1, Math.floor((contentY + cellHeight / 2) / cellHeight) * root.cols)

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: head.y + head.height
                    width: root.cols * panel.cell
                    height: panel.rows * panel.cell
                    cellWidth: panel.cell
                    cellHeight: panel.cell
                    clip: true
                    model: root.shown
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: Math.max(0, panel.cell * 3)

                    // a new search (or a new opening) starts at the top
                    onModelChanged: positionViewAtBeginning()

                    // keep the selected one in sight
                    Connections {
                        target: root

                        function onIndexChanged() {
                            grid.positionViewAtIndex(root.index, GridView.Contain);
                        }

                        function onJumped(at) {
                            grid.positionViewAtIndex(at, GridView.Beginning);
                        }
                    }

                    delegate: Item {
                        id: cell
                        required property int index
                        required property int modelData

                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Theme.pop(2)
                            radius: Theme.pop(10)
                            color: cell.index === root.index ? Config.selected : (cellArea.containsMouse ? Config.hover : "transparent")
                        }
                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData >= 0 ? Emoji.list[cell.modelData][0] : ""
                            font.family: "Noto Color Emoji"
                            font.pixelSize: Theme.pop(26)
                        }
                        MouseArea {
                            id: cellArea
                            anchors.fill: parent
                            enabled: cell.modelData >= 0         // not an empty place
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onContainsMouseChanged: {
                                if (containsMouse)
                                    root.hovered = cell.index;
                                else if (root.hovered === cell.index)
                                    root.hovered = -1;
                            }
                            onClicked: root.pick(cell.index)
                        }
                    }
                }

                Txt {
                    visible: root.searching && root.shown.length === 0
                    anchors.horizontalCenter: grid.horizontalCenter
                    y: grid.y + Theme.pop(24)
                    text: "Try another word"
                    color: Config.textDim
                    font.pixelSize: Theme.pop(15)
                    font.weight: Font.Medium
                }

                // ── the groups: a click jumps there (and ends a search) ──
                Rectangle {
                    x: panel.pad
                    y: grid.y + grid.height + panel.gap / 2
                    width: parent.width - 2 * panel.pad
                    height: 1
                    color: Config.divider
                }

                Row {
                    id: tabs
                    // one emoji for each group of Emoji.groups
                    readonly property var icons: ["😀", "👋", "🐻", "🍔", "✈️", "⚽", "💡", "💕", "🏁"]
                    readonly property int current: root.groupAt(grid.topIndex)

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: grid.y + grid.height + panel.gap
                    height: panel.tabsH
                    spacing: Theme.pop(4)

                    Repeater {
                        model: root.groupStarts

                        Item {
                            id: tab
                            required property var modelData
                            readonly property bool active: tabs.current === modelData.group
                            readonly property color ink: active || tabArea.containsMouse ? Config.text : Config.textDim

                            width: Theme.pop(44)
                            height: tabs.height

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: Theme.pop(2)
                                radius: Theme.pop(10)
                                color: tab.active ? Config.selected : (tabArea.containsMouse ? Config.hover : "transparent")
                            }
                            // recently used: a clock
                            Item {
                                visible: tab.modelData.group === -1
                                anchors.centerIn: parent
                                width: Theme.pop(18)
                                height: width

                                readonly property real line: Math.max(1, Theme.pop(2))

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: parent.line
                                    border.color: tab.ink
                                }
                                Rectangle {     // the hour hand: up
                                    x: (parent.width - width) / 2
                                    y: Theme.pop(4)
                                    width: parent.line
                                    height: parent.height / 2 - Theme.pop(4) + parent.line / 2
                                    color: tab.ink
                                }
                                Rectangle {     // the minute hand: right
                                    x: (parent.width - parent.line) / 2
                                    y: (parent.height - height) / 2
                                    width: parent.width / 2 - Theme.pop(4) + parent.line / 2
                                    height: parent.line
                                    color: tab.ink
                                }
                            }
                            Text {
                                visible: tab.modelData.group >= 0
                                anchors.centerIn: parent
                                text: tab.modelData.group >= 0 ? tabs.icons[tab.modelData.group] || "" : ""
                                font.family: "Noto Color Emoji"
                                font.pixelSize: Theme.pop(19)
                                opacity: tab.active || tabArea.containsMouse ? 1 : 0.55
                            }
                            MouseArea {
                                id: tabArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    input.text = "";            // ends a search: the whole grid again
                                    root.index = tab.modelData.at;
                                    root.jumped(tab.modelData.at);
                                    input.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
