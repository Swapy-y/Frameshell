import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.components
import "../components/shapes.js" as Shapes

// ═══════════════════════════════════════════════════════════════════════════
//  Island.qml - the notch at the top centre.
//
//  Collapsed: workspaces · clock · signal + battery - with "Glowing icons"
//             (Settings > Appearance) the white parts of it (the workspace you are
//             on, signal + battery) softly glow - not the clock
//  Hovered:   grows downward and also shows the date, the round Bluetooth and
//             Wi-Fi buttons, what is playing (picture, title, artist) with the
//             progress bar, its times and the media buttons, and the notifications
//             capsule.
//
//  A click on Wi-Fi or Bluetooth opens its card in the middle of the screen
//  (modules/NetPopup.qml).
//
//  Click to expand (Config.clickToExpand, the Settings app's Experimental page):
//  the pointer on it only lets it grow a little (`peeking`; with auto hide a
//  small block out of the top edge), none of the open island showing yet; a click
//  on it (not on a workspace pill: that still goes to the workspace) opens it,
//  until the pointer leaves it.
//
//  Auto hide (the Settings app, Store.islandAutoHide): nothing of the island
//  sticks out of the frame (the notch shrinks into the middle of the top edge);
//  when the pointer touches the top edge of the screen above it (`hot`, a strip
//  of the frame, see Overlay.qml) it grows out of the middle straight into the
//  open island, over your windows.
//
//  SUPER + CTRL + Left / Right: the island grows into the wallpaper switcher - your
//  wallpapers in order (no loop: it stops at the first and the last), the one it
//  is on in the middle (white outline), one on each side - and slides to the
//  previous / next one (services/
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

    // ── glow of the closed notch ──────────────────────────────────────────
    // How strongly the white parts of the closed notch glow (0 = no glow at all):
    // "Glowing icons" (Config.glowingIcons, Settings > Appearance) - off: 0, and
    // nothing is rendered for it. Switched, the glow fades in / out.
    property real glowStrength: Config.glowingIcons ? 0.9 : 0
    Behavior on glowStrength {
        NumberAnimation {
            duration: Theme.durSmall
            easing.type: Easing.OutCubic
        }
    }

    // A soft halo behind one item (`source`; give it the item's place with
    // anchors.fill). It is the item itself, blurred twice - a tight blur for the
    // glow close to it and a wide one for the haze - so the glow always has the
    // item's own colour. The item itself is not touched: it is drawn as before, on
    // top. `amount` (0 ... 1) fades the glow; at 0 nothing is drawn or rendered.
    component NotchGlow: Item {
        id: glow
        required property Item source
        property real amount: 0

        visible: amount > 0.01 && source.width > 0 && source.height > 0
        opacity: amount

        MultiEffect {
            anchors.fill: parent
            source: glow.source
            blurEnabled: true
            blurMax: Math.min(64, Math.round(Theme.px(32)))
            blur: 0.5                       // the wide haze (about 16 px)
        }
        MultiEffect {
            anchors.fill: parent
            source: glow.source
            blurEnabled: true
            blurMax: Math.min(64, Math.round(Theme.px(32)))
            blur: 0.2                       // the tight glow (about 6 px)
        }
    }

    // ── open / close ──────────────────────────────────────────────────────
    // auto hide: 0 = the notch is there, 1 = nothing is there until you hover
    // (Disable island, Store.islandDisabled: nothing is there, and hovering does nothing -
    // the wallpaper / theme switcher still grows out of the top edge)
    property real hidden: Store.islandHidden ? 1 : 0
    Behavior on hidden {
        PanelAnim {
            opening: !Store.islandHidden
        }
    }
    // the wallpaper / theme switcher takes the island's place while it is open
    readonly property bool switching: Ui.wallpaperOpen || Ui.themeOpen
    // the launcher / switcher grows out of the notch (components/IslandSheet.qml): the
    // top row (workspaces, clock, signal + battery) fades away first, so the notch the
    // sheet starts from is plain black, and comes back once it has shrunk back in
    property real handOff: Ui.islandSheets > 0 ? 0 : 1
    Behavior on handOff {
        NumberAnimation {
            duration: Theme.durHandOff
            easing.type: Easing.OutQuad
        }
    }
    // what the switcher shows: "wallpaper" or "theme" (kept while it closes)
    property string switchMode: "wallpaper"
    property real sw: switching ? 1 : 0        // 0 = notch, 1 = wallpaper / theme switcher
    Behavior on sw {
        PanelAnim {
            opening: root.switching
        }
    }

    // Click to expand: the island was clicked while it peeked (until the pointer leaves it)
    property bool clicked: false
    readonly property bool expanded: latch.open && !switching && (!Config.clickToExpand || clicked)
    readonly property bool peeking: Config.clickToExpand && latch.open && !clicked && !switching
    // ... how far it grows then: 12 px taller than the notch - with auto hide (no notch) as
    // tall as the frame's width and 14 px, like a panel's peek (components/Panel.qml)
    readonly property real peekH: Math.max(notchHeight + Theme.px(12), Theme.edge + Theme.px(14))
    readonly property real peekP: Shapes.clamp((peekH - notchHeight) / Math.max(1, fullH - notchHeight), 0, 0.45)
    property real p: expanded ? 1 : (peeking ? peekP : 0)      // 0 = notch, 1 = full island
    Behavior on p {
        PanelAnim {
            opening: root.expanded || root.peeking
        }
    }

    // ── size ──────────────────────────────────────────────────────────────
    // the open island's height: the space under the media buttons is the same as
    // above the picture (under the clock). The clock row sits in the middle of the
    // notch (Theme.notchH).
    readonly property real lowerTop: Theme.px(56)
    readonly property real lowerH: Theme.px(92)
    readonly property real wantedH: lowerTop + lowerH + Theme.px(8)

    // the round buttons on both sides: their size, top (centred on the media
    // column) and how far the two groups' middles are from the island's middle
    // the open island's grey buttons (off Bluetooth / Wi-Fi, the notifications capsule,
    // the light behind a media button under the pointer)
    readonly property color buttonGrey: "#0b0b0b"
    readonly property real buttonSize: Theme.px(42)
    readonly property real buttonTop: Theme.px(70)
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
    // frameless (Config.framelessOutline): the whole island moves up into the frame's
    // place, its top part off the screen - the same shape, only higher (Theme.notchShift)
    // (in whole pixels, so its content stays sharp while it moves: the shape glides)
    y: -Math.round(Theme.notchShift)

    HoverLatch {
        id: latch
        input: !Store.islandDisabled && (hover.hovered || root.hot || openHover.hovered)
        onOpenChanged: {
            if (!open)
                root.clicked = false;
        }
    }

    HoverHandler {
        id: hover
    }

    // While it is open, the whole open island counts as "on it", even while it is
    // still growing: the pointer can be quicker than the island (auto hide: from
    // the edge of the screen straight down to its buttons). Overlay.qml adds it to
    // the window's input area. (Click to expand: only once it opens, not while it peeks.)
    readonly property Item openArea: openAreaItem
    Item {
        id: openAreaItem
        readonly property bool on: root.expanded
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
        // frameless it moves up with the frame's edge (Theme.notchShift, Theme.frameEdge):
        // the same shape, only higher
        fy: -Theme.notchShift
        fw: root.fw
        fh: root.fh
        fillLayer: root.fillLayer
        strokeLayer: root.strokeLayer
        attachTop: true
    }

    // Click to expand: the click that opens the peeking island - under its content, so a
    // workspace pill still takes its own click. It takes no hover (`hover` above sees it).
    MouseArea {
        anchors.fill: parent
        visible: root.peeking
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked = true
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
            // the workspaces and signal + battery: beside the clock closed, open centred over the
            // Bluetooth + Wi-Fi buttons and the notifications capsule
            readonly property real slotOffset: Shapes.lerp(Theme.px(91), root.sideOffset, root.p)
            readonly property real rowCenter: Theme.notchH / 2
            readonly property real lower: Shapes.clamp((root.p - 0.35) / 0.65, 0, 1)   // fades in the lower area
            // the top row (workspaces, clock, signal + battery): hidden with the island
            // (auto hide), fading in while it grows open; away while a sheet grows out of it
            readonly property real topRow: (1 - root.hidden * (1 - Shapes.clamp((root.p - 0.1) / 0.4, 0, 1))) * root.handOff
            // the glow of the white parts of the closed notch: full while the island is closed,
            // gone before the lower area starts to fade in (at the same point, `lower`)
            readonly property real glow: root.glowStrength * (1 - Shapes.clamp(root.p / 0.35, 0, 1))

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
                // (the 5th) should not wait for it. (10 workspaces: the pill that
                // stands for it - the 5th on workspaces 5 ... 10, Spaces.focusedPill.)
                readonly property var shownIds: {
                    const ids = Spaces.ids;
                    const here = Spaces.focusedPill;
                    return ids.indexOf(here) >= 0 || Spaces.slots.indexOf(here) < 0 ? ids : ids.concat([here]);
                }

                readonly property real restW: {
                    let w = shownIds.length * (wOff + gap);
                    if (shownIds.indexOf(Spaces.focusedPill) >= 0)
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
                            readonly property bool active: modelData === Spaces.focusedPill
                            readonly property bool present: wsSlot.shownIds.indexOf(modelData) >= 0
                            // the small pill's colour: a bit lighter when tiling is off there - and
                            // always for the 5th of "10 workspaces" (it stands for 5 ... 10)
                            readonly property bool lighter: Spaces.untiled.indexOf(modelData) >= 0 || (Spaces.ten && modelData === Spaces.tenPills)
                            readonly property color offColor: lighter ? Config.frameColors.workspaceUntiled : Config.frameColors.inactive

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

                            // "10 workspaces": the 5th pill stands for 5 ... 10, so going from
                            // one of them to another the white pill stays where it is - it
                            // plays the move in place instead: it shrinks to a small pill and
                            // grows straight back, staying white (as long as a move, both halves
                            // together)
                            property real dip: 0
                            readonly property real look: on * (1 - dip)
                            property int lastId: -1
                            Component.onCompleted: lastId = Spaces.focusedId
                            Connections {
                                target: Spaces
                                function onFocusedIdChanged() {
                                    const was = dot.lastId;
                                    const now = Spaces.focusedId;
                                    dot.lastId = now;
                                    if (Spaces.ten && dot.modelData === Spaces.tenPills && was !== now && was >= Spaces.tenPills && now >= Spaces.tenPills)
                                        dipAnim.restart();
                                }
                            }
                            SequentialAnimation {
                                id: dipAnim
                                NumberAnimation {
                                    target: dot
                                    property: "dip"
                                    to: 1
                                    duration: Math.round(Theme.durSmall * 0.6)
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveStandard
                                }
                                NumberAnimation {
                                    target: dot
                                    property: "dip"
                                    to: 0
                                    duration: Math.round(Theme.durSmall * 0.6)
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveStandard
                                }
                            }

                            // width of the pill, and of its place: the pill + the air
                            // beside it. A pill that appears or disappears grows from /
                            // shrinks to a thin line in the middle of its place (no
                            // clipping: a clipped edge moves in whole pixels and would
                            // wobble the new pill while it appears).
                            readonly property real pillW: Shapes.lerp(wsSlot.wOff, wsSlot.wOn, look)
                            // (its place keeps the white pill's width through the dip: the
                            // pills beside it don't move)
                            width: (Shapes.lerp(wsSlot.wOff, wsSlot.wOn, on) + wsSlot.gap) * shown
                            height: wsSlot.rowH
                            opacity: shown
                            visible: shown > 0

                            // the glow of the white pill (the workspace you are on) - it
                            // follows the pill's colour, so the small grey ones don't glow
                            NotchGlow {
                                anchors.fill: pill
                                source: pill
                                amount: body.glow * dot.on
                            }

                            Rectangle {
                                id: pill
                                width: dot.pillW * dot.shown
                                height: Shapes.lerp(wsSlot.hOff, wsSlot.hOn, dot.look)
                                // centred by hand (see above)
                                x: (dot.width - width) / 2
                                y: (dot.height - height) / 2 + Shapes.lerp(wsSlot.nudgeOff, wsSlot.nudgeOn, dot.look)
                                radius: width / 2
                                // (the colour follows `on`, not the dip: the pill stays white while it dips)
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
            // its right and the pair stays centred. When the minute (or hour) changes,
            // the changed digits roll: the old ones up and out, the new ones up from
            // below (components/RollText.qml).
            Row {
                id: clockRow
                x: Math.round((body.width - width) / 2)
                y: Math.round(body.rowCenter - height / 2)
                spacing: 0
                opacity: body.topRow
                visible: opacity > 0.01

                RollText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Clock.time
                    pixelSize: Theme.fsClock
                    weight: Font.DemiBold
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Clock.dateWords
                    font.pixelSize: Theme.fsSmall
                    color: Config.frameColors.textSecondary
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

                // the glow of signal + battery (the slot already fades with the top row)
                NotchGlow {
                    anchors.fill: statusRow
                    source: statusRow
                    amount: body.glow
                }

                Row {
                    id: statusRow
                    // 1 px left of the middle (looks centred), on whole pixels
                    x: Math.round((parent.width - width) / 2) - Theme.px(1)
                    y: Math.round((parent.height - height) / 2)
                    spacing: Theme.px(7)

                    SignalIcon {
                        id: signalIcon
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.px(14)
                        level: NetSpeed.level
                    }

                    // 2 px shorter than the signal icon: 1 px in from its top and its bottom
                    BatteryIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.px(28)
                        bodyHeight: signalIcon.height - Theme.px(2)
                        level: Battery.level
                        charging: Battery.charging
                    }
                }
            }

            // ── Bluetooth and Wi-Fi (left, visible when expanded) ─────────────
            // Round buttons: white with a dark icon = on, a grey circle with a white
            // icon = off (or not available). A click opens the list of devices / networks in a card in
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
                            size: Theme.px(28),         // the rune: about 13 x 22
                            offset: -Theme.px(28)
                        },
                        {
                            page: "wifi",
                            icon: "wifi",
                            size: Theme.px(30),         // about 25 x 19
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
                        edge: true                       // the outline ("No outline buttons" takes it away)
                        offColor: root.buttonGrey
                        hoverColor: offColor             // no change under the pointer
                        iconColor: Config.text
                        onClicked: Ui.toggleNet(modelData.page)
                    }
                }
            }

            // ── media (centre column) ─────────────────────────────────────────
            // Laid out like Apple's Now Playing: what is playing (the cover or the
            // video's picture, the title and the artist / channel); under it the
            // progress bar, the time played on its left and the whole length on its
            // right; under that the buttons - back, play / pause, forward - in the
            // shapes of Apple's SF Symbols.
            Item {
                id: mediaCol
                // no times beside the bar, so a narrower column, a shorter bar and smaller
                // buttons - unless "Detailed media controls" (Config.detailedMedia) is on
                readonly property bool minimal: !Config.detailedMedia
                width: minimal ? Theme.px(192) : Theme.px(232)
                height: controls.y + controls.height
                x: Math.round(body.cx - width / 2)
                y: Theme.px(50)
                opacity: body.lower
                visible: opacity > 0.01

                // ── now playing: picture + title + artist, centred over the bar ──
                Item {
                    id: nowPlaying

                    readonly property real coverSize: Theme.px(34)
                    readonly property real gap: Theme.px(10)
                    // the text is as wide as it needs, the whole row never wider than the column
                    readonly property real textWidth: Math.min(mediaCol.width - coverSize - gap, Math.ceil(Math.max(titleText.implicitWidth, artistText.implicitWidth)))

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
                        radius: Theme.px(8)
                        color: Config.frameColors.inactive           // no picture (yet)

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
                            color: Config.frameColors.textTertiary
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
                        // centred on the picture, on whole pixels
                        y: Math.round((nowPlaying.coverSize - height) / 2)
                        width: nowPlaying.textWidth
                        spacing: Theme.px(1)

                        Txt {
                            id: titleText
                            width: parent.width
                            text: nowPlaying.title
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.DemiBold
                            color: Media.has ? Config.text : Config.frameColors.textSecondary
                            elide: Text.ElideRight
                        }

                        Txt {
                            id: artistText
                            width: parent.width
                            visible: text !== ""
                            text: nowPlaying.artist
                            font.pixelSize: Theme.px(12)
                            color: Config.frameColors.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                }

                // ── progress: time played · the bar · the whole length ─────────
                // A stream without a length has no times: the bar alone, as wide as the row.
                Item {
                    id: seekRow

                    readonly property real length: Media.player !== null && Media.player.lengthSupported ? Math.max(0, Media.player.length) : 0
                    readonly property bool timed: length > 0 && !mediaCol.minimal
                    // where it is, in seconds (while you drag the bar: where you drag it to)
                    readonly property real at: seek.shown * length
                    // both times get the same room - as wide as the length ("0:00" for it,
                    // its figures all the same width: the time played is never wider) -
                    // so the bar stays in the middle and never changes its length
                    readonly property real timeW: timed ? Math.ceil(timeMetrics.advanceWidth) : 0
                    readonly property real timeGap: timed ? Theme.px(8) : 0

                    // seconds as "m:ss" ("h:mm:ss" from an hour on)
                    function clock(s) {
                        const t = Math.max(0, Math.floor(s));
                        const h = Math.floor(t / 3600);
                        const m = Math.floor(t / 60) % 60;
                        const two = n => (n < 10 ? "0" : "") + n;
                        return h > 0 ? h + ":" + two(m) + ":" + two(t % 60) : m + ":" + two(t % 60);
                    }

                    width: mediaCol.width
                    height: Theme.px(12)
                    y: nowPlaying.height + Theme.px(7)

                    TextMetrics {
                        id: timeMetrics
                        font: playedText.font
                        text: seekRow.clock(seekRow.length).replace(/[0-9]/g, "0")
                    }

                    Txt {
                        id: playedText
                        visible: seekRow.timed
                        x: 0
                        width: seekRow.timeW
                        height: parent.height
                        horizontalAlignment: Text.AlignRight
                        text: seekRow.clock(seekRow.at)
                        font.pixelSize: Theme.px(11)
                        font.weight: Font.Medium
                        font.features: {
                            "tnum": 1         // figures all the same width: the time doesn't wobble
                        }
                        color: Config.frameColors.textSecondary
                    }

                    FSlider {
                        id: seek
                        x: seekRow.timeW + seekRow.timeGap
                        width: seekRow.width - 2 * x
                        anchors.verticalCenter: parent.verticalCenter
                        trackHeight: Theme.px(6)
                        interactive: Media.player !== null && Media.player.canSeek
                        value: Media.progress
                        onMoved: v => Media.seekTo(v)
                    }

                    Txt {
                        visible: seekRow.timed
                        x: seekRow.width - width
                        width: seekRow.timeW
                        height: parent.height
                        horizontalAlignment: Text.AlignLeft
                        // the whole length of the song / video
                        text: seekRow.clock(seekRow.length)
                        font.pixelSize: playedText.font.pixelSize
                        font.weight: playedText.font.weight
                        font.features: playedText.font.features
                        color: Config.frameColors.textSecondary
                    }
                }

                // ── the buttons: back · play / pause · forward ───────────────────
                // All three the same size: the shapes make play / pause the tallest and
                // back / forward the widest, as in Apple's. Under the pointer a soft round
                // light comes up behind the icon; pressed, the icon dips.
                Row {
                    id: controls
                    x: Math.round((mediaCol.width - width) / 2)
                    y: seekRow.y + seekRow.height + Theme.px(5)
                    spacing: mediaCol.minimal ? Theme.px(9) : Theme.px(10)

                    Repeater {
                        model: ["prev", "toggle", "next"]

                        Item {
                            id: btn
                            required property string modelData
                            readonly property bool main: modelData === "toggle"
                            readonly property bool available: Media.has

                            width: Theme.px(42)
                            height: Theme.px(26)

                            Rectangle {
                                width: Theme.px(32)
                                height: width
                                x: Math.round((parent.width - width) / 2)
                                y: Math.round((parent.height - height) / 2)
                                radius: width / 2
                                color: root.buttonGrey
                                antialiasing: true
                                opacity: btnArea.containsMouse ? 1 : 0
                                scale: btnArea.pressed ? 0.9 : 1

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

                            Icon {
                                x: Math.round((parent.width - width) / 2)
                                y: Math.round((parent.height - height) / 2)
                                size: mediaCol.minimal ? Theme.px(18) : Theme.px(20)
                                name: btn.main ? (Media.playing ? "pause" : "play") : btn.modelData
                                color: btn.available ? Config.text : Config.frameColors.textTertiary
                                scale: btnArea.pressed ? 0.86 : 1

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
            // A capsule like a tile of Apple's Control Center: the round bell at its
            // left end - white with a dark bell = notifications on, grey with the bell
            // struck out = "Do not disturb" - then "Notifications" and, under it, "On" /
            // "Off". A click anywhere on it switches it.
            Item {
                id: bellCol
                readonly property bool on: Store.notificationsOn

                width: root.buttonSize + Theme.px(10) + Math.ceil(Math.max(bellTitle.implicitWidth, offMetrics.advanceWidth)) + Theme.px(18)
                height: root.buttonSize
                x: Math.round(body.cx + root.sideOffset - width / 2)
                y: root.buttonTop
                opacity: body.lower
                visible: opacity > 0.01

                // the wider of the two states: the capsule keeps its size when it switches
                TextMetrics {
                    id: offMetrics
                    font: bellState.font
                    text: "Off"
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.buttonGrey
                    border.width: Theme.outlineW            // the outline ("No outline buttons" takes it away)
                    border.color: Theme.outlineColor
                    antialiasing: true
                }

                RingButton {
                    x: 0
                    on: bellCol.on
                    icon: bellCol.on ? "bell-fill" : "bell-off"
                    iconSize: Theme.px(24)
                    outline: false
                    // off: see-through - the capsule (its grey, and its outline)
                    // shows behind the bell
                    offColor: "transparent"
                    hoverColor: offColor
                    iconColor: Config.text
                    interactive: false                       // the whole capsule is the button
                    hot: bellArea.containsMouse
                    down: bellArea.pressed
                }

                Column {
                    x: root.buttonSize + Theme.px(10)
                    y: Math.round((parent.height - height) / 2)
                    spacing: 0

                    Txt {
                        id: bellTitle
                        text: "Notifications"
                        font.pixelSize: Theme.px(13)
                        font.weight: Font.DemiBold
                    }

                    Txt {
                        id: bellState
                        text: bellCol.on ? "On" : "Off"
                        font.pixelSize: Theme.px(12)
                        color: Config.frameColors.textSecondary
                    }
                }

                MouseArea {
                    id: bellArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Store.notificationsOn = !Store.notificationsOn
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
                    color: Config.frameColors.inactive       // a soft grey key

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
            color: Config.frameColors.textSecondary
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

    // One picture / theme of the strip, placed by its place in the list: the
    // big one in the middle, the others beside it (none before the first or after
    // the last: no loop). What it shows goes inside it,
    // drawn at the big size and scaled down by `shown` (on the graphics card) beside
    // the middle, so nothing is resized or redrawn while it slides; the outline is
    // drawn on top at the shown size, so it stays 2 px. A click: `picked`, with how
    // many places it is from the middle.
    component StripCard: Item {
        id: card

        required property int index
        required property Item strip      // the strip it is in
        property int n: 0                 // how many there are
        property bool ready: true         // false: not shown (a picture without a file)
        signal picked(int offset)

        readonly property int file: index

        // places from the middle (negative = left)
        readonly property real d: n > 0 ? file - strip.pos : 0
        readonly property real middle: Math.max(0, 1 - Math.abs(d))     // 1 = in the middle
        readonly property real shown: Theme.wallThumbSmall + (1 - Theme.wallThumbSmall) * middle   // 1 = the big size
        readonly property real exactX: strip.cx + strip.offset(d) * strip.spread - width / 2

        width: strip.bigW
        height: strip.bigH
        x: strip.moving ? exactX : Math.round(exactX)
        y: Theme.wallSwitchHead
        visible: ready && x + width / 2 + width * shown / 2 > 0 && x + width / 2 - width * shown / 2 < strip.width

        // The outline, at the shown size, exactly over the picture. Placed by
        // hand, not with anchors.centerIn: that rounds to whole pixels, so the
        // outline would step against the smoothly scaled picture as it grows.
        // White (Config.previewSelectedBorder) on the one in the middle, the others like
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
                const b = card.strip.middleOutline;
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
        // to the next.
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
        Connections {
            target: Wallpapers
            enabled: root.switchMode === "wallpaper"
            function onCursorChanged() {
                wallStrip.slideTo(Wallpapers.cursor);
            }
            function onJumped() {
                wallStrip.jumpTo(Wallpapers.cursor);
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
        // border of the theme in use (windowBorderInactive in Config.qml)
        readonly property color sideOutline: Config.frameColors.windowBorderInactive
        // ... and the one in the middle (white). Both typed as colours: the outline mixes them by
        // their red, green and blue (Config.frameColors keeps them as text)
        readonly property color middleOutline: Config.frameColors.previewSelectedBorder
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
        readonly property bool moving: slide.running || (root.sw > 0 && root.sw < 1)

        // ── the wallpapers ────────────────────────────────────────────────
        // Every picture once, in order: the first has nothing on its left, the last
        // nothing on its right. (They stay loaded while the theme switcher is open.)
        Item {
            anchors.fill: parent
            visible: root.switchMode === "wallpaper"

            Repeater {
                model: Wallpapers.count

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
                        color: Config.frameColors.controlBackground              // until the picture has loaded

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
        // (its greys, its text colours and the focused window's border, windowBorderActive;
        // the darkest on the left, the lightest on the right), its name under them.
        Item {
            anchors.fill: parent
            visible: root.switchMode === "theme"

            Repeater {
                model: Themes.count

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
                        color: themeCard.theme ? Config.themeColor(themeCard.theme, "background") : Config.frameColors.controlBackground
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
            color: Config.frameColors.textSecondary
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
