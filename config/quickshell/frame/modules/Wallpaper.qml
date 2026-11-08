import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// ═══════════════════════════════════════════════════════════════════════════
//  Wallpaper.qml - Wallpaper, drawn by the shell itself (no hyprpaper needed).
//  The pictures are in ~/.local/share/frameshell/wallpapers; SUPER + CTRL + Left /
//  Right switches between them (services/Wallpapers.qml, the switcher in the
//  island). A new one fades in over the old one once it has loaded.
//
//  After logging in the whole desktop fades in from black (Hyprland's
//  background is black too, misc.background_color in hyprland.lua) once the
//  picture has loaded: the wallpaper here, the frame, island and bar with it
//  (Ui.revealed, Overlay.qml). Only when the shell starts: a reload (saving
//  Config.qml) does not fade again.
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    id: root

    property bool revealed: false     // fade in now
    property bool instant: false      // a reload: no fade

    PersistentProperties {
        reloadableId: "wallpaperReveal"

        property bool done: false     // survives reloads of the shell

        onLoaded: {
            root.instant = done;
            done = true;
            root.revealed = true;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "frame-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "black"

            // the picture is there (or will not come). Counted from when the whole
            // shell has loaded (root.revealed): while it loads, nothing else runs
            // either, and a timer counted from the start would win against a picture
            // that is ready at the same moment. Never wait more than 3 s after that.
            readonly property bool pictureDone: Wallpapers.ready && (front.status === Image.Ready || front.status === Image.Error || front.source.toString() === "")
            property bool waited: false
            readonly property bool ready: pictureDone || waited
            Timer {
                interval: 3000
                running: root.revealed && !win.pictureDone && !win.waited
                onTriggered: win.waited = true
            }

            // ... and drawn once, nearly invisible (content starts at 1 %): the slow
            // first frame (the picture going to the graphics card) is over before
            // the fade starts, so none of the fade is lost
            property bool drew: false
            Timer {
                interval: 400
                running: win.ready && !win.drew
                onTriggered: win.drew = true
            }

            // ── which picture (services/Wallpapers.qml) ──────────────────────
            readonly property string want: Wallpapers.ready ? "file://" + Wallpapers.current : ""
            property Image front: layerA
            readonly property Image back: front === layerA ? layerB : layerA
            readonly property bool firstFade: root.instant || win.revealing
            property bool started: false
            property bool switched: false           // a second picture came: from now on only crossfades

            onWantChanged: pick()
            function pick() {
                if (want.length === 0)
                    return;
                if (!started) {                       // the first picture: no crossfade
                    started = true;
                    front.source = want;
                    return;
                }
                switched = true;
                if (crossfade.running) {
                    // picked again mid-fade: the picture that is more than half in
                    // stays, the other layer takes the new one
                    crossfade.stop();
                    if (back.opacity > 0.5)
                        swapped();
                    else
                        back.opacity = 0;
                }
                if (front.source.toString() === want) {
                    back.source = "";
                    return;
                }
                if (back.source.toString() === want) {
                    // loaded while you browsed the switcher (below): fade in right away
                    if (back.status === Image.Ready)
                        startFade();
                    return;                         // still loading: loaded() starts it
                }
                back.opacity = 0;
                back.source = want;                 // loads, then loaded() fades it in
            }
            function startFade() {
                back.opacity = 0;
                back.z = 1;
                front.z = 0;
                crossfade.target = back;
                crossfade.from = 0;
                crossfade.start();
            }

            // While you browse the switcher, the picture it is on is loaded in the
            // (hidden) back layer already, so when it is applied it fades in at once -
            // no waiting for a 4K picture. Closed without picking: it is let go again.
            readonly property string preview: Ui.wallpaperOpen && Wallpapers.selected.length > 0 ? "file://" + Wallpapers.selected : ""
            onPreviewChanged: preload()
            function preload() {
                if (!started || crossfade.running)
                    return;
                // a picture that was applied and is still loading goes first
                if (back.source.toString() === want && want !== front.source.toString())
                    return;
                if (preview.length === 0 || preview === front.source.toString()) {
                    if (back.source.toString() !== want)
                        back.source = "";
                    return;
                }
                back.opacity = 0;
                back.source = preview;
            }
            function loaded(layer) {
                if (layer !== back || layer.source.toString() !== want)
                    return;
                if (layer.status === Image.Ready) {
                    startFade();
                } else if (layer.status === Image.Error) {
                    layer.source = "";              // broken picture: keep the one on screen
                }
            }
            function swapped() {
                const old = front;
                back.opacity = 1;
                front = back;
                old.opacity = 0;
                old.source = "";                      // let the old picture go (memory)
                preload();                            // the switcher may be open again
            }

            readonly property bool go: root.revealed && (root.instant || (ready && drew))
            property bool revealing: false   // the fade has started: a picture that comes later fades in by itself
            onGoChanged: show()
            Component.onCompleted: show()
            function show() {
                if (!go)
                    return;
                revealing = true;
                // the frame, the island and the bar fade in with it (Overlay.qml)
                Ui.revealInstant = root.instant;
                Ui.revealed = true;
                if (root.instant) {
                    reveal.stop();
                    content.opacity = 1;
                } else if (content.opacity < 1 && !reveal.running) {
                    reveal.start();
                }
            }

            NumberAnimation {
                id: reveal
                target: content
                property: "opacity"
                to: 1
                duration: Theme.durReveal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveStandard
            }

            Item {
                id: content
                anchors.fill: parent
                opacity: 0.01

                Connections {
                    target: content.Window.window
                    enabled: !win.drew
                    function onFrameSwapped() {
                        if (win.ready)
                            win.drew = true;
                    }
                }

                // only when there is no picture at all (missing, broken). Not under a
                // picture that is loading: in a fade it would shine through it as grey.
                Rectangle {
                    anchors.fill: parent
                    visible: Wallpapers.ready && (win.front.status === Image.Error || win.front.source.toString() === "")
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: "#2a1d46"
                        }
                        GradientStop {
                            position: 0.55
                            color: "#1b1631"
                        }
                        GradientStop {
                            position: 1.0
                            color: "#0f0b19"
                        }
                    }
                }

                // Two layers: the picture on screen (`front`) and, while you switch,
                // the new one loading on top of it (`back`). The new one fades in once
                // it has loaded, then it becomes the front and the old one is let go.
                Image {
                    id: layerA
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    cache: false
                    // the first picture fades in once it has loaded instead of popping
                    // in: after a reload, or when it came late after logging in.
                    // Normally after logging in it is there before the fade, and the
                    // whole desktop fades in with it.
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity {
                        enabled: win.firstFade && !win.switched
                        NumberAnimation {
                            duration: Theme.durOpen
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveStandard
                        }
                    }
                    onStatusChanged: win.loaded(layerA)
                }

                Image {
                    id: layerB
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    cache: false
                    opacity: 0
                    onStatusChanged: win.loaded(layerB)
                }

                // slow at both ends, even in the middle: no jump at the start even when
                // the two pictures have very different colours
                NumberAnimation {
                    id: crossfade
                    property: "opacity"
                    to: 1
                    duration: Theme.durWallpaperFade
                    easing.type: Easing.InOutSine
                    onFinished: win.swapped()
                }
            }
        }
    }
}
