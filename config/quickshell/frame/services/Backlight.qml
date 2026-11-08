pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ═══════════════════════════════════════════════════════════════════════════
//  Backlight.qml - Screen brightness. Uses scripts/brightness.sh, which talks to
//    - brightnessctl  (laptop panels), or
//    - ddcutil        (desktop monitors over DDC/CI)
//  The brightness is read once, when the shell starts (not each time the slider
//  panel opens: over DDC that is slow and made the panel lag); after that the
//  slider shows what it set.
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    property real value: 0.5          // 0..1
    property bool supported: false
    property bool probed: false

    readonly property string script: Quickshell.shellPath("scripts/brightness.sh")

    function refresh() {
        if (!getter.running)
            getter.running = true;
    }

    // called while dragging the slider; the real write is debounced
    function setValue(v) {
        value = Math.max(0.01, Math.min(1, v));
        debounce.restart();
    }

    property bool _dirty: false

    Timer {
        id: debounce
        interval: 150
        onTriggered: {
            if (setter.running) {
                root._dirty = true;
            } else {
                setter.command = ["bash", root.script, "set", Math.round(root.value * 100).toString()];
                setter.running = true;
            }
        }
    }

    Process {
        id: getter
        command: ["bash", root.script, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                root.probed = true;
                if (!isNaN(v) && v >= 0) {
                    root.supported = true;
                    if (!debounce.running && !setter.running)
                        root.value = Math.max(0.01, Math.min(1, v / 100));
                } else {
                    root.supported = false;
                }
            }
        }
    }

    Process {
        id: setter
        onRunningChanged: {
            if (!running && root._dirty) {
                root._dirty = false;
                debounce.restart();
            }
        }
    }

    Component.onCompleted: refresh()
}
