pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ═══════════════════════════════════════════════════════════════════════════
//  Notes.qml - The quick note text. It is saved automatically to
//  ~/.local/state/quickshell/by-shell/<id>/quick-note.txt
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    property string text: ""
    property bool loaded: false

    function edit(newText) {
        if (newText === text)
            return;
        text = newText;
        saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: file.setText(root.text)
    }

    FileView {
        id: file
        path: Quickshell.statePath("quick-note.txt")
        printErrors: false
        atomicWrites: true

        onLoaded: {
            root.text = file.text();
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
}
