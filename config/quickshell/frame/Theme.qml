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
    readonly property int frame: Math.max(2, px(3))      // dark frame on the left / top / right
    readonly property int bar: px(42)                     // dark bar at the bottom
    readonly property int border: Math.max(0, Config.frameBorder)   // the border, in real pixels (Settings: Appearance)
    readonly property int cornerRadius: Config.cornerRadius

    // Distance from the screen edge to the *inside* of the border. The space
    // Hyprland reserves for windows starts here (plus the window gap,
    // Config.windowGap).
    readonly property int inset: frame + border
    readonly property int insetBottom: bar + border

    // One radius for every corner of the shell, exactly like the concept art:
    // the corners of the window area, the concave "ears" where a panel meets
    // the frame, and the rounded corners of the panels themselves. It is the
    // radius of the outer edge of the border; the inner edge (where windows
    // start) ends up with `cornerRadius`.
    readonly property int windowRadius: cornerRadius + border
    readonly property int earRadius: windowRadius
    readonly property int panelRadius: windowRadius
    // ... but the four corners of the window area itself (the frame round the windows) follow
    // the Settings app's "Corner rounding" (Config.cornerRounding), like the windows' corners
    readonly property int frameCornerRadius: Math.max(0, Config.cornerRounding) + border

    // ── island (notch) ─────────────────────────────────────────────────────
    readonly property int notchW: px(340)
    readonly property int notchH: px(38)
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
    readonly property string font: "Clarity City"
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
    readonly property int durFast: ms(110)       // hover, press, colour changes
    readonly property int durSmall: ms(160)      // fades, small movements
    readonly property int durOpen: ms(400)       // a panel opening or changing size (most of the way in 0.2 s, then it settles)
    readonly property int durClose: ms(250)      // a panel closing
    readonly property int durPop: ms(200)        // the app switcher / launcher growing in
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
}
