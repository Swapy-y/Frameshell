pragma Singleton

import QtQuick
import Quickshell

// ═══════════════════════════════════════════════════════════════════════════
//  Theme.qml  -  sizes and motion shared by the whole shell (no need to edit).
//
//  Sizes are written for a 1080p screen (the concept art) and scaled with px().
//  Colours and the settings you can change live in Config.qml.
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    // ── scaling ────────────────────────────────────────────────────────────
    readonly property real autoScale: {
        const s = Quickshell.screens;
        return s.length > 0 && s[0].height > 0 ? Math.max(0.6, s[0].height / 1080) : 1;
    }
    readonly property real scale: Config.scale > 0 ? Config.scale : autoScale

    function px(v) {
        return Math.round(v * scale);
    }

    // Sizes of the app switcher and the launcher: px() times Config.popupScale.
    function pop(v) {
        return Math.round(v * scale * Config.popupScale);
    }

    // ── frame ──────────────────────────────────────────────────────────────
    // A dark frame round the left, top and right of the screen (`edge` wide): the
    // Settings app's "Frame overlay" (Appearance, Config.frameOverlay). Off (at first;
    // Config.framelessOutline) there is none: the wallpaper reaches those edges and only
    // the screen's corners are rounded off; the bar, the notch and the panels stay dark
    // shapes.
    readonly property int edge: Math.max(2, px(3))        // the strip along the left / top / right edges: the dark frame - or, frameless, only a place that reacts to the pointer (the hot corners and edges)
    readonly property int bar: px(42)                     // dark bar at the bottom
    readonly property int cornerRadius: Config.cornerRadius

    // The edge of every dark shape is drawn as a 1 px border (in real pixels) round
    // its fill: a border's edge is smoother than a fill's, and its curves rounder. It
    // lies *inside* the size of each shape - the frame, the bar, the notch and the
    // panels are as big as they would be without one: their fill is a pixel smaller
    // all round (Flap.qml, `frameEdge` below, Overlay.qml's bar) and the border
    // fills that pixel. Its colour is the frame's (Config.frameColors.border).
    readonly property int border: 1

    // 0 = the frame, 1 = frameless (Config.framelessOutline: "Frame overlay" off). Flipping
    // the Settings app's switch glides from one to the other: the frame narrows away into the screen's edges
    // (or grows back out of them) and the island moves with it. What windows keep free
    // (inset, notchShiftTo: Reserve.qml) switches at once, so they move only once.
    property real frameless: Config.framelessOutline ? 1 : 0
    Behavior on frameless {
        NumberAnimation {
            duration: root.durOpen
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.curveStandard
        }
    }
    readonly property real frame: edge * (1 - frameless)   // the frame you see on the left / top / right (its border included)

    // Where the shapes (components/shapes.js) put the frame's edge on the left,
    // top and right: the border is drawn round the fill, so the edge is a border
    // width inside the frame you see - frameless, a border width outside the screen,
    // so the outside of the border lands exactly on the screen's edge. Nothing of it
    // shows along the edges then - only round the corners, the notch and the panels,
    // where it narrows away smoothly into the edge.
    readonly property real frameEdge: frame - border

    // How far the panels (components/Panel.qml: the sliders, the colour picker, the
    // clipboard, the quick note, the calendar, the power menu ...) move towards the left /
    // top / right edge they sit on with "Frame overlay" off, like the island
    // (notchShift): the frame they grow out of is gone, so they move into its place and
    // keep their shape exactly - the same panel, a frame's width further out - instead of
    // their concave curves growing out to the edge of the screen. 0 with the frame.
    readonly property real frameShift: edge * frameless

    // Distance from the screen edge to the inside of the frame. The space Hyprland
    // reserves for windows starts here (plus the window gap, Config.windowGap).
    readonly property int inset: Config.framelessOutline ? 0 : edge
    readonly property int insetBottom: bar

    // One radius for every corner of the shell, exactly like the concept art:
    // the corners of the window area, the concave "ears" where a panel meets
    // the frame, and the rounded corners of the panels themselves - the radius of
    // their fill (the border makes a panel's own corners a pixel rounder, the
    // ears and the window area's corners a pixel less).
    readonly property int windowRadius: cornerRadius + border
    readonly property int earRadius: windowRadius
    readonly property int panelRadius: windowRadius
    // ... but the four corners of the window area itself (the frame round the windows - or,
    // frameless, the screen's rounded corners) follow
    // the Settings app's "Corner rounding" (Config.cornerRounding), like the windows' corners
    readonly property int frameCornerRadius: Math.max(0, Config.cornerRounding) + border

    // ── island (notch) ─────────────────────────────────────────────────────
    // The closed notch: small concave "ears" where it meets the top, flowing into its
    // rounded bottom corners (the radii are the panels', shrunk to fit its height -
    // components/shapes.js). 324 x 38 at 1080p.
    readonly property int notchW: px(324)
    readonly property int notchH: px(38)
    // How far the island moves up with "Frame overlay" off: the frame it hangs from is
    // gone, so the notch - and everything in it, open or closed - moves up into its place
    // (the frame's `edge`) and keeps its shape exactly, instead of growing up to the edge.
    // 0 with the frame.
    readonly property real notchShift: frameShift
    readonly property int notchShiftTo: Config.framelessOutline ? edge : 0     // where it is going (what windows keep free)
    readonly property int islandW: px(716)

    // ── wallpaper / theme switcher (the island, SUPER + CTRL + Left / Right, Up / Down) ──
    // The picture you are on in the middle (a little bigger) and one whole picture
    // on each side, ending wallSwitchPad inside the island's sides (674 at 1080p).
    readonly property int wallSwitchW: wallThumbW + 2 * (wallThumbGap + Math.ceil(wallThumbW * wallThumbSmall) + wallSwitchPad)
    // a row above the pictures (where you are: "3 / 7", the keys that browse), a gap under them
    readonly property int wallSwitchHead: px(36)
    readonly property int wallSwitchFoot: px(23)
    readonly property int wallSwitchH: wallSwitchHead + wallThumbH + wallSwitchFoot   // 184 at 1080p
    readonly property int wallSwitchText: px(14)  // the words start / end this far from the island's sides (in line with the pictures)
    readonly property int wallThumbW: px(222)      // the picture in the middle
    readonly property int wallThumbH: px(125)
    readonly property real wallThumbSmall: 0.875   // the others, this much of it: 194 x 109
    readonly property int wallThumbGap: px(19)
    readonly property int wallThumbRadius: px(12)
    readonly property int wallSwitchPad: px(12)   // the pictures end this far from the island's sides (like the clipboard's entries)

    // ── panels (widths; heights follow their content) ──────────────────────
    readonly property int slidersW: px(300)
    readonly property int notifMinW: px(80)       // small: a short notification is as wide as its text (+ 16 px each side)
    readonly property int notifMaxW: px(300)
    readonly property int notifMaxH: px(220)
    readonly property int noteW: px(300)
    readonly property int noteMinH: px(150)
    readonly property int clipW: px(300)        // clipboard panel (left edge), like the note
    readonly property int pickerW: px(44)       // colour picker block (top right corner)
    readonly property int pickerH: px(41)

    // ── typography ─────────────────────────────────────────────────────────
    // Apple's SF Pro when it is installed, else Inter - the free font closest to
    // it, bundled (assets/fonts, SIL Open Font License; shell.qml loads it). SF Pro
    // itself can't be bundled (Apple's licence): README.md says how to install it.
    // `font` is the cut for text (SF Pro Text / Inter), `fontDisplay` the one for
    // big titles, 20 px and up (SF Pro Display / Inter Display), as Apple uses them.
    readonly property var installedFonts: Qt.fontFamilies()
    function firstFont(names, fallback) {
        for (const name of names)
            if (installedFonts.indexOf(name) >= 0)
                return name;
        return fallback;
    }
    readonly property string font: firstFont(["SF Pro Text", "SF Pro", "SF Pro Display"], "Inter")
    readonly property string fontDisplay: firstFont(["SF Pro Display", "SF Pro", "SF Pro Text"], "Inter Display")
    readonly property int fsClock: px(18)
    readonly property int fsBody: px(16)
    readonly property int fsSmall: px(13)
    readonly property int fsTiny: px(11)

    // ── motion ─────────────────────────────────────────────────────────────
    // Panels glide out and glide back: both curves end slowly, so nothing
    // stops dead or jumps the last bit. Every duration goes through ms() so
    // Config.animationSpeed can speed everything up or switch it off.
    function ms(v) {
        return Config.animationSpeed > 0 ? Math.round(v / Config.animationSpeed) : 0;
    }

    // Everything is deliberately quick: you notice the motion, you never wait for it.
    // The outline: a thin line round the dark buttons, a little lighter than they are
    // (white at 7%: on the island's #0b0b0b about #1b1b1b). The white buttons get none.
    // "No outline buttons" (Config.noButtonOutline, Settings > Appearance) takes it away.
    readonly property int outlineW: Config.buttonOutline ? 1 : 0
    readonly property color outlineColor: Qt.rgba(1, 1, 1, 0.07)
    // ... on the small round buttons (up to about 34 px: the sound / brightness circles, the
    // calendar's arrows, the power menu's circles, the quick note's save button, the clipboard's
    // search button, the Settings app's sidebar icons) thinner and fainter, so it doesn't look
    // heavy next to the bigger ones (white at 5 %, 0.5 px: drawn smoothed, much fainter)
    readonly property real outlineSmallW: Config.buttonOutline ? 0.5 : 0
    readonly property color outlineSmallColor: Qt.rgba(1, 1, 1, 0.05)

    readonly property int durFast: ms(110)       // hover, press, colour changes
    readonly property int durSmall: ms(160)      // fades, small movements
    readonly property int durOpen: ms(400)       // a panel opening or changing size (most of the way in 0.2 s, then it settles)
    readonly property int durClose: ms(250)      // a panel closing
    readonly property int durPop: ms(200)        // the app switcher / launcher growing in
    readonly property int durSheet: ms(300)      // ... out of the island (IslandSheet): fast, straight into place (curveSheet)
    readonly property int durHandOff: ms(60)     // ... the island's clock row stepping aside first
    readonly property int durDockIn: ms(240)     // an app's icon in the dock growing into its place (with a little spring, Theme.curveSpring)
    readonly property int durDockOut: ms(170)    // ... and shrinking away (Theme.curveStandard)
    readonly property int durPopFade: ms(90)     // ... and fading in
    readonly property int hoverClose: ms(40)     // a hover panel starts closing this long after the pointer left (HoverLatch)
    readonly property int durCurtain: ms(10)     // logging out: the screen fading to black (Curtain)
    readonly property int durReveal: ms(600)     // after logging in: the desktop fading in from black (Wallpaper, Overlay)
    readonly property int durWallpaperFade: ms(600)  // a new wallpaper fading in over the old one (Wallpaper): long and even, smooth even between very different colours
    readonly property int durSlide: ms(300)      // the wallpaper switcher sliding: like Hyprland's workspaces (SLIDE_SPEED, "standard" curve in hyprland.lua)
    readonly property int durLock: ms(400)       // the lock screen fading in over the desktop, and out again (Lock)
    readonly property int durShot: ms(200)       // the screenshot screen (Print) fading in over the screen, and out again (Screenshot)
    readonly property int durCover: ms(200)      // the frame fading out / in for F11 on a workspace without tiling (Overlay): like Hyprland's own fade of it for fullscreen ("fadeLayersIn" in hyprland.lua: speed 2, "standard" curve)

    // Bezier control points: [x1, y1, x2, y2, ..., 1, 1]
    readonly property var curveStandard: [0.2, 0, 0, 1, 1, 1]
    readonly property var curveDecel: [0.25, 1, 0.5, 1, 1, 1]          // things arriving / resizing: quick start, long soft landing
    readonly property var curveAccel: [0.4, 0, 0.2, 1, 1, 1]           // things leaving: eases off, then lands softly in the frame
    readonly property var curveSpring: [0.38, 1.21, 0.22, 1, 1, 1]     // small elements, a hint of overshoot
    readonly property var curveSheet: [0.15, 1, 0.3, 1, 1, 1]          // the launcher / switcher out of the island: 90 % there in a third of the time, then a soft landing (no overshoot)
}
