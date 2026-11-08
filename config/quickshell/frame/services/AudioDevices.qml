pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// ═══════════════════════════════════════════════════════════════════════════
//  AudioDevices.qml - the sound devices (PipeWire / WirePlumber) for the
//  Settings app's Devices page: the outputs (speakers, headphones) and inputs
//  (microphones), the one in use of each, its volume and mute.
//
//  Picking one makes it PipeWire's default: apps playing (recording) follow it,
//  and WirePlumber remembers it.
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    // devices, not apps' streams
    readonly property var nodes: Pipewire.nodes.values
    readonly property var outputs: nodes.filter(n => n.audio && n.isSink && !n.isStream).sort((a, b) => label(a).localeCompare(label(b)))
    readonly property var inputs: nodes.filter(n => n.audio && !n.isSink && !n.isStream).sort((a, b) => label(a).localeCompare(label(b)))

    // the ones in use (without a microphone PipeWire may name an output's "monitor" as
    // the input: that is no input here, its volume is the output's)
    readonly property var output: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.isSink ? Pipewire.defaultAudioSink : null
    readonly property var input: Pipewire.defaultAudioSource && !Pipewire.defaultAudioSource.isSink ? Pipewire.defaultAudioSource : null

    // its name as the system gives it ("Built-in Audio Analog Stereo")
    function label(n) {
        if (!n)
            return "";
        return n.description || n.nickname || n.name || "";
    }

    function isCurrent(n, current) {
        return !!n && !!current && n.id === current.id;
    }

    function pickOutput(n) {
        if (n)
            Pipewire.preferredDefaultAudioSink = n;
    }

    function pickInput(n) {
        if (n)
            Pipewire.preferredDefaultAudioSource = n;
    }

    // 0 ... 1 (the volume of a device that is not there: 0)
    function volume(n) {
        return n && n.ready && n.audio ? n.audio.volume : 0;
    }
    function muted(n) {
        return n && n.ready && n.audio ? n.audio.muted : false;
    }
    function setVolume(n, v) {
        if (!n || !n.ready || !n.audio)
            return;
        n.audio.volume = Math.max(0, Math.min(1, v));
        if (v > 0 && n.audio.muted)
            n.audio.muted = false;
    }
    function setMuted(n, on) {
        if (n && n.ready && n.audio)
            n.audio.muted = on;
    }

    // the volume and mute of the two in use can be read and set
    PwObjectTracker {
        objects: [root.output, root.input].filter(n => n !== null)
    }
}
