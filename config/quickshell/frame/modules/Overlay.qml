import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services
import qs.components
import "../components/shapes.js" as Shapes

// ═══════════════════════════════════════════════════════════════════════════
//  Overlay.qml - the frame, the island, the bottom bar and every panel that
//  grows out of it.
//
//  One full-screen layer window per screen. Only the visible shapes accept
//  pointer input (see `mask`), everything else falls through to your apps.
//
//  Draw order inside the window:
//    shadow  <  strokes (borders)  <  fills (#1A1A1A)  <  content (text, icons)
//  so every border ends up *under* every fill and only shows around the
//  outside of the merged silhouette. The soft shadow is the lowest layer, so
//  it never covers a border.
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            // a window covers this screen like fullscreen (F11 on a workspace without tiling,
            // Ui.coveredScreens): it fades out and takes no input - as Hyprland fades it for its
            // own fullscreen (the window stays, only its content fades and its input area goes:
            // see `mask` and `scene`)
            readonly property bool covered: Ui.coveredScreens.indexOf(modelData.name) >= 0
            onCoveredChanged: {
                if (covered)
                    Ui.closePopups();
            }

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "frame-overlay"
            // a text cursor / Esc handling is only needed while something is open
            // (the note and the clipboard: so a click into them can give them the keyboard)
            WlrLayershell.keyboardFocus: (note.open || clipboard.open || Ui.anyPopup) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            // Input region: the frame ring + every visible panel (none while covered)
            mask: win.covered ? noInput : frameInput
            Region {
                id: noInput
            }
            Region {
                id: frameInput
                Region {
                    item: scene
                    Region {
                        x: Theme.frame
                        y: Theme.frame
                        width: Math.max(0, scene.width - 2 * Theme.frame)
                        height: Math.max(0, scene.height - Theme.frame - scene.frameBottom)
                        radius: Theme.windowRadius
                        intersection: Intersection.Subtract
                    }
                }
                Region {
                    item: island
                }
                Region {
                    item: island.openArea       // the open island while it is still growing
                }
                Region {
                    item: dockZone              // the bottom edge, and the whole bar once it comes out (auto hide)
                }
                Region {
                    item: dockEdge              // notch mode: the bottom edge round the middle (auto hide)
                }
                Region {
                    item: sliders
                }
                Region {
                    item: power
                }
                Region {
                    item: calendar
                }
                Region {
                    item: notification
                }
                Region {
                    item: note
                }
                Region {
                    item: clipboard
                }
                Region {
                    item: picker
                }
                Region {
                    item: dockNotch             // notch mode: the notch and the blocks in the bottom corners
                }
                Region {
                    item: powerCorner
                }
                Region {
                    item: dateCorner
                }
            }

            // click outside an open popup (menu / calendar / note editor) closes it
            HyprlandFocusGrab {
                windows: [win]
                active: Ui.anyPopup
                onCleared: Ui.closePopups()
            }

            Item {
                id: scene
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: Ui.closePopups()
                // the wallpaper / theme switcher: Enter uses the one in the middle (with
                // SUPER still held too: SUPER + Enter is no shortcut)
                Keys.onReturnPressed: Ui.applySwitcher()
                Keys.onEnterPressed: Ui.applySwitcher()
                // ... the arrows without SUPER move it too: Left / Right, and with the
                // themes Up / Down as SUPER + CTRL + Up / Down
                Keys.onLeftPressed: event => event.accepted = Ui.browseSwitcher(-1)
                Keys.onRightPressed: event => event.accepted = Ui.browseSwitcher(1)
                Keys.onUpPressed: event => event.accepted = Ui.themeOpen && Ui.browseSwitcher(1)
                Keys.onDownPressed: event => event.accepted = Ui.themeOpen && Ui.browseSwitcher(-1)
                // ... and it takes the keyboard when it opens (from the note's text, say)
                Connections {
                    target: Ui
                    function onWallpaperOpenChanged() {
                        if (Ui.wallpaperOpen)
                            scene.forceActiveFocus();
                    }
                    function onThemeOpenChanged() {
                        if (Ui.themeOpen)
                            scene.forceActiveFocus();
                    }
                }

                // ── the dock (bottom bar) ─────────────────────────────
                // Auto hide (the Settings app, Store.dockAutoHide): the bottom of the
                // frame is as thin as its sides; when the pointer touches the bottom
                // edge of the screen the bar grows back up, over your windows (they
                // keep their size: the space is not reserved, see Reserve.qml). It stays
                // while the pointer is on it and while the power menu or the calendar
                // (they open from it) is open.
                //
                // Notch mode (the Settings app, Store.dockNotch): the bottom of the frame
                // is as thin as its sides, and the dock is a notch in the middle of it -
                // the island's look, at the bottom, as tall as the bar (`dockNotch` below).
                // The power button and the date are blocks in the bottom corners
                // (PowerCorner.qml, DateCorner.qml). Its space stays reserved as with the
                // bar (Reserve.qml): windows end above it, as the island's notch keeps
                // them below it. With auto hide the notch comes up out of the frame when
                // the pointer touches the bottom edge round the middle (`dockEdge`).
                HoverLatch {
                    id: dockLatch
                    input: (dockZone.hovered && dockZone.enabled) || (dockEdge.hovered && dockEdge.enabled)
                }
                readonly property bool dockOpen: !Store.dockAutoHide || dockLatch.open || (!Store.dockNotch && (Ui.powerOpen || Ui.calendarOpen))
                property real dockP: dockOpen ? 1 : 0          // 0 = hidden, 1 = the bar is there
                Behavior on dockP {
                    PanelAnim {
                        opening: scene.dockOpen
                    }
                }
                // 0 = the bar, 1 = the notch (switching: the bar's ends sink into the frame
                // while its middle stays, as the notch)
                property real notchP: Store.dockNotch ? 1 : 0
                Behavior on notchP {
                    PanelAnim {
                        opening: Store.dockNotch
                    }
                }
                // how far the dock comes up from the bottom of the screen (the bar /
                // notch, or the frame's own thickness while it is hidden)
                readonly property real dockTop: Shapes.lerp(Theme.frame, Theme.bar, dockP)
                // how far the frame comes up from the bottom of the screen (the bar,
                // or the frame's own thickness while the dock is hidden or a notch;
                // fractional while it moves, so the edge glides)
                readonly property real frameBottom: Shapes.lerp(dockTop, Theme.frame, notchP)

                // After logging in the frame, island and bar fade in together with
                // the wallpaper (Ui.revealed, set by Wallpaper.qml once the picture has
                // loaded), so there is never a dark frame around a black screen.
                // At 1 % until then: drawn once already, so the fade loses nothing.
                // After a reload of the shell: there at once.
                property real revealOpacity: 0.01
                // ... and it fades out / in with F11 on a workspace without tiling (win.covered),
                // as long and on the same curve as Hyprland fades it for its own fullscreen
                property real coverOpacity: win.covered ? 0 : 1
                Behavior on coverOpacity {
                    NumberAnimation {
                        duration: Theme.durCover
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveStandard
                    }
                }
                opacity: revealOpacity * coverOpacity
                visible: opacity > 0
                // While it fades, everything fades as one picture: otherwise the
                // borders and shadows under the panels shine through them for a moment.
                layer.enabled: opacity < 1

                NumberAnimation {
                    id: reveal
                    target: scene
                    property: "revealOpacity"
                    to: 1
                    duration: Theme.durReveal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveStandard
                }

                function show() {
                    if (!Ui.revealed)
                        return;
                    if (Ui.revealInstant) {
                        reveal.stop();
                        scene.revealOpacity = 1;
                    } else if (scene.revealOpacity < 1 && !reveal.running) {
                        reveal.start();
                    }
                }

                Connections {
                    target: Ui
                    function onRevealedChanged() {
                        scene.show();
                    }
                }
                Component.onCompleted: show()

                // the wallpaper never said so (it gives up waiting for its picture
                // 3 s after the shell has loaded): show the shell anyway
                Timer {
                    interval: 8000
                    running: !Ui.revealed
                    onTriggered: Ui.revealed = true
                }

                // ── soft shadow ───────────────────────────────────────
                // A blurred, darkened copy of every dark shape (frame, island,
                // panels). It is drawn below the borders and below the fills, so
                // only the part that falls onto the wallpaper / your windows
                // shows. The copy is rendered at half resolution: a shadow is
                // blurry anyway, and it keeps the GPU cost low.
                Item {
                    id: shadowLayer
                    anchors.fill: parent
                    z: -1
                    visible: Config.shadows && Config.shadowStrength > 0

                    ShaderEffectSource {
                        id: shadowSource
                        anchors.fill: parent
                        sourceItem: fills
                        textureSize: Qt.size(Math.max(1, width / 2), Math.max(1, height / 2))
                        live: shadowLayer.visible
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: shadowSource
                        shadowEnabled: true
                        shadowColor: "#000000"
                        shadowOpacity: Math.min(1, Config.shadowStrength)
                        shadowBlur: 1.0
                        blurMax: 64
                        shadowVerticalOffset: Theme.px(3)
                        shadowHorizontalOffset: 0
                        // see-through shapes (the shell's blur): no shadow under them, only
                        // around them (it would darken them from behind)
                        maskEnabled: Config.shellAlpha < 1
                        maskSource: shadowSource
                        maskInverted: true
                        maskThresholdMin: 0.0
                        maskSpreadAtMin: 1.0
                    }
                }

                // the frame, the island and the panels: their outlines, then their fills. With
                // the shell's blur (Config.shellAlpha < 1) the two become see-through together,
                // as one picture - so the half of an outline under a fill, and two shapes where
                // they overlap, never show through (Hyprland blurs what is behind them)
                Item {
                    id: surfaces
                    anchors.fill: parent
                    z: 0
                    opacity: Config.shellAlpha
                    layer.enabled: Config.shellAlpha < 1

                    // draw order: all outlines, then all fills, then content
                    Item {
                        id: strokes
                        anchors.fill: parent
                        z: 0

                        // border of the window area (the visible half of this stroke is the
                        // border, the other half is hidden under the frame fill)
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeWidth: Theme.border * 2
                                strokeColor: Config.outline
                                fillColor: "transparent"
                                joinStyle: ShapePath.RoundJoin
                                PathSvg {
                                    path: Shapes.innerPath(scene.width, scene.height, Theme.frame, scene.frameBottom, Theme.windowRadius)
                                }
                            }
                        }
                    }

                    Item {
                        id: fills
                        anchors.fill: parent
                        z: 1

                        // the panels' shapes meet the frame here (components/Flap.qml)
                        readonly property real frameBottom: scene.frameBottom

                        // the dark frame: everything outside the wallpaper window
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeWidth: -1
                                fillColor: Config.frame
                                fillRule: ShapePath.OddEvenFill
                                PathSvg {
                                    path: Shapes.ringPath(scene.width, scene.height, Theme.frame, scene.frameBottom, Theme.windowRadius)
                                }
                            }
                        }
                    }
                }

                Item {
                    id: content
                    anchors.fill: parent
                    z: 2

                    // ── hot zones (pixels of the frame itself) ────────────
                    HotZone {
                        id: slidersHotTop
                        x: 0
                        y: 0
                        width: Theme.px(110)
                        height: Theme.frame
                    }
                    HotZone {
                        id: slidersHotLeft
                        x: 0
                        y: 0
                        width: Theme.frame
                        height: Theme.px(70)
                    }
                    HotZone {
                        id: pickerHotTop
                        x: scene.width - Theme.px(70)
                        y: 0
                        width: Theme.px(70)
                        height: Theme.frame
                    }
                    HotZone {
                        id: pickerHotRight
                        x: scene.width - Theme.frame
                        y: 0
                        width: Theme.frame
                        height: Theme.px(70)
                    }
                    HotZone {
                        id: clipboardHot
                        x: 0
                        y: scene.height / 2 - Theme.px(140)
                        width: Theme.frame
                        height: Theme.px(280)
                    }
                    // the top edge above the island, while it hides (auto hide)
                    HotZone {
                        id: islandHot
                        enabled: Store.islandAutoHide
                        x: Math.round((scene.width - Theme.islandW) / 2)
                        y: 0
                        width: Theme.islandW
                        height: Theme.frame
                    }
                    HotZone {
                        id: noteHot
                        enabled: !Ui.calendarOpen
                        x: scene.width - Theme.frame
                        y: scene.height / 2 - Theme.px(140)
                        width: Theme.frame
                        height: Theme.px(280)
                    }

                    // ── panels ────────────────────────────────────────────
                    SliderPanel {
                        id: sliders
                        fillLayer: fills
                        strokeLayer: strokes
                        hot: slidersHotTop.hovered || slidersHotLeft.hovered
                    }

                    QuickNote {
                        id: note
                        fillLayer: fills
                        strokeLayer: strokes
                        hot: noteHot.hovered && noteHot.enabled
                    }

                    ClipboardPanel {
                        id: clipboard
                        fillLayer: fills
                        strokeLayer: strokes
                        hot: clipboardHot.hovered
                    }

                    NotificationPanel {
                        id: notification
                        fillLayer: fills
                        strokeLayer: strokes
                    }

                    // shares the top-right corner with the notification card
                    ColorPicker {
                        id: picker
                        fillLayer: fills
                        strokeLayer: strokes
                        hot: pickerHotTop.hovered || pickerHotRight.hovered
                        blocked: Notifs.busy || notification.visible
                    }

                    PowerMenu {
                        id: power
                        fillLayer: fills
                        strokeLayer: strokes
                    }

                    CalendarPanel {
                        id: calendar
                        fillLayer: fills
                        strokeLayer: strokes
                    }

                    Island {
                        id: island
                        fillLayer: fills
                        strokeLayer: strokes
                        hot: islandHot.hovered && islandHot.enabled
                    }

                    // ── notch mode: the dock's notch and the corner blocks ──
                    // The notch: a panel on the bottom edge, as tall as the dock (`dockTop`)
                    // and as wide as the apps need (BottomBar.qml's notchWidth). While the
                    // mode changes it starts as wide as the screen - the bar - and narrows.
                    // With auto hide it grows out of the middle of the edge like a panel
                    // (the quick note, the clipboard): as wide and as tall as `dockP`.
                    Item {
                        id: dockNotch
                        readonly property real fw: Shapes.lerp(scene.width + 2 * Theme.earRadius, bar.notchWidth * scene.dockP, scene.notchP)
                        readonly property real fh: scene.dockTop
                        x: Math.round((scene.width - fw) / 2)
                        y: Math.round(scene.height - fh)
                        width: scene.notchP > 0 ? Math.round(fw) : 0
                        height: scene.notchP > 0 ? Math.round(fh) : 0

                        Flap {
                            target: dockNotch
                            fx: (scene.width - dockNotch.fw) / 2
                            fy: scene.height - dockNotch.fh
                            fw: dockNotch.fw
                            fh: dockNotch.fh
                            fillLayer: fills
                            strokeLayer: strokes
                            attachBottom: true
                        }
                    }

                    // the bottom-left / bottom-right corner of the frame (notch mode)
                    HotZone {
                        id: powerHotBottom
                        enabled: Store.dockNotch
                        x: 0
                        y: scene.height - Theme.frame
                        width: Theme.px(70)
                        height: Theme.frame
                    }
                    HotZone {
                        id: powerHotLeft
                        enabled: Store.dockNotch
                        x: 0
                        y: scene.height - Theme.px(70)
                        width: Theme.frame
                        height: Theme.px(70)
                    }
                    HotZone {
                        id: dateHotBottom
                        enabled: Store.dockNotch
                        x: scene.width - Theme.px(70)
                        y: scene.height - Theme.frame
                        width: Theme.px(70)
                        height: Theme.frame
                    }
                    HotZone {
                        id: dateHotRight
                        enabled: Store.dockNotch
                        x: scene.width - Theme.frame
                        y: scene.height - Theme.px(70)
                        width: Theme.frame
                        height: Theme.px(70)
                    }

                    // above the power menu and the calendar: the button sits in their corner
                    PowerCorner {
                        id: powerCorner
                        fillLayer: fills
                        strokeLayer: strokes
                        hot: (powerHotBottom.hovered || powerHotLeft.hovered) && Store.dockNotch
                    }

                    DateCorner {
                        id: dateCorner
                        fillLayer: fills
                        strokeLayer: strokes
                        hot: (dateHotBottom.hovered || dateHotRight.hovered) && Store.dockNotch
                    }

                    BottomBar {
                        id: bar
                        frameBottom: scene.dockTop
                        reveal: scene.dockP
                        notch: scene.notchP
                        shownWidth: dockNotch.fw
                    }

                    // the bottom edge while the dock hides; once it is out, the whole
                    // bar (so it stays while the pointer is anywhere on it). Above the
                    // bar: it only watches the pointer, clicks go through to the bar.
                    // Notch mode: only under the notch (the corners are the blocks').
                    HotZone {
                        id: dockZone
                        enabled: Store.dockAutoHide
                        x: Store.dockNotch ? Math.round((scene.width - bar.notchWidth) / 2) : 0
                        width: Store.dockNotch ? Math.round(bar.notchWidth) : scene.width
                        height: dockLatch.open ? Theme.bar : Theme.frame
                        y: scene.height - height
                    }

                    // Notch mode: the notch also comes out from the bottom edge round the
                    // middle, at least 1500 px wide (wider with a wider notch; never into
                    // the corners - those are the blocks'), so you need not aim for it.
                    // Once it is out the strip is as tall as the dock, so it stays while
                    // the pointer is a little above the edge beside it. (While it is out
                    // that strip takes the clicks - the bottom of a window beside the
                    // notch is clicked once the dock has gone again.)
                    HotZone {
                        id: dockEdge
                        enabled: Store.dockAutoHide && Store.dockNotch
                        width: Math.round(Math.min(Math.max(Theme.px(1500), bar.notchWidth), scene.width - 2 * Theme.px(70)))
                        x: Math.round((scene.width - width) / 2)
                        height: dockLatch.open ? Theme.bar : Theme.frame
                        y: scene.height - height
                    }
                }
            }
        }
    }
}
