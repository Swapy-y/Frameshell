import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.components
import "../components/shapes.js" as Shapes

// ═══════════════════════════════════════════════════════════════════════════
//  Island.qml - the notch at the top centre.
//
//  Collapsed: workspaces · clock · signal + battery
//  Hovered:   grows downward and also shows the date, the round Bluetooth and
//             Wi-Fi buttons, what is playing (picture, title, artist) with the
//             progress bar and the media buttons, and the notifications pill.
//
//  A click on Wi-Fi or Bluetooth opens its card in the middle of the screen
//  (modules/NetPopup.qml).
//
//  Auto hide (the Settings app, Store.islandAutoHide): nothing of the island
//  sticks out of the frame (the notch shrinks into the middle of the top edge);
//  when the pointer touches the top edge of the screen above it (`hot`, a strip
//  of the frame, see Overlay.qml) it grows out of the middle straight into the
//  open island, over your windows.
//
//  SUPER + CTRL + Left / Right: the island grows into the wallpaper switcher - your
//  wallpapers in a loop, the one it is on in the middle (white outline), one
//  on each side - and slides to the previous / next one (services/
//  Wallpapers.qml; while it is open the arrows alone do too). Enter makes the
//  one in the middle the wallpaper and closes the switcher; Esc, or a click
//  outside it, closes it and the wallpaper stays (the keyboard and the click:
//  modules/Overlay.qml). A click on a picture beside the middle slides to it,
//  a click on the one in the middle is Enter. Above the pictures: where you
//  are ("3 / 7") and the keys that browse (switchText at the end).
//
//  SUPER + CTRL + Up / Down: the same switcher with the colour themes (services/
//  Themes.qml, Config.themes): each one a card in its own colours - a row of
//  them and its name. Up goes to the next one (right), Down to the previous.
//  Enter, Esc and the clicks as with the wallpapers.
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    required property Item fillLayer
    required property Item strokeLayer

    // the pointer is on the top edge of the screen above the island (auto hide)
    property bool hot: false

    // ── open / close ──────────────────────────────────────────────────────
    // auto hide: 0 = the notch is there, 1 = nothing is there until you hover
    property real hidden: Store.islandAutoHide ? 1 : 0
    Behavior on hidden {
        PanelAnim {
            opening: !Store.islandAutoHide
        }
    }
    // the wallpaper / theme switcher takes the island's place while it is open
    readonly property bool switching: Ui.wallpaperOpen || Ui.themeOpen
    // what the switcher shows: "wallpaper" or "theme" (kept while it closes)
    property string switchMode: "wallpaper"
    property real sw: switching ? 1 : 0        // 0 = notch, 1 = wallpaper / theme switcher
    Behavior on sw {
        PanelAnim {
            opening: root.switching
        }
    }

    readonly property bool expanded: latch.open && !switching
    property real p: expanded ? 1 : 0          // 0 = notch, 1 = full island
    Behavior on p {
        PanelAnim {
            opening: root.expanded
        }
    }

    // ── size ──────────────────────────────────────────────────────────────
    // the open island's height: the space under the media buttons is the same as
    // above the picture (under the clock)
    readonly property real lowerTop: Theme.px(56)
    readonly property real lowerH: Theme.px(86)
    readonly property real wantedH: lowerTop + lowerH + Theme.px(8)

    // the round buttons on both sides: their size, top (centred on the media
    // column) and how far the two groups' middles are from the island's middle
    readonly property real buttonSize: Theme.px(42)
    readonly property real buttonTop: Theme.px(66)
    readonly property real sideOffset: Theme.px(227)

    property real fullH: wantedH
    Behavior on fullH {
        Anim {
            curve: Theme.curveDecel
            duration: Theme.durOpen
        }
    }

    // The exact size (fractional while animating, so the edges glide). Both
    // widths keep the odd/even-ness of the screen so the island sits on whole
    // pixels when it is at rest.
    readonly property real notchWidth: Shapes.sameParity(Theme.notchW, parent.width)
    readonly property real islandWidth: Shapes.sameParity(Theme.islandW, parent.width)
    readonly property real switchWidth: Shapes.sameParity(Theme.wallSwitchW, parent.width)
    // auto hide: the notch shrinks into the middle of the top edge (and grows out
    // of it again), like a panel - the quick note, the clipboard
    readonly property real notchShown: notchWidth * (1 - hidden)
    readonly property real fw: Shapes.lerp(Shapes.lerp(notchShown, islandWidth, p), switchWidth, sw)
    readonly property real notchHeight: Theme.notchH * (1 - hidden)
    readonly property real fh: Shapes.lerp(Shapes.lerp(notchHeight, fullH, p), Theme.wallSwitchH, sw)

    width: Math.round(fw)
    height: Math.round(fh)
    x: Math.round((parent.width - fw) / 2)
    y: 0

    HoverLatch {
        id: latch
        input: hover.hovered || root.hot || openHover.hovered
    }

    HoverHandler {
        id: hover
    }

    // While it is open, the whole open island counts as "on it", even while it is
    // still growing: the pointer can be quicker than the island (auto hide: from
    // the edge of the screen straight down to its buttons). Overlay.qml adds it to
    // the window's input area.
    readonly property Item openArea: openAreaItem
    Item {
        id: openAreaItem
        readonly property bool on: latch.open && !root.switching
        x: Math.round((root.parent.width - root.islandWidth) / 2) - root.x
        y: 0
        width: on ? root.islandWidth : 0
        height: on ? Math.round(root.fullH) : 0

        HoverHandler {
            id: openHover
        }
    }

    Flap {
        target: root
        fx: (root.parent.width - root.fw) / 2
        fy: 0
        fw: root.fw
        fh: root.fh
        fillLayer: root.fillLayer
        strokeLayer: root.strokeLayer
        attachTop: true
    }

    // The content lives in a fixed-width body that is revealed by the growing
    // island, so nothing reflows during the animation. The body stays on the
    // same whole pixel of the screen while the island's (rounded) size changes,
    // and everything that slides in it moves in whole pixels, so the icons and
    // the text don't jitter while the island opens or closes. It is cut off at
    // the island's edge: while the island grows, nothing of it shows outside yet
    // (auto hide: the island grows from nothing, over your windows).
    Item {
        width: root.width
        height: root.height
        clip: true

        Item {
            id: body
            width: Theme.islandW
            height: root.fullH
            x: Math.round((root.parent.width - width) / 2) - root.x
            y: 0
            // gone while the wallpaper switcher is open
            opacity: 1 - Shapes.clamp(root.sw / 0.4, 0, 1)
            visible: opacity > 0.01

            readonly property real cx: width / 2
            // the workspaces and signal + battery: beside the notch closed, open centred over the
            // Bluetooth + Wi-Fi buttons and the notifications pill
            readonly property real slotOffset: Shapes.lerp(Theme.px(97), root.sideOffset, root.p)
            readonly property real rowCenter: Theme.notchH / 2
            readonly property real lower: Shapes.clamp((root.p - 0.35) / 0.65, 0, 1)   // fades in the lower area
            // the top row (workspaces, clock, signal + battery): hidden with the island
            // (auto hide), fading in while it grows open
            readonly property real topRow: 1 - root.hidden * (1 - Shapes.clamp((root.p - 0.1) / 0.4, 0, 1))

            // ── workspaces (left slot) ────────────────────────────────────────
            Item {
                id: wsSlot
                width: Theme.px(110)
                height: Theme.notchH
                x: Math.round(body.cx - body.slotOffset - width / 2)
                y: 0
                opacity: body.topRow
                visible: opacity > 0.01

                // The pills are placed by hand, not with anchors.centerIn: that
                // rounds to whole pixels, and while a pill grows or shrinks the
                // rounding flips back and forth (the pill jitters) and snaps once
                // more when it ends (a pixel to the side, a moment later).
                //
                // Instead they move exactly, and where exact centring would leave
                // a pill between two screen pixels once it stops, a tiny offset
                // (under a pixel) puts it on the pixel. The offset moves along with
                // the pills, so nothing jumps afterwards. On a 2x screen (4K at
                // scale 2) there is nothing to offset: the pills sit exactly centred.
                readonly property real dpr: QsWindow.window && QsWindow.window.devicePixelRatio > 0 ? QsWindow.window.devicePixelRatio : 1
                // the nearest screen pixel; exactly halfway goes right / down, or up
                // with `up` (both the way the pills sat before)
                function onPixels(v, up) {
                    const d = v * dpr;
                    return (up ? Math.ceil(d - 0.5) : Math.round(d)) / dpr;
                }
                readonly property int gap: Theme.px(7)       // air between two pills
                readonly property int wOn: Theme.px(6)       // the workspace you are on: a bigger white pill
                readonly property int hOn: Theme.px(16)
                readonly property int wOff: Theme.px(4)      // the others: small grey ones
                readonly property int hOff: Theme.px(12)
                readonly property int rowH: Theme.px(20)

                // where the first pill's left edge ends up once nothing moves
                // (the row exactly centred), and the offset onto a screen pixel
                // The pills shown: Spaces.ids, and the workspace you are on at
                // once - Spaces.ids follows a moment later (it waits until Hyprland
                // has settled), and the pill of a workspace you go to that had none
                // (the 5th) should not wait for it.
                readonly property var shownIds: {
                    const ids = Spaces.ids;
                    const here = Spaces.focusedId;
                    return ids.indexOf(here) >= 0 || Spaces.slots.indexOf(here) < 0 ? ids : ids.concat([here]);
                }

                readonly property real restW: {
                    let w = shownIds.length * (wOff + gap);
                    if (shownIds.indexOf(Spaces.focusedId) >= 0)
                        w += wOn - wOff;
                    return w;
                }
                readonly property real restLeft: (width - restW + gap) / 2
                property real nudge: onPixels(restLeft) - restLeft
                Behavior on nudge {
                    Anim {}     // with the pills (`shown` below)
                }
                readonly property real nudgeOff: onPixels((rowH - hOff) / 2, true) - (rowH - hOff) / 2
                readonly property real nudgeOn: onPixels((rowH - hOn) / 2, true) - (rowH - hOn) / 2

                // One slot per possible workspace. A slot that is not shown has no
                // width, so the pills that are shown stay centred, and a pill that
                // appears or disappears grows or shrinks smoothly.
                Row {
                    x: (wsSlot.width - width) / 2 + wsSlot.nudge
                    y: wsSlot.onPixels((wsSlot.height - wsSlot.rowH) / 2, true)
                    spacing: 0

                    Repeater {
                        model: Spaces.slots

                        Item {
                            id: dot
                            required property var modelData
                            readonly property bool active: modelData === Spaces.focusedId
                            readonly property bool present: wsSlot.shownIds.indexOf(modelData) >= 0
                            // the small pill's colour: a bit lighter when tiling is off there
                            readonly property color offColor: Spaces.untiled.indexOf(modelData) >= 0 ? Config.pillUntiled : Config.iconDim

                            // 0 = no pill, 1 = pill; the change is animated. Just as
                            // quick as the white pill moving on (`on` below), so going to
                            // the 5th workspace - its pill appears and becomes the white
                            // one - is one quick movement, like going to any other.
                            property real shown: present ? 1 : 0
                            Behavior on shown {
                                Anim {
                                    curve: Theme.curveStandard
                                }
                            }

                            // 0 = small grey pill, 1 = big white pill (the workspace you
                            // are on). Size and colour follow this one value, so they
                            // change together - smooth, no overshoot, no bounce.
                            property real on: active ? 1 : 0
                            Behavior on on {
                                Anim {
                                    curve: Theme.curveStandard
                                }
                            }

                            // width of the pill, and of its place: the pill + the air
                            // beside it. A pill that appears or disappears grows from /
                            // shrinks to a thin line in the middle of its place (no
                            // clipping: a clipped edge moves in whole pixels and would
                            // wobble the new pill while it appears).
                            readonly property real pillW: Shapes.lerp(wsSlot.wOff, wsSlot.wOn, on)
                            width: (pillW + wsSlot.gap) * shown
                            height: wsSlot.rowH
                            opacity: shown
                            visible: shown > 0

                            Rectangle {
                                id: pill
                                width: dot.pillW * dot.shown
                                height: Shapes.lerp(wsSlot.hOff, wsSlot.hOn, dot.on)
                                // centred by hand (see above)
                                x: (dot.width - width) / 2
                                y: (dot.height - height) / 2 + Shapes.lerp(wsSlot.nudgeOff, wsSlot.nudgeOn, dot.on)
                                radius: width / 2
                                color: Qt.rgba(Shapes.lerp(dot.offColor.r, Config.text.r, dot.on), Shapes.lerp(dot.offColor.g, Config.text.g, dot.on), Shapes.lerp(dot.offColor.b, Config.text.b, dot.on), Shapes.lerp(dot.offColor.a, Config.text.a, dot.on))
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: dot.present
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Spaces.go(dot.modelData)
                            }
                        }
                    }
                }
            }

            // ── clock (centre) ────────────────────────────────────────────────
            // The clock text is centred on its own, so "1:23" and "12:33" both sit
            // exactly in the middle. When the island opens, the date slides in on
            // its right and the pair stays centred.
            Row {
                id: clockRow
                x: Math.round((body.width - width) / 2)
                y: Math.round(body.rowCenter - height / 2)
                spacing: 0
                opacity: body.topRow
                visible: opacity > 0.01

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Clock.time
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.fsClock
                    font.weight: Font.DemiBold
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Clock.dateWords
                    font.pixelSize: Theme.fsSmall
                    color: Config.textDim
                    leftPadding: Theme.px(8)
                    width: implicitWidth * body.lower
                    opacity: body.lower
                    clip: true
                }
            }

            // ── signal + battery (right slot) ─────────────────────────────────
            Item {
                id: rightSlot
                width: Theme.px(110)
                height: Theme.notchH
                opacity: body.topRow
                visible: opacity > 0.01
                // (open, 1 px further right: the row's 1 px nudge below is for the notch;
                // open, the row lines up with the notifications pill under it)
                x: Math.round(body.cx + body.slotOffset + Theme.px(1) * root.p - width / 2)
                y: 0

                Row {
                    // 1 px left of the middle (looks centred), on whole pixels
                    x: Math.round((parent.width - width) / 2) - Theme.px(1)
                    y: Math.round((parent.height - height) / 2)
                    spacing: Theme.px(7)

                    SignalIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.px(14)
                        level: NetSpeed.level
                    }

                    BatteryIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.px(24)
                        level: Battery.level
                        charging: Battery.charging
                    }
                }
            }

            // ── Bluetooth and Wi-Fi (left, visible when expanded) ─────────────
            // Round buttons: white with a dark icon = on, a grey ring = off (or not
            // available). A click opens the list of devices / networks in a card in
            // the middle of the screen (modules/NetPopup.qml).
            Item {
                id: netCol
                x: 0
                y: root.buttonTop
                width: body.cx
                height: root.buttonSize
                opacity: body.lower
                visible: opacity > 0.01

                readonly property var wifi: Net.wifi
                readonly property var bt: Net.bt
                readonly property bool wifiOn: wifi !== null && (wifi.device !== null ? wifi.enabled : wifi.wiredConnected)
                readonly property bool btOn: bt !== null && bt.enabled

                // the pair is centred where the notification button is mirrored
                Repeater {
                    model: [
                        {
                            page: "bluetooth",
                            icon: "bluetooth",
                            size: Theme.px(22),         // 13.75 x 22
                            offset: -Theme.px(28)
                        },
                        {
                            page: "wifi",
                            icon: "wifi",
                            size: Theme.px(28),         // 28 x 22
                            offset: Theme.px(28)
                        }
                    ]

                    RingButton {
                        required property var modelData
                        x: Math.round(body.cx - root.sideOffset + modelData.offset - width / 2)
                        on: modelData.page === "wifi" ? netCol.wifiOn : netCol.btOn
                        active: Ui.netPage === modelData.page
                        icon: modelData.icon
                        iconSize: modelData.size
                        // off: a soft grey circle with a white icon (no ring)
                        outline: false
                        offColor: Config.selected
                        hoverColor: offColor             // no change under the pointer
                        iconColor: Config.text
                        onClicked: Ui.toggleNet(modelData.page)
                    }
                }
            }

            // ── media (centre column) ─────────────────────────────────────────
            // What is playing (the cover or the video's picture, the title and the
            // artist / channel), the progress bar under it and the buttons under that.
            Item {
                id: mediaCol
                width: barWidth
                height: Theme.px(75)
                x: Math.round(body.cx - width / 2)
                y: Theme.px(50)
                opacity: body.lower
                visible: opacity > 0.01

                readonly property real barWidth: Theme.px(192)

                // ── now playing: picture + title + artist, centred over the bar ──
                Item {
                    id: nowPlaying

                    readonly property real coverSize: Theme.px(32)
                    readonly property real gap: Theme.px(9)
                    // the text is as wide as it needs, the whole row never wider than the bar
                    readonly property real textWidth: Math.min(mediaCol.barWidth - coverSize - gap, Math.ceil(Math.max(titleText.implicitWidth, artistText.implicitWidth)))

                    // nothing loaded: "Nothing playing"; no title: the app's name
                    readonly property string title: !Media.has ? "Nothing playing" : (Media.title !== "" ? Media.title : Media.playerName)
                    readonly property string artist: !Media.has || Media.title === "" ? "" : (Media.artist !== "" ? Media.artist : Media.playerName)

                    width: coverSize + gap + textWidth
                    height: coverSize
                    x: Math.round((mediaCol.width - width) / 2)
                    y: 0

                    // the picture, with rounded corners. Two images take turns, so a new
                    // picture fades in over the old one instead of blinking
                    ClippingRectangle {
                        id: cover
                        width: nowPlaying.coverSize
                        height: nowPlaying.coverSize
                        radius: Theme.px(7)
                        color: Config.selected          // no picture (yet)

                        property int current: -1        // which image is shown, -1 = none
                        property int under: -1          // the one before, kept under the new one while it fades in
                        readonly property string url: Media.artUrl

                        property int last: -1
                        onCurrentChanged: {
                            under = current < 0 ? -1 : last;
                            last = current;
                            if (under >= 0)
                                dropUnder.restart();
                        }
                        Timer {
                            id: dropUnder
                            interval: Theme.durSmall + 40
                            onTriggered: cover.under = -1
                        }

                        function load() {
                            if (url === "") {
                                current = -1;
                                return;
                            }
                            const next = current === 0 ? 1 : 0;
                            const img = images.itemAt(next);
                            if (!img)
                                return;                 // not made yet: load() runs again when it is
                            if (img.source.toString() === url && img.status === Image.Ready) {
                                current = next;
                                return;
                            }
                            img.source = url;           // shown once it has loaded (onStatusChanged)
                        }
                        onUrlChanged: load()
                        Component.onCompleted: load()

                        Icon {
                            anchors.centerIn: parent
                            size: Theme.px(16)
                            name: "bt-headphones"
                            color: Config.iconDim
                            opacity: cover.current < 0 ? 1 : 0
                            Behavior on opacity {
                                Anim {
                                    duration: Theme.durSmall
                                }
                            }
                        }

                        Repeater {
                            id: images
                            model: 2
                            onItemAdded: cover.load()

                            Image {
                                required property int index
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop  // square: the middle of a wide video picture
                                sourceSize.width: Math.ceil(nowPlaying.coverSize * 2)
                                sourceSize.height: Math.ceil(nowPlaying.coverSize * 2)
                                asynchronous: true
                                cache: true
                                smooth: true
                                mipmap: true
                                opacity: cover.current === index || cover.under === index ? 1 : 0
                                z: cover.current === index ? 1 : 0
                                Behavior on opacity {
                                    Anim {
                                        duration: Theme.durSmall
                                    }
                                }
                                onStatusChanged: {
                                    if (status === Image.Ready && source.toString() === cover.url)
                                        cover.current = index;
                                    else if (status === Image.Error && source.toString() === cover.url)
                                        cover.current = -1;
                                }
                            }
                        }
                    }

                    Column {
                        x: nowPlaying.coverSize + nowPlaying.gap
                        // centred on the picture (its ink a pixel low looks centred), on whole pixels
                        y: Math.round((nowPlaying.coverSize - height) / 2 + Theme.px(1))
                        width: nowPlaying.textWidth
                        spacing: Theme.px(2)

                        Txt {
                            id: titleText
                            width: parent.width
                            text: nowPlaying.title
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.DemiBold
                            color: Media.has ? Config.text : Config.textDim
                            elide: Text.ElideRight
                        }

                        Txt {
                            id: artistText
                            width: parent.width
                            visible: text !== ""
                            text: nowPlaying.artist
                            font.pixelSize: Theme.px(11)
                            color: Config.textDim
                            elide: Text.ElideRight
                        }
                    }
                }

                FSlider {
                    x: 0
                    y: Theme.px(39)
                    width: mediaCol.barWidth
                    knobSize: Theme.px(9)
                    trackHeight: Theme.px(3)
                    interactive: Media.player !== null && Media.player.canSeek
                    value: Media.progress
                    onMoved: v => Media.seekTo(v)
                }

                Row {
                    id: controls
                    x: Math.floor((mediaCol.width - width) / 2)      // whole pixels
                    y: Theme.px(56)
                    spacing: Theme.px(30)

                    Repeater {
                        model: ["prev", "toggle", "next"]

                        Item {
                            id: btn
                            required property string modelData
                            width: Theme.px(23)
                            height: Theme.px(23)

                            readonly property bool available: Media.has

                            Icon {
                                anchors.centerIn: parent
                                size: Theme.px(15)
                                name: btn.modelData === "toggle" ? (Media.playing ? "pause" : "play") : btn.modelData
                                color: btn.available ? Config.text : Config.iconDim
                                opacity: btnArea.pressed ? 0.6 : 1
                                scale: btnArea.pressed ? 0.85 : 1

                                Behavior on opacity {
                                    Anim {
                                        duration: Theme.durFast
                                    }
                                }
                                Behavior on scale {
                                    Anim {
                                        duration: Theme.durFast
                                        curve: Theme.curveSpring
                                    }
                                }
                            }

                            MouseArea {
                                id: btnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: btn.available
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (btn.modelData === "prev")
                                        Media.previous();
                                    else if (btn.modelData === "next")
                                        Media.next();
                                    else
                                        Media.togglePlaying();
                                }
                            }
                        }
                    }
                }

                // while the bar is on screen, Media keeps asking the player where it is
                Binding {
                    target: Media
                    property: "shown"
                    value: mediaCol.visible
                }
            }

            // ── notifications (right) ─────────────────────────────────────────
            // A pill: the round bell button and what it does. White circle = notifications
            // on, grey circle = "Do not disturb". Only the round button switches it.
            Item {
                id: bellCol
                readonly property bool on: Store.notificationsOn

                width: root.buttonSize + Theme.px(8) + labelMetrics.width + Theme.px(14)
                height: root.buttonSize
                x: Math.round(body.cx + root.sideOffset - width / 2)
                y: root.buttonTop
                opacity: body.lower
                visible: opacity > 0.01

                // the wider of the two texts: the pill keeps its size when it switches
                TextMetrics {
                    id: labelMetrics
                    font: bellLabel.font
                    text: "Notifications off"
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "transparent"
                    border.width: Theme.px(1.5)
                    border.color: Config.selected
                    antialiasing: true
                }

                RingButton {
                    x: 0
                    on: bellCol.on
                    icon: "bell-fill"
                    iconSize: Theme.px(22)
                    outline: false
                    offColor: Config.selected
                    hoverColor: offColor             // no change under the pointer
                    iconColor: Config.text
                    onClicked: Store.notificationsOn = !Store.notificationsOn
                }

                Txt {
                    id: bellLabel
                    x: root.buttonSize + Theme.px(8)
                    y: Math.round((parent.height - height) / 2)
                    text: bellCol.on ? "Notifications on" : "Notifications off"
                    font.pixelSize: Theme.px(13)
                    font.weight: Font.Medium
                    color: Config.textDim
                }
            }
        }
    }

    // ── wallpaper / theme switcher (SUPER + CTRL + Left / Right, Up / Down) ──────
    // Nothing is used until Enter (Ui.applySwitcher()) or a click on the one in
    // the middle.
    Connections {
        target: Ui
        function onWallpaperShown() {
            root.thumbsWanted = true;
        }
        function onWallpaperOpenChanged() {
            if (Ui.wallpaperOpen)
                root.switchMode = "wallpaper";
        }
        function onThemeOpenChanged() {
            if (Ui.themeOpen)
                root.switchMode = "theme";
        }
    }

    // A key and what it does, for the switcher's top row: the keys as small rounded
    // caps (an arrow: "<" / ">" / "v" / "^"; or a word: "Enter"), then what they do.
    component KeyHint: Row {
        id: hint
        property var keys: []
        property string label: ""
        spacing: Theme.px(5)

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(2)

            Repeater {
                model: hint.keys

                Rectangle {
                    id: cap
                    required property string modelData
                    readonly property bool arrow: ["<", ">", "v", "^"].indexOf(modelData) >= 0
                    height: Theme.px(16)
                    width: arrow ? height : Math.max(height, capText.implicitWidth + Theme.px(8))
                    radius: Theme.px(4)
                    color: Config.selected

                    Txt {
                        id: capText
                        visible: !cap.arrow
                        anchors.centerIn: parent
                        text: cap.modelData
                        font.pixelSize: Theme.px(10)
                        font.weight: Font.Medium
                        color: Config.text
                    }
                    Icon {
                        visible: cap.arrow
                        x: Math.round((parent.width - width) / 2)
                        y: Math.round((parent.height - height) / 2)
                        size: Theme.px(8)
                        name: cap.modelData === "<" ? "chev-left" : "chev-right"
                        rotation: cap.modelData === "v" ? 90 : cap.modelData === "^" ? -90 : 0   // down / up: the right one turned
                        color: Config.text
                    }
                }
            }
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: hint.label
            font.pixelSize: Theme.px(11)
            font.weight: Font.Medium
            color: Config.textDim
        }
    }

    // the small pictures load a while after logging in (not during it), so
    // they are there when the switcher opens
    property bool thumbsWanted: false
    Timer {
        interval: 3000
        running: Ui.revealed && !root.thumbsWanted
        onTriggered: root.thumbsWanted = true
    }

    // One picture / theme of the strip, placed by its place in the loop: the
    // big one in the middle, the others beside it. What it shows goes inside it,
    // drawn at the big size and scaled down by `shown` (on the graphics card) beside
    // the middle, so nothing is resized or redrawn while it slides; the outline is
    // drawn on top at the shown size, so it stays 2 px. A click: `picked`, with how
    // many places it is from the middle.
    component StripCard: Item {
        id: card

        required property int index
        required property Item strip      // the strip it is in
        property int n: 0                 // how many there are (each one is in the strip strip.copies(n) times)
        property bool ready: true         // false: not shown (a picture without a file)
        signal picked(int offset)

        readonly property int file: n > 0 ? index % n : 0
        readonly property int copy: n > 0 ? Math.floor(index / n) - Math.floor(strip.copies(n) / 2) : 0

        // places from the middle (negative = left)
        readonly property real d: {
            if (n === 0)
                return 0;
            let r = (file - strip.pos) % n;
            r = ((r % n) + n) % n;
            if (r >= n / 2)
                r -= n;
            return r + copy * n;
        }
        readonly property real middle: Math.max(0, 1 - Math.abs(d))     // 1 = in the middle
        readonly property real shown: Theme.wallThumbSmall + (1 - Theme.wallThumbSmall) * middle   // 1 = the big size
        readonly property real exactX: strip.cx + strip.offset(d) * strip.spread - width / 2 + strip.bump

        width: strip.bigW
        height: strip.bigH
        x: strip.moving ? exactX : Math.round(exactX)
        y: Theme.wallSwitchHead
        visible: ready && x + width / 2 + width * shown / 2 > 0 && x + width / 2 - width * shown / 2 < strip.width

        // The outline, at the shown size, exactly over the picture. Placed by
        // hand, not with anchors.centerIn: that rounds to whole pixels, so the
        // outline would step against the smoothly scaled picture as it grows.
        // White (Config.thumbOutline) on the one in the middle, the others like
        // an unfocused window's border; it blends over while one slides in.
        Rectangle {
            id: cardOutline
            z: 1
            width: parent.width * card.shown
            height: parent.height * card.shown
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
            radius: card.strip.bigRadius * card.shown
            color: "transparent"
            border.width: Theme.px(2)
            border.color: {
                const a = card.strip.sideOutline;
                const b = Config.thumbOutline;
                const m = card.middle;
                return Qt.rgba(a.r + (b.r - a.r) * m, a.g + (b.g - a.g) * m, a.b + (b.b - a.b) * m, a.a + (b.a - a.a) * m);
            }
            antialiasing: true
        }

        MouseArea {
            z: 2
            anchors.fill: cardOutline
            cursorShape: Qt.PointingHandCursor
            onClicked: card.picked(Math.round(card.d))
        }
    }

    Item {
        id: wallStrip
        // the pictures end a little inside the island's sides
        x: Theme.wallSwitchPad
        width: root.width - 2 * Theme.wallSwitchPad
        height: root.height
        clip: true
        // Opens like the island on hover: the size on the same curve (PanelAnim on
        // `sw`, like `p`), the pictures fading in at the same point as the island's
        // lower row (`body.lower`), and the side pictures gliding outwards with the
        // island's edges, like its workspace / battery slots.
        opacity: Shapes.clamp((root.sw - 0.35) / 0.65, 0, 1)
        visible: root.sw > 0.01
        readonly property real spread: Shapes.lerp(root.notchShown / root.switchWidth, 1, root.sw)

        // Where the strip is: the cursor of Wallpapers / Themes, gliding from one
        // to the next (it counts on round the loop, it never jumps back to 0).
        property real pos: 0
        // the same motion as switching workspaces: Hyprland's workspace slide
        // takes 300 ms on the "standard" curve (hyprland.lua), so does this
        NumberAnimation {
            id: slide
            target: wallStrip
            property: "pos"
            duration: Theme.durSlide
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveStandard
        }
        function slideTo(cursor) {
            slide.stop();
            slide.from = wallStrip.pos;
            slide.to = cursor;
            slide.start();
        }
        function jumpTo(cursor) {
            slide.stop();
            wallStrip.pos = cursor;
        }
        function nudge(direction) {
            bumpAnim.stop();
            bumpAnim.to = -direction * Theme.px(14);
            bumpAnim.start();
        }
        Connections {
            target: Wallpapers
            enabled: root.switchMode === "wallpaper"
            function onCursorChanged() {
                wallStrip.slideTo(Wallpapers.cursor);
            }
            function onJumped() {
                wallStrip.jumpTo(Wallpapers.cursor);
            }
            function onBumped(direction) {
                wallStrip.nudge(direction);
            }
        }
        Connections {
            target: Themes
            enabled: root.switchMode === "theme"
            function onCursorChanged() {
                wallStrip.slideTo(Themes.cursor);
            }
            function onJumped() {
                wallStrip.jumpTo(Themes.cursor);
            }
            function onBumped(direction) {
                wallStrip.nudge(direction);
            }
        }

        // a single picture / theme: the strip only nudges
        property real bump: 0
        SequentialAnimation {
            id: bumpAnim
            property real to: 0
            NumberAnimation {
                target: wallStrip
                property: "bump"
                to: bumpAnim.to
                duration: Theme.durFast
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: wallStrip
                property: "bump"
                to: 0
                duration: Theme.durOpen
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveDecel
            }
        }

        // centre of a picture `d` places from the middle (fractional while
        // sliding): the big one in the middle, normal ones beside it
        readonly property real bigW: Theme.wallThumbW
        readonly property real bigH: Theme.wallThumbH
        readonly property real smallW: bigW * Theme.wallThumbSmall
        readonly property real firstStep: bigW / 2 + Theme.wallThumbGap + smallW / 2
        readonly property real nextStep: smallW + Theme.wallThumbGap
        // corner radius at the big size: the side pictures end up with Theme.wallThumbRadius
        readonly property real bigRadius: Theme.wallThumbRadius / Theme.wallThumbSmall
        // the outline of the pictures / cards beside the middle: the unfocused window
        // border of the theme in use (inactiveHint in Config.qml)
        readonly property color sideOutline: Config.inactiveHint
        // Every picture is in the strip three times - one loop to the left, the loop,
        // one loop to the right - five times when there are only one or two pictures:
        // two places on each side are seen (one and a half).
        function copies(n) {
            return n < 3 ? 5 : 3;
        }
        function offset(d) {
            const a = Math.abs(d);
            const o = a <= 1 ? a * firstStep : firstStep + (a - 1) * nextStep;
            return d < 0 ? -o : o;
        }
        // The middle of the screen (in the strip's coordinates). Not the middle of
        // the island: that one moves by half a pixel while the island's rounded
        // size changes, the pictures should not.
        readonly property real cx: root.parent.width / 2 - root.x - x
        // exact (sub-pixel) positions while the strip moves - smooth; whole
        // pixels when it stands still - sharp
        readonly property bool moving: slide.running || bumpAnim.running || (root.sw > 0 && root.sw < 1)

        // ── the wallpapers ────────────────────────────────────────────────
        // Every picture three (or five) times - copies() - so there are always
        // pictures on both sides, even with only one or two. Each copy sits where
        // it is nearest the middle. (They stay loaded while the theme switcher is open.)
        Item {
            anchors.fill: parent
            visible: root.switchMode === "wallpaper"

            Repeater {
                model: Wallpapers.count * wallStrip.copies(Wallpapers.count)

                StripCard {
                    id: thumb
                    strip: wallStrip
                    n: Wallpapers.count
                    readonly property string path: n > 0 && file < Wallpapers.files.length ? Wallpapers.files[file] : ""
                    ready: path.length > 0

                    // a click beside the middle: it slides to the middle; on the one in
                    // the middle: like Enter (it becomes the wallpaper, the switcher closes)
                    onPicked: offset => {
                        if (offset !== 0)
                            Wallpapers.browseBy(offset);
                        else
                            Ui.applySwitcher();
                    }

                    // the picture: fixed size, scaled around its middle. 1 px inside the
                    // outline, so its edge is always under it (the two round their curves a
                    // little differently, the corner would peek out)
                    ClippingRectangle {
                        x: Theme.px(1)
                        y: Theme.px(1)
                        width: parent.width - 2 * x
                        height: parent.height - 2 * y
                        transformOrigin: Item.Center
                        scale: thumb.shown
                        radius: wallStrip.bigRadius - Theme.px(1)
                        color: Config.selected              // until the picture has loaded

                        Image {
                            id: thumbImage
                            anchors.fill: parent
                            source: root.thumbsWanted && thumb.path.length > 0 ? "file://" + thumb.path : ""
                            sourceSize.width: wallStrip.bigW
                            sourceSize.height: wallStrip.bigH
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity {
                                Anim {
                                    duration: Theme.durSmall
                                }
                            }

                            // a picture that is still being copied into the folder can't be
                            // read yet: try again a few times
                            property int tries: 0
                            onStatusChanged: {
                                if (status === Image.Error && tries < 5)
                                    retry.restart();
                            }
                            Timer {
                                id: retry
                                interval: 1500
                                onTriggered: {
                                    thumbImage.tries++;
                                    thumbImage.source = "";
                                    thumbImage.source = Qt.binding(() => root.thumbsWanted && thumb.path.length > 0 ? "file://" + thumb.path : "");
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── the colour themes ─────────────────────────────────────────────
        // A card in the theme's own colours: its main colour, a row of five dots
        // (its greys, its text colours and the focused window's border, activeHint;
        // the darkest on the left, the lightest on the right), its name under them.
        Item {
            anchors.fill: parent
            visible: root.switchMode === "theme"

            Repeater {
                model: Themes.count * wallStrip.copies(Themes.count)

                StripCard {
                    id: themeCard
                    strip: wallStrip
                    n: Themes.count
                    readonly property var theme: n > 0 && file < Themes.list.length ? Themes.list[file] : null
                    // the dots: from the darkest (left) to the lightest (right)
                    readonly property var dots: Themes.dots(theme)
                    ready: theme !== null

                    // the same as a picture: beside the middle it slides there, in the middle: Enter
                    onPicked: offset => {
                        if (offset !== 0)
                            Themes.browseBy(offset);
                        else
                            Ui.applySwitcher();
                    }

                    Rectangle {
                        x: Theme.px(1)
                        y: Theme.px(1)
                        width: parent.width - 2 * x
                        height: parent.height - 2 * y
                        transformOrigin: Item.Center
                        scale: themeCard.shown
                        radius: wallStrip.bigRadius - Theme.px(1)
                        color: themeCard.theme ? Config.themeColor(themeCard.theme, "frame") : Config.selected
                        antialiasing: true

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.px(14)

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Theme.px(8)

                                Repeater {
                                    model: themeCard.dots

                                    Rectangle {
                                        required property color modelData
                                        width: Theme.px(16)
                                        height: width
                                        radius: width / 2
                                        color: modelData
                                        antialiasing: true
                                    }
                                }
                            }

                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: themeCard.theme ? themeCard.theme.name : ""
                                color: themeCard.theme ? Config.themeColor(themeCard.theme, "text") : Config.text
                                font.pixelSize: Theme.px(16)
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }

    // ── the switcher's words ──────────────────────────────────────────────
    // Above the pictures / themes: where you are ("3 / 7") on the left, the arrow
    // keys that browse on the right. They fade in and out with the pictures.
    Item {
        id: switchText
        anchors.fill: parent
        visible: root.sw > 0.01
        opacity: wallStrip.opacity

        readonly property bool walls: root.switchMode === "wallpaper"
        readonly property int count: walls ? Wallpapers.count : Themes.count
        readonly property int at: walls ? Wallpapers.selectedIndex : Themes.selectedIndex
        readonly property real inset: Theme.wallSwitchText

        // the row the words sit in, centred a little below the middle of the gap
        // above the pictures
        readonly property real rowH: Theme.px(44)

        // where you are
        Txt {
            x: switchText.inset
            height: switchText.rowH
            visible: switchText.count > 0
            text: (switchText.at + 1) + " / " + switchText.count
            font.pixelSize: Theme.px(11)
            font.weight: Font.Medium
            color: Config.textDim
        }

        // the keys that browse: left / right, the themes down / up (SUPER + CTRL + Down goes
        // left, Up right)
        KeyHint {
            x: Math.round(parent.width - width - switchText.inset)
            y: Math.round((switchText.rowH - height) / 2)
            keys: switchText.walls ? ["<", ">"] : ["v", "^"]
            label: "Browse"
        }
    }
}
