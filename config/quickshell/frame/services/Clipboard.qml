pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Clipboard.qml - the clipboard history shown by the Clipboard panel (left
//  edge). The history is kept by cliphist; scripts/clipboard.sh reads it,
//  copies an entry back and deletes entries.
//
//  entries: newest first, each { id, kind: "text", text } or
//           { id, kind: "image", path, w, h }
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    property var entries: []
    property bool loaded: false

    readonly property string script: Quickshell.shellPath("scripts/clipboard.sh")

    // read the history again (the panel does this every time it opens)
    function refresh() {
        if (lister.running)
            _again = true;
        else
            lister.running = true;
    }

    // put an entry on the clipboard again; cliphist then moves it to the top
    function copy(entry) {
        let type = "";
        if (entry.kind === "image") {
            const ext = entry.path.slice(entry.path.lastIndexOf(".") + 1);
            type = "image/" + ext;
        }
        _run(["bash", script, "copy", entry.id].concat(type.length > 0 ? [type] : []));
    }

    function remove(entry) {
        entries = entries.filter(e => e.id !== entry.id);
        _run(["bash", script, "delete", entry.id]);
    }

    property bool _again: false

    // read it once at the start too, so the panel already has its right size the
    // first time it opens (instead of growing while it opens)
    Component.onCompleted: refresh()

    // detached: wl-copy keeps running in the background to serve the clipboard
    function _run(cmd) {
        Quickshell.execDetached(cmd);
        settle.restart();
    }

    // the history changes a moment later (cliphist stores the copy): read it again
    Timer {
        id: settle
        interval: 400
        onTriggered: root.refresh()
    }

    Process {
        id: lister
        command: ["bash", root.script, "list", String(Config.clipboardMaxItems)]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].length === 0)
                        continue;
                    try {
                        const e = JSON.parse(lines[i]);
                        if (e.kind === "text") {
                            // trim, and skip entries that are only spaces
                            e.text = e.text.replace(/\t/g, "    ").replace(/^\s+|\s+$/g, "");
                            if (e.text.length === 0)
                                continue;
                        }
                        out.push(e);
                    } catch (err) {
                    }
                }
                // only when something changed: a new list rebuilds the panel's
                // entries, and that made its content move while it was opening
                if (JSON.stringify(out) !== JSON.stringify(root.entries))
                    root.entries = out;
                root.loaded = true;
            }
        }
        onExited: {
            if (root._again) {
                root._again = false;
                running = true;
            }
        }
    }
}
