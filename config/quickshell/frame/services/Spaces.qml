pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs
import "workspaces.js" as Workspaces

// ═══════════════════════════════════════════════════════════════════════════
//  Spaces.qml - Hyprland workspaces for the pill indicator in the island.
//
//  The island always shows Config.workspaceCount pills (4). When you open a
//  window on the last one, the next pill appears; pills above the first four
//  disappear again once their workspace is empty (the rules are written down
//  in workspaces.js).
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    // ids of the pills that are shown right now, sorted
    property var ids: Workspaces.pillIds([], 1, Config.workspaceCount, Config.workspaceMax)

    // every pill the island can ever show: it keeps one slot per id, so a pill
    // can grow in and shrink away instead of popping in and out
    readonly property var slots: {
        const last = Math.max(Config.workspaceMax, Config.workspaceCount, ids.length > 0 ? ids[ids.length - 1] : 1);
        const all = [];
        for (let i = 1; i <= last; i++)
            all.push(i);
        return all;
    }

    function refresh() {
        const ws = Hyprland.workspaces.values;
        const occupied = [];
        for (let i = 0; i < ws.length; i++) {
            if (ws[i].id > 0 && ws[i].toplevels.values.length > 0)
                occupied.push(ws[i].id);
        }
        const next = Workspaces.pillIds(occupied, focusedId, Config.workspaceCount, Config.workspaceMax);
        if (JSON.stringify(next) !== JSON.stringify(ids))
            ids = next;
    }

    // the workspaces with tiling off (SUPER + Page Down): hyprland.lua writes their numbers into
    // ~/.local/state/frameshell/untiled whenever that changes (and none when Hyprland starts);
    // their small pill in the island is a bit lighter (Config.pillUntiled)
    property var untiled: []
    FileView {
        id: untiledFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/frameshell/untiled"
        printErrors: false
        watchChanges: true
        // a new file reports itself twice (the file and its folder): read it once
        onFileChanged: untiledReload.restart()
        onLoaded: {
            const ids = text().trim().split(/\s+/).map(Number).filter(n => Number.isInteger(n) && n > 0);
            if (JSON.stringify(ids) !== JSON.stringify(root.untiled))
                root.untiled = ids;
        }
        onLoadFailed: root.untiled = []
    }
    Timer {
        id: untiledReload
        interval: 30
        onTriggered: untiledFile.reload()
    }

    function go(id) {
        Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ workspace = " + id + " })" : "workspace " + id);
    }

    // Windows open, close and move in bursts; wait a moment so Quickshell has
    // updated its own lists before we read them.
    Timer {
        id: settle
        interval: 40
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland.workspaces

        function onValuesChanged() {
            settle.restart();
        }
    }

    Connections {
        target: Hyprland.toplevels

        function onValuesChanged() {
            settle.restart();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent() {
            settle.restart();
        }

        function onFocusedWorkspaceChanged() {
            settle.restart();
        }
    }

    Connections {
        target: Config

        function onWorkspaceCountChanged() {
            settle.restart();
        }

        function onWorkspaceMaxChanged() {
            settle.restart();
        }
    }

    Component.onCompleted: {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        refresh();
    }
}
