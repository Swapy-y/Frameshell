pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// ═══════════════════════════════════════════════════════════════════════════
//  Volume.qml - Default audio output volume (PipeWire / WirePlumber).
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null

    // 0..1
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false

    function setVolume(v) {
        if (!ready)
            return;
        sink.audio.volume = Math.max(0, Math.min(1, v));
        if (v > 0 && sink.audio.muted)
            sink.audio.muted = false;
    }

    function toggleMute() {
        if (ready)
            sink.audio.muted = !sink.audio.muted;
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
