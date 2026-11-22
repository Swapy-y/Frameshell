pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ═══════════════════════════════════════════════════════════════════════════
//  Config.qml  -  every setting of the shell lives here.
//
//  Edit a value, save the file, and the shell reloads itself.
//  Sizes are in pixels for a 1080p screen unless a comment says otherwise;
//  the shell scales them to your real screen height automatically.
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: config

    // ── General ────────────────────────────────────────────────────────────

    // UI scale. 0 = automatic (screen height / 1080). Set e.g. 1.25 to force a size.
    property real scale: 0

    // Terminal the launcher uses for apps that need one (Super+Q uses the
    // `terminal` line in hyprland.lua).
    property string terminal: "kitty"

    // Wallpapers, drawn by the shell itself (no hyprpaper needed). Each colour theme
    // has its own: the pictures in its folder of this one, named like the theme without
    // spaces (wallpapers/Default, wallpapers/TokyoNight ...; themeWallpaperDir()).
    // SUPER + CTRL + Left / Right switches between the current theme's pictures (in the order
    // of their file names; add your own there, or in the Settings app). A theme without
    // pictures of its own uses Default's. Each theme starts with its picture in
    // `themeWallpapers` (below; `wallpaper` is Default's) until you pick another. The
    // login and lock screen show the same picture.
    property string wallpaperDir: Quickshell.env("HOME") + "/.local/share/frameshell/wallpapers"
    property string wallpaper: wallpaperDir + "/Default/meadow.png"
    // the folder of a theme's wallpapers (its name without spaces, like its GTK theme's)
    function themeWallpaperDir(name) {
        return wallpaperDir + "/" + String(name).replace(/\s+/g, "");
    }
    // each theme's wallpaper until you pick another for it (a theme not here, or whose
    // picture is gone: its first picture)
    readonly property var themeWallpapers: ({
            "Default": "meadow.png",
            "Noir": "dark-bloom.png",
            "Catppuccin Mocha": "night-clouds.png",
            "Everblush": "everblush-5.png",
            "Everforest": "everforest.png",
            "Rose Pine": "rose-pine2.png",
            "Gruvbox": "gruvbox.png",
            "Kanagawa": "kanagawa.png",
            "Nord": "nord.png",
            "Tokyo Night": "tokyo-night.png"
        })
    function themeWallpaper(name) {
        const f = themeWallpapers[name];
        return f ? themeWallpaperDir(name) + "/" + f : "";
    }

    // ── Look ───────────────────────────────────────────────────────────────

    // Width of the ring round every window (windowBorder: Hyprland's border_size), in
    // REAL pixels (not scaled with the screen), 0 = none. Set it with the slider in the
    // Settings app (Appearance, 0 - 4 px; 2 until you do): it is kept in
    // ~/.local/state/frameshell/appearance.json (below), which Hyprland reads when it
    // starts (hyprland.lua), and the shell hands a change to the windows right away
    // (modules/HyprSync.qml). The frame, the island, the panels and the pop-ups have a
    // fixed 1 px edge (Theme.border).
    property alias windowBorder: appearance.windowBorder

    // The space round every window - to the frame and between two windows (Hyprland's
    // gaps), in screen pixels. Set it with the slider in the Settings app (Appearance,
    // 5 - 20 px): kept in appearance.json too ("windowGap"; -1 until you move it -
    // then WINDOW_GAP at the top of hyprland.lua counts, 15), which Hyprland reads when
    // it starts; the shell hands a change to Hyprland right away (modules/HyprSync.qml).
    readonly property int windowGap: appearance.windowGap >= 0 ? appearance.windowGap : hyprWindowGap
    function setWindowGap(v) {
        appearance.windowGap = Math.max(0, Math.round(v));
    }
    // The rounding of the frame's four corners (round the window area) and of the windows'
    // corners, in screen pixels: the slider in the Settings app (Appearance, "Corner rounding",
    // 20 - 30 px). Kept in appearance.json too ("cornerRounding"; -1 until you move it - then
    // cornerRadius below counts, 30), which Hyprland reads when it starts; the shell hands a
    // change to Hyprland right away (modules/HyprSync.qml). The island, the dock and the panels
    // keep cornerRadius.
    readonly property int cornerRounding: appearance.cornerRounding >= 0 ? appearance.cornerRounding : cornerRadius
    function setCornerRounding(v) {
        appearance.cornerRounding = Math.max(0, Math.round(v));
    }
    // true once appearance.json is read (or found missing): before that the values above are
    // only the defaults
    property bool appearanceRead: false

    // Switches of the Settings app kept in ~/.local/state/frameshell/experimental.json (below) -
    // the Appearance page's (Frame overlay and its cards for the media / sliders and the
    // island's icons), the Island page's (10 workspaces, Island popups), the Dock page's (Clean dock)
    // and the Experimental page's (Click to expand, More window info in app switcher). dynamicPopups is on until you switch it off, the
    // others off until you switch them on:
    //   frameOverlay      "Frame overlay": a dark frame round the left, top and right edges of
    //                     the screen (Theme.frame), the island and the panels growing out of
    //                     it. Off (framelessOutline below): no frame - the wallpaper reaches
    //                     those edges and only the screen's four corners stay rounded off;
    //                     the island moves up into the frame's place and keeps its shape
    //                     (Theme.notchShift), and so do the panels on the left, top and
    //                     right edges (Theme.frameShift). Switched, the frame glides away / back
    //                     (Theme.frameless)
    //   tenWorkspaces     workspaces up to 10: SUPER + Left / Right go on past the 5th, SUPER + 6 ... 9
    //                     and 0 go to 6 ... 10. The island keeps five pills: the 5th, always the
    //                     lighter grey of a workspace without tiling, stands for 5 ... 10 and is
    //                     the big white one on any of them (services/Spaces.qml). hyprland.lua
    //                     reads it when Hyprland starts; the shell hands a change to Hyprland
    //                     right away (modules/HyprSync.qml)
    //   dynamicPopups     the pop-ups (launcher, app switcher, Wi-Fi / Bluetooth card, "Shut
    //                     down?", the password dialog, the emoji picker) grow out of the
    //                     island; off: cards in the middle of the screen (components/IslandSheet.qml)
    //   cleanDock         the bar's power button (bottom left) and date (bottom right) only show
    //                     while the pointer is on their corner (or their panel is open); a click
    //                     opens the power menu / calendar as always (modules/BottomBar.qml)
    //   detailedMedia     the open island's media with the times beside the progress bar, a
    //                     longer bar and bigger buttons (at first: no times) (modules/Island.qml)
    //   flatSliders       the sliders' filled part square at its right end (at first it is
    //                     round at both ends) (components/FSlider.qml)
    //   detailedBattery   the island's battery with a gap inside its outline and the charge as
    //                     a bar in it (at first: no gap, the charge fills the outline)
    //                     (components/BatteryIcon.qml)
    //   minimalSliders    the sound / brightness block (top left) without the round icons on
    //                     the left: just the names, values and sliders (modules/SliderPanel.qml)
    //   glowingIcons      the white parts of the closed island (the workspace you are on,
    //                     signal + battery) softly glow (modules/Island.qml, NotchGlow)
    //   noButtonOutline   "No outline buttons" (the Appearance page): without the thin, slightly
    //                     lighter outline round the dark buttons and fields (buttonOutline
    //                     below is the other way round; Theme.outlineW / outlineColor)
    //   clickToExpand     "Click to expand" (the Experimental page): the blocks that come out
    //                     when the pointer touches them - the island, the sound / brightness
    //                     block, the quick note, the clipboard, the colour picker - only peek out
    //                     a little; a click on one opens it all the way, until the pointer leaves
    //                     it (components/Panel.qml, modules/Island.qml). Not the dock (auto hide)
    //                     and its pieces: the corner blocks of notch mode, Clean dock's buttons
    //   switcherWindowInfo "More window info in app switcher" (the Experimental page): each row of
    //                     the app switcher shows its window's title in smaller text under the app
    //                     name (Firefox: the tab you are on), so two windows of one app can be
    //                     told apart (modules/Switcher.qml, components/AppRow.qml)
    property alias frameOverlay: experimental.frameOverlay
    readonly property bool framelessOutline: !frameOverlay        // no frame (what the shapes go by)
    property alias tenWorkspaces: experimental.tenWorkspaces
    property alias dynamicPopups: experimental.dynamicPopups
    property alias cleanDock: experimental.cleanDock
    property alias detailedMedia: experimental.detailedMedia
    property alias flatSliders: experimental.flatSliders
    property alias detailedBattery: experimental.detailedBattery
    property alias minimalSliders: experimental.minimalSliders
    property alias glowingIcons: experimental.glowingIcons
    property alias noButtonOutline: experimental.noButtonOutline
    property alias clickToExpand: experimental.clickToExpand
    property alias switcherWindowInfo: experimental.switcherWindowInfo
    readonly property bool buttonOutline: !noButtonOutline        // the outline is drawn
    // true once experimental.json is read (or found missing)
    property bool experimentalRead: false

    // The focus and the pointer (the Settings app's Devices page, Mouse; kept in
    // ~/.local/state/frameshell/system.json, below, which Hyprland reads when it
    // starts, hyprland.lua; the shell hands a change to Hyprland right away,
    // modules/HyprSync.qml):
    //   focusFollowsMouse   true: the window under the pointer gets the focus, no
    //                       click needed (Hyprland's input:follow_mouse 1; false: 2,
    //                       a click focuses)
    //   cursorFollowsFocus  true: focusing a window with the keys moves the pointer
    //                       to it (false: Hyprland's cursor:no_warps)
    property alias focusFollowsMouse: system.focusFollowsMouse
    property alias cursorFollowsFocus: system.cursorFollowsFocus

    // Blur (the Settings app's Blur page; kept in ~/.local/state/frameshell/blur.json,
    // below, which Hyprland reads when it starts, hyprland.lua; the shell hands a
    // change to Hyprland right away, modules/HyprSync.qml):
    //   windowBlur      Hyprland blurs what is behind see-through windows (it makes
    //                   no window see-through itself: e.g. kitty's background_opacity)
    //   blurSize, blurPasses, blurBrightness, blurContrast   Hyprland's blur
    property alias windowBlur: blur.windowBlur
    property alias blurSize: blur.blurSize
    property alias blurPasses: blur.blurPasses
    property alias blurBrightness: blur.blurBrightness
    property alias blurContrast: blur.blurContrast
    // how solid the shell's surfaces are: always 1 - the shell is never see-through
    // (there was an "Apply blur to shell" setting; what still reads this keeps working)
    readonly property real shellAlpha: 1

    // The keyboard, the mouse and the touchpad (the Settings app's Devices page; kept in
    // ~/.local/state/frameshell/input.json, below, which Hyprland reads when it starts,
    // the INPUT section of hyprland.lua; the shell hands a change to Hyprland right away,
    // modules/HyprSync.qml). One not set there yet is the one hyprland.lua starts with:
    // the last value of its line  shell_state("input.json", "<name>", <value>)  (read below).
    //   repeatDelay          a held key repeats after this many ms ...
    //   repeatRate           ... this many times a second
    //   numlock              Num Lock is on when you log in
    //   mouseSpeed           -1 ... 1 (0: the mouse's own speed; -0.75 by default)
    //   mouseAccel           the pointer goes further the faster you move the mouse: Hyprland's
    //                        accel_profile "adaptive" (the default); off = "flat" (kept as
    //                        "mouseAcceleration" - a value saved as "mouseAccel" is not read)
    //   mouseScrollSpeed     0.1 ... 2 (1: as the mouse sends it)
    //   mouseNaturalScroll   the content follows the wheel, like on a phone
    //   touchpadTap, touchpadNaturalScroll, touchpadTyping (off while you type),
    //   touchpadScrollSpeed  the same for a touchpad
    property alias repeatDelay: input.repeatDelay
    property alias repeatRate: input.repeatRate
    property alias numlock: input.numlock
    property alias mouseSpeed: input.mouseSpeed
    property alias mouseAccel: input.mouseAcceleration
    property alias mouseScrollSpeed: input.mouseScrollSpeed
    property alias mouseNaturalScroll: input.mouseNaturalScroll
    property alias touchpadTap: input.touchpadTap
    property alias touchpadNaturalScroll: input.touchpadNaturalScroll
    property alias touchpadTyping: input.touchpadTyping
    property alias touchpadScrollSpeed: input.touchpadScrollSpeed

    // Corner radius of the window area, in REAL pixels (not scaled). Every other
    // corner of the shell (panels, the notch, the "ears" where a panel meets the
    // frame) is derived from it, plus the border width, so everything matches.
    // 30 is tuned for a 4K screen like the concept art; use about 13 on 1080p.
    // The frame's four corners and the windows' corners follow it too until the
    // Settings app's "Corner rounding" slider is moved (cornerRounding above).
    property int cornerRadius: 30

    // Soft shadow around the frame, the island, the panels and the pop-ups
    // (app switcher, launcher), and under every window (Hyprland draws that
    // one; its size and darkness factors are SHADOW_* in hyprland.lua). Turn
    // it off if your GPU is very weak. Both settings apply to the windows
    // right away when you save.
    property bool shadows: true
    property real shadowStrength: 0.6       // 0 = invisible ... 1 = strong

    // ── Animations ─────────────────────────────────────────────────────────

    // 1 = normal, 2 = twice as fast, 0.5 = twice as slow, 0 = no animations.
    property real animationSpeed: 1

    // ── Clock ──────────────────────────────────────────────────────────────

    property bool clock24h: false           // false: 1:23   true: 13:23

    // ── Island (the notch at the top) ──────────────────────────────────────

    // true  = windows start *below* the notch, so it never covers a title bar.
    // false = windows may slide under the notch.
    // (Auto hide for the island and the dock is in the Settings app: SUPER + R,
    // "Settings". Hidden, they are not reserved at all - they come out over windows.)
    property bool reserveNotch: true

    // Most networks / Bluetooth devices the list under the island shows before
    // it scrolls (the Wi-Fi and Bluetooth buttons open it).
    property int netMaxRows: 6

    // ── Workspaces (the pills in the island) ───────────────────────────────

    // Pills that are always shown. When you open a window on the last one the
    // next pill appears; pills above this number disappear again when empty.
    property int workspaceCount: 4

    // The last workspace: the "next" pill is only created up to this one, and
    // Super+1 … Super+5, Super+Left / Right and the other workspace keys stop here
    // (hyprland.lua reads this number too; up to 10, Super+0 = 10).
    property int workspaceMax: 5

    // ── Bottom bar ─────────────────────────────────────────────────────────

    property bool plainSquares: false       // true = white placeholder squares like the concept art

    // Size of the app icons in the bottom bar, in 1080p pixels (scaled with the
    // screen like the rest of the shell: 30 = 60 real pixels on 4K). The old
    // size was 22; up to 34 fits the bar.
    property int dockIconSize: 30

    // ── App switcher (Super+Space) and app launcher (Super+R) ──────────────

    // Size of the app switcher and the launcher (rows, text, icons, width):
    // 1 = their normal size, 0.8 = 20 % smaller, 1.2 = 20 % bigger.
    property real popupScale: 1

    // Rows shown before the list becomes scrollable. Fewer apps = a smaller panel.
    property int switcherMaxRows: 6
    property int launcherMaxRows: 8

    // ── Notifications ──────────────────────────────────────────────────────

    property bool startWithNotificationsOn: false   // the concept starts on "Do not disturb"
    property int notificationTimeout: 6000          // ms, when the app does not ask for one

    // ── Quick note ─────────────────────────────────────────────────────────

    property real noteMaxHeightFraction: 0.6        // tallest the note (and the clipboard) get, as a fraction of the screen
    property int scrollStep: 100                    // px one mouse-wheel notch scrolls the note and the clipboard (Qt's normal: 72)

    // ── Clipboard (hover the middle of the left edge) ──────────────────────

    property int clipboardMaxItems: 50              // newest entries shown (cliphist keeps up to 750)

    // ── Colour picker (hover the top-right corner) ─────────────────────────

    // A small block pops out of the corner; click it to pick a colour anywhere
    // on the screen (hyprpicker): the hex code is copied. It does not come out
    // while a notification is on screen. false = no colour picker block.
    property bool colorPicker: true

    // ── Lock screen (Super+Escape, "Lock" in the power menu, after 5 min idle) ──

    // The lock screen is the Pixie login screen, drawn by the shell. It takes
    // the wallpaper and fonts from this SDDM theme folder (install.sh puts Pixie
    // there) and, like the login screen, the login colours - the same in every
    // colour theme (loginCard ... below: the shell writes them into the
    // folder's theme.conf.user, which wins over its theme.conf). Without the
    // folder: the desktop wallpaper and those colours.
    property string lockTheme: "/usr/share/sddm/themes/pixie"

    // Suspend / restart / shut down buttons at the top right, like Pixie.
    // false = hide them, so nobody can turn the computer off while it is locked.
    property bool lockPowerButtons: true

    // ── Colours ────────────────────────────────────────────────────────────
    // The colour themes. SUPER + CTRL + Up / Down opens the theme switcher in the island
    // and goes through them in this order (Up = the next one, to the right);
    // Enter uses the one in the middle (Esc: no change). Your
    // pick is kept in ~/.local/state/frameshell/theme.
    // Every colour the shell draws with is here; Default's entry says what each one
    // is for (in groups: surfaces, text, icons and controls, windows, status). The
    // screenshot screen (Print) is in Noir's colours in every theme, unless "Follow
    // theme" is on (the Settings app's Screenshot page: modules/Screenshot.qml).
    // Change a theme's colours, or add a theme: a name and the
    // colours it changes - a colour it leaves out is Default's. The frame, the island,
    // the bar and the panels that slide out of them take only `text`, `notificationText` and `sliderFill`
    // from a theme: the rest of their colours are the same in every theme (frameBase,
    // below the themes).
    // GTK and Qt apps switch along (scripts/theme.sh): Default uses the GTK theme
    // Frame and the Kvantum theme Frame, the others Frame-<name> / Frame<name>
    // (made by themes/make-themes.py and themes/Kvantum/make-frame.py in the
    // frameshell folder; a theme of your own without them uses Default's).
    readonly property var themes: [
        {
            name: "Default",
            // surfaces
            background: "#1a1a1a",            // the Settings app's window, and the pop-ups and panels drawn in the theme's colours; the dark text on white buttons
            cardBackground: "#222222",        // the Settings app's cards and search field; a row or button under the pointer
            controlBackground: "#2a2a2a",     // buttons (Cancel, Done ...), text fields, round icons, a switch when off, a selected row
            controlHover: "#313131",          // a button under the pointer
            controlDisabled: "#3a3a3a",       // a button that cannot be used yet (Wi-Fi's Join before a password is typed)
            border: "#313131",                // the edge of the frame's shapes, the on-screen keyboard and the screenshot screen's menu (with Follow theme); the big icon on a Settings page
            divider: "#313131",               // the thin lines between rows (the power menu, the calendar's weekdays, the emoji picker)
            // text
            text: "#ffffff",                  // text and icons
            textSecondary: "#8c8c8c",         // the second line: descriptions, values, "Connected", the date
            textTertiary: "#575757",          // the faintest text: placeholders ("Search"), days outside the month, buttons you cannot use
            selectionBackground: "#3e3e3e",   // selected text in the shell's text fields (kitty, GTK and Qt apps use the same)
            notificationText: "#e8e8e8",      // the text of a notification
            fieldFocusBorder: "#4a4a4a",      // the outline of a password or name field while you type in it
            // icons and controls
            inactive: "#494949",              // the unlit parts: empty battery, unlit Wi-Fi / signal bars, slider tracks, switches when off
            sliderFill: "#ffffff",            // the filled part of the sliders (volume, brightness, the island's progress bar)
            scrollbar: "#3a3a3a",             // the thin scroll bars (the Settings app, the Wi-Fi / Bluetooth lists)
            appIconFallback: "#ffffff",       // the tile drawn for an app that has no icon
            colorPickerIcon: "#d6d6d6",       // the colour picker's icon (`text` under the pointer)
            workspaceUntiled: "#696969",      // the island's pill of a workspace with tiling off (SUPER + PageDown)
            dockSeparator: "#494949",         // the line in the dock between the pinned apps and the other open apps
            previewSelectedBorder: "#ffffff", // the ring round the picture in the middle of the wallpaper / theme switchers, and round the preset in use
            // windows (Hyprland's borders)
            windowBorderActive: "#c4c4c4",    // the focused window (also a dot on the theme's card, and the line round the screenshot's area with Follow theme)
            windowBorderInactive: "#313131",  // the other windows (also the outline of the side pictures in the switchers)
            // status
            batteryCharging: "#ffb454",       // the battery while charging
            warning: "#ff6b6b"                // the battery below 15 %, a wrong password, errors, Shut down in the power menu
        },
        {
            name: "Noir",
            background: "#000000",
            cardBackground: "#060606",
            controlBackground: "#060606",
            controlHover: "#0c0c0c",
            controlDisabled: "#3a3a3a",
            border: "#000000",
            divider: "#060606",
            text: "#ffffff",
            textSecondary: "#8c8c8c",
            textTertiary: "#575757",
            selectionBackground: "#222222",
            notificationText: "#e8e8e8",
            fieldFocusBorder: "#4a4a4a",
            inactive: "#1a1a1a",
            sliderFill: "#ffffff",
            scrollbar: "#3a3a3a",
            appIconFallback: "#ffffff",
            colorPickerIcon: "#d6d6d6",
            workspaceUntiled: "#3a3a3a",
            dockSeparator: "#3a3a3a",
            previewSelectedBorder: "#ffffff",
            windowBorderActive: "#7d7d7d",
            windowBorderInactive: "#060606",
            batteryCharging: "#ffb454",
            warning: "#ff6b6b"
        },
        {
            name: "Catppuccin Mocha",
            background: "#1e1e2e",
            cardBackground: "#262637",
            controlBackground: "#2d2e3f",
            controlHover: "#343546",
            controlDisabled: "#3c3e50",
            border: "#343546",
            divider: "#343546",
            text: "#cdd6f4",
            textSecondary: "#8b90a9",
            textTertiary: "#585b6f",
            selectionBackground: "#45475a",
            notificationText: "#bcc4e0",
            fieldFocusBorder: "#4b4e61",
            inactive: "#4a4d60",
            sliderFill: "#89b4fa",
            scrollbar: "#3c3e50",
            appIconFallback: "#cdd6f4",
            colorPickerIcon: "#aeb5d0",
            workspaceUntiled: "#686c82",
            dockSeparator: "#4a4d60",
            previewSelectedBorder: "#89b4fa",
            windowBorderActive: "#cba6f7",
            windowBorderInactive: "#343546",
            batteryCharging: "#f9e2af",
            warning: "#f38ba8"
        },
        {
            name: "Everblush",
            background: "#141b1e",
            cardBackground: "#1c2326",
            controlBackground: "#232a2d",
            controlHover: "#2b3235",
            controlDisabled: "#343b3e",
            border: "#2b3235",
            divider: "#2b3235",
            text: "#dadada",
            textSecondary: "#8a8d8e",
            textTertiary: "#54595b",
            selectionBackground: "#383f42",
            notificationText: "#c6c7c7",
            fieldFocusBorder: "#444b4e",
            inactive: "#434a4d",
            sliderFill: "#67b0e8",
            scrollbar: "#343b3e",
            appIconFallback: "#dadada",
            colorPickerIcon: "#b6b8b8",
            workspaceUntiled: "#65696b",
            dockSeparator: "#434a4d",
            previewSelectedBorder: "#67b0e8",
            windowBorderActive: "#6cbfbf",
            windowBorderInactive: "#2b3235",
            batteryCharging: "#e5c76b",
            warning: "#e57474"
        },
        {
            name: "Everforest",
            background: "#2d353b",
            cardBackground: "#343e43",
            controlBackground: "#3b464b",
            controlHover: "#424e52",
            controlDisabled: "#4a575c",
            border: "#424e52",
            divider: "#424e52",
            text: "#d3c6aa",
            textSecondary: "#a39d8a",
            textTertiary: "#6f6f67",
            selectionBackground: "#4e5c60",
            notificationText: "#c2b89f",
            fieldFocusBorder: "#58696c",
            inactive: "#58686b",
            sliderFill: "#7fbbb3",
            scrollbar: "#4a575c",
            appIconFallback: "#d3c6aa",
            colorPickerIcon: "#b5ac96",
            workspaceUntiled: "#8a8679",
            dockSeparator: "#58686b",
            previewSelectedBorder: "#7fbbb3",
            windowBorderActive: "#7fbbb3",
            windowBorderInactive: "#424e52",
            batteryCharging: "#dbbc7f",
            warning: "#e67e80"
        },
        {
            name: "Rose Pine",
            background: "#191724",
            cardBackground: "#211e2d",
            controlBackground: "#282636",
            controlHover: "#2f2c3e",
            controlDisabled: "#373548",
            border: "#2f2c3e",
            divider: "#2f2c3e",
            text: "#e0def4",
            textSecondary: "#8c8a9c",
            textTertiary: "#585665",
            selectionBackground: "#403d52",
            notificationText: "#cccadf",
            fieldFocusBorder: "#47435a",
            inactive: "#464359",
            sliderFill: "#ebbcba",
            scrollbar: "#373548",
            appIconFallback: "#e0def4",
            colorPickerIcon: "#bcbacf",
            workspaceUntiled: "#676575",
            dockSeparator: "#464359",
            previewSelectedBorder: "#ebbcba",
            windowBorderActive: "#ebbcba",
            windowBorderInactive: "#2f2c3e",
            batteryCharging: "#f6c177",
            warning: "#eb6f92"
        },
        {
            name: "Gruvbox",
            background: "#282828",
            cardBackground: "#31302f",
            controlBackground: "#3b3836",
            controlHover: "#433e3c",
            controlDisabled: "#4e4743",
            border: "#433e3c",
            divider: "#433e3c",
            text: "#d4be98",
            textSecondary: "#a6967a",
            textTertiary: "#6b6253",
            selectionBackground: "#504945",
            notificationText: "#c3af8d",
            fieldFocusBorder: "#605751",
            inactive: "#5f5650",
            sliderFill: "#7daea3",
            scrollbar: "#4e4743",
            appIconFallback: "#d4be98",
            colorPickerIcon: "#b5a384",
            workspaceUntiled: "#867a65",
            dockSeparator: "#5f5650",
            previewSelectedBorder: "#7daea3",
            windowBorderActive: "#7daea3",
            windowBorderInactive: "#433e3c",
            batteryCharging: "#d8a657",
            warning: "#ea6962"
        },
        {
            name: "Kanagawa",
            background: "#1f1f28",
            cardBackground: "#262631",
            controlBackground: "#2e2e3b",
            controlHover: "#343443",
            controlDisabled: "#3c3c4e",
            border: "#343443",
            divider: "#343443",
            text: "#dcd7ba",
            textSecondary: "#959283",
            textTertiary: "#5e5c59",
            selectionBackground: "#404053",
            notificationText: "#c9c5ab",
            fieldFocusBorder: "#4b4b61",
            inactive: "#4a4a60",
            sliderFill: "#dcd7ba",
            scrollbar: "#3c3c4e",
            appIconFallback: "#dcd7ba",
            colorPickerIcon: "#bab6a0",
            workspaceUntiled: "#75736b",
            dockSeparator: "#4a4a60",
            previewSelectedBorder: "#dcd7ba",
            windowBorderActive: "#dcd7ba",
            windowBorderInactive: "#343443",
            batteryCharging: "#e6c384",
            warning: "#e82424"
        },
        {
            name: "Nord",
            background: "#2e3440",
            cardBackground: "#353c4a",
            controlBackground: "#3b4353",
            controlHover: "#414a5c",
            controlDisabled: "#495366",
            border: "#414a5c",
            divider: "#414a5c",
            text: "#d8dee9",
            textSecondary: "#a2a8b3",
            textTertiary: "#696f7a",
            selectionBackground: "#4c576b",
            notificationText: "#c7cdd8",
            fieldFocusBorder: "#56627a",
            inactive: "#556178",
            sliderFill: "#81a1c1",
            scrollbar: "#495366",
            appIconFallback: "#d8dee9",
            colorPickerIcon: "#b9bfcb",
            workspaceUntiled: "#7d838f",
            dockSeparator: "#556178",
            previewSelectedBorder: "#81a1c1",
            windowBorderActive: "#81a1c1",
            windowBorderInactive: "#414a5c",
            batteryCharging: "#ebcb8b",
            warning: "#bf616a"
        },
        {
            name: "Tokyo Night",
            background: "#1a1b26",
            cardBackground: "#202231",
            controlBackground: "#262a3c",
            controlHover: "#2b3045",
            controlDisabled: "#313851",
            border: "#2b3045",
            divider: "#2b3045",
            text: "#c0caf5",
            textSecondary: "#868dac",
            textTertiary: "#54596f",
            selectionBackground: "#343c57",
            notificationText: "#a9b1d6",
            fieldFocusBorder: "#3d4767",
            inactive: "#3c4666",
            sliderFill: "#7aa2f7",
            scrollbar: "#313851",
            appIconFallback: "#c0caf5",
            colorPickerIcon: "#a2aad0",
            workspaceUntiled: "#626780",
            dockSeparator: "#3c4666",
            previewSelectedBorder: "#7aa2f7",
            windowBorderActive: "#7aa2f7",
            windowBorderInactive: "#2b3045",
            batteryCharging: "#ff9e64",
            warning: "#f7768e"
        }
    ]

    // the theme in use: the one picked in the switcher (services/Themes.qml sets
    // it, scripts/theme.sh keeps it), else the first one
    property string themeName: ""
    // ("Mocha", the theme of earlier versions, is Catppuccin Mocha now)
    readonly property var theme: themes.find(t => t.name === (themeName === "Mocha" ? "Catppuccin Mocha" : themeName)) || themes[0]

    // a colour of a theme (an entry of `themes`); one it does not set is Default's
    function themeColor(t, key) {
        return t && t[key] !== undefined ? t[key] : themes[0][key];
    }

    readonly property color background: themeColor(theme, "background")
    // the fill of a pop-up card (switcher, launcher ...): the same as background
    // (shellAlpha is always 1 now)
    readonly property color surface: Qt.rgba(background.r, background.g, background.b, shellAlpha)
    readonly property color border: themeColor(theme, "border")
    readonly property color divider: themeColor(theme, "divider")
    readonly property color controlBackground: themeColor(theme, "controlBackground")
    readonly property color cardBackground: themeColor(theme, "cardBackground")
    readonly property color controlHover: themeColor(theme, "controlHover")
    readonly property color controlDisabled: themeColor(theme, "controlDisabled")
    readonly property color text: themeColor(theme, "text")
    readonly property color textSecondary: themeColor(theme, "textSecondary")
    readonly property color textTertiary: themeColor(theme, "textTertiary")
    readonly property color selectionBackground: themeColor(theme, "selectionBackground")
    readonly property color notificationText: themeColor(theme, "notificationText")
    readonly property color fieldFocusBorder: themeColor(theme, "fieldFocusBorder")
    readonly property color inactive: themeColor(theme, "inactive")
    readonly property color workspaceUntiled: themeColor(theme, "workspaceUntiled")
    readonly property color dockSeparator: themeColor(theme, "dockSeparator")
    readonly property color appIconFallback: themeColor(theme, "appIconFallback")
    readonly property color colorPickerIcon: themeColor(theme, "colorPickerIcon")
    readonly property color sliderFill: themeColor(theme, "sliderFill")
    readonly property color scrollbar: themeColor(theme, "scrollbar")
    readonly property color previewSelectedBorder: themeColor(theme, "previewSelectedBorder")
    // the window borders: hyprland.lua reads them from here when Hyprland starts, the shell hands
    // them to Hyprland when the theme changes (modules/HyprSync.qml)
    readonly property color windowBorderActive: themeColor(theme, "windowBorderActive")
    readonly property color windowBorderInactive: themeColor(theme, "windowBorderInactive")
    readonly property color batteryCharging: themeColor(theme, "batteryCharging")
    readonly property color warning: themeColor(theme, "warning")
    // the login screen (SDDM, Pixie) and the lock screen: the same in every colour theme
    // (Noir's); the shell writes them into the Pixie folder's theme.conf.user
    readonly property color loginCard: "#000000"            // the card (the password field: a little lighter)
    readonly property color loginText: "#ffffff"            // its text
    readonly property color loginAccent: "#ffffff"          // the avatar letter, the session icon
    readonly property color loginClockHours: "#ffffff"      // the clock's hours
    readonly property color loginClockMinutes: "#ffffff"    // the clock's minutes
    readonly property color loginCornerText: "#c4c4c4"      // the date and the power icons and labels in the top corners
    readonly property color loginField: "#060606"           // the password field's border and the round button
    readonly property color loginButtonArrow: "#ffffff"     // the arrow on the round button
    readonly property color loginErrorCard: "#0e0606"       // the card after a wrong password (it shakes)

    // ── the frame's colours ──────────────────────────────────────────────
    // The frame, the island, the bar and the panels that slide out of them (Overlay.qml:
    // the quick note, the clipboard, the sliders, the notifications, the power menu, the
    // calendar ...) are one colour in every theme: #000000, their edge too (no border of
    // another colour). In them #060606 is the buttons, fields and rows (and the thin lines)
    // and #1a1a1a the unlit parts of icons - Noir's. Only their text and icons (`text`), a
    // notification's text (`notificationText`) and the sliders (`sliderFill`) follow the theme. So do the launcher and the app switcher,
    // which grow out of the island (components/IslandSheet.qml). Everything else - the
    // Settings app, the pop-ups - keeps the theme's colours. The keys are the themes' (see
    // Default's comments).
    readonly property var frameBase: ({
            background: "#000000",
            border: "#000000",                // the same: the overlay is all one colour
            divider: "#060606",
            controlBackground: "#060606",
            cardBackground: "#060606",
            controlHover: "#0c0c0c",
            controlDisabled: "#3a3a3a",
            textSecondary: "#8c8c8c",
            textTertiary: "#575757",
            selectionBackground: "#222222",
            notificationText: "#e8e8e8",
            fieldFocusBorder: "#4a4a4a",
            inactive: "#1a1a1a",
            workspaceUntiled: "#3a3a3a",
            dockSeparator: "#3a3a3a",
            appIconFallback: "#ffffff",
            colorPickerIcon: "#d6d6d6",
            sliderFill: "#ffffff",
            scrollbar: "#3a3a3a",
            previewSelectedBorder: "#ffffff",
            windowBorderInactive: "#060606",
            batteryCharging: "#ffb454",
            warning: "#ff6b6b"
        })
    // the frame's colours: those, and the theme's text, notification text and slider colour
    readonly property var frameColors: Object.assign({}, frameBase, {
        text: themeColor(theme, "text"),
        notificationText: themeColor(theme, "notificationText"),   // a notification's text follows the theme like its title
        sliderFill: themeColor(theme, "sliderFill")       // the sliders' filled part follows the theme too
    })
    // the same colours of the theme in use (for the pieces that are in both: components/)
    readonly property var themeColors: {
        const o = {};
        for (const k in frameBase)
            o[k] = themeColor(theme, k);
        o.text = themeColor(theme, "text");
        return o;
    }
    // the colours for something in `window`: the frame's in the frame (Overlay.qml's window
    // says so: framePalette), the theme's anywhere else - components/ use it as
    //    readonly property var pal: Config.paletteFor(QsWindow.window)
    // the cards in the middle of the screen (Wi-Fi / Bluetooth, "Shut down?", the password
    // dialog, the emoji picker) are black like the frame, in every theme: their fill, see-through
    // with the shell's blur like Config.surface
    readonly property color frameSurface: Qt.rgba(0, 0, 0, shellAlpha)

    function paletteFor(window) {
        return window && window.framePalette === true ? frameColors : themeColors;
    }

    // the theme you picked, read before anything is drawn (no flash of the first
    // theme at start); `themeRead` once it is known
    property bool themeRead: false
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/frameshell/theme"
        printErrors: false
        blockLoading: true
        onLoaded: {
            themeName = text().trim();
            themeRead = true;
        }
        onLoadFailed: themeRead = true
    }

    // While holdWrites is true a change to appearance.json or blur.json is not written at once:
    // a preset sets several of them in one go (services/Presets.qml), then calls writeSettings().
    // A FileView writes in the background and, when a write is still going as the next one
    // starts, reads what the first one wrote back into its adapter - so a second change made in
    // the same moment would undo the one before it.
    property bool holdWrites: false
    function writeSettings() {
        appearanceFile.writeAdapter();
        blurFile.writeAdapter();
    }

    // the window border, the window gap and the corner rounding of the Settings app
    // (Appearance): windowBorder / windowGap / cornerRounding above
    FileView {
        id: appearanceFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/frameshell/appearance.json"
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onAdapterUpdated: {
            if (!config.holdWrites)
                writeAdapter();
        }
        onLoaded: config.appearanceRead = true
        onLoadFailed: config.appearanceRead = true

        adapter: JsonAdapter {
            id: appearance
            property int windowBorder: 2
            property int windowGap: -1
            property int cornerRounding: -1
        }
    }

    // the switches above (Appearance, Island, Dock): frameOverlay /
    // tenWorkspaces ... above
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/frameshell/experimental.json"
        printErrors: false
        // read before anything is drawn: the frame and the notch never change shape at start
        blockLoading: true
        atomicWrites: true
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            // the switch used to be the other way round ("Frameless overlay", on at first):
            // switched off back then, the frame is kept - once (framelessOutline is then put
            // back to its old default, so it never does it again)
            if (!experimental.framelessOutline) {
                experimental.framelessOutline = true;
                experimental.frameOverlay = true;
            }
            config.experimentalRead = true;
        }
        onLoadFailed: config.experimentalRead = true

        adapter: JsonAdapter {
            id: experimental
            property bool frameOverlay: false
            property bool framelessOutline: true        // only read: the old switch (onLoaded)
            property bool tenWorkspaces: false
            property bool dynamicPopups: true
            property bool cleanDock: false
            property bool detailedMedia: false
            property bool flatSliders: false
            property bool detailedBattery: false
            property bool minimalSliders: false
            property bool glowingIcons: false
            property bool noButtonOutline: false
            property bool clickToExpand: false
            property bool switcherWindowInfo: false
        }
    }

    // the focus settings of the Settings app (Devices, Mouse): focusFollowsMouse / cursorFollowsFocus above
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/frameshell/system.json"
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: system
            property bool focusFollowsMouse: false
            property bool cursorFollowsFocus: true
        }
    }

    // the keyboard, mouse and touchpad of the Settings app (Devices): repeatDelay ... above.
    // What hyprland.lua starts with: the last value of its  shell_state("input.json", ...)  lines.
    FileView {
        id: hyprLua
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/hyprland.lua"
        printErrors: false
        blockLoading: true
    }
    // WINDOW_GAP there: the window gap while its slider was never moved (windowGap above)
    readonly property int hyprWindowGap: {
        const m = (hyprLua.text() || "").match(/\n\s*local\s+WINDOW_GAP\s*=\s*([0-9.]+)/);
        const v = m ? Math.round(parseFloat(m[1])) : NaN;
        return isNaN(v) ? 15 : v;
    }
    function luaInput(name, fallback) {
        const m = (hyprLua.text() || "").match(new RegExp('shell_state\\(\\s*"input\\.json"\\s*,\\s*"' + name + '"\\s*,\\s*("[^"]*"|-?[0-9.]+|true|false)\\s*\\)'));
        if (!m)
            return fallback;
        const raw = m[1];
        if (raw.charAt(0) === '"')
            return typeof fallback === "string" ? raw.slice(1, -1) : fallback;
        if (raw === "true" || raw === "false")
            return typeof fallback === "boolean" ? raw === "true" : fallback;
        const v = parseFloat(raw);
        return typeof fallback === "number" && !isNaN(v) ? v : fallback;
    }
    // Once (settingsVersion 4): the mouse speed -0.75 where it is still the old default
    // (-0.6, version 3); from before version 3 (version 2 had set acceleration off and the
    // speed to 0): acceleration on and -0.75.
    // Saved in one go: a save that starts while another one is running first reads that
    // one back in, which would undo the changes made in between.
    property bool inputHold: false
    function updateInput() {
        if (input.settingsVersion >= 4)
            return;
        inputHold = true;
        if (input.settingsVersion < 3) {
            input.mouseAcceleration = true;
            input.mouseSpeed = -0.75;
        } else if (Math.abs(input.mouseSpeed + 0.6) < 0.001) {
            input.mouseSpeed = -0.75;
        }
        input.settingsVersion = 4;
        inputHold = false;
        inputFile.writeAdapter();
    }
    FileView {
        id: inputFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/frameshell/input.json"
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onAdapterUpdated: {
            if (!config.inputHold)
                writeAdapter();
        }
        onLoaded: config.updateInput()
        onLoadFailed: config.updateInput()      // no file yet

        adapter: JsonAdapter {
            id: input
            property int settingsVersion: 0
            property int repeatDelay: config.luaInput("repeatDelay", 300)
            property int repeatRate: config.luaInput("repeatRate", 35)
            property bool numlock: config.luaInput("numlock", true)
            property real mouseSpeed: config.luaInput("mouseSpeed", -0.75)
            property bool mouseAcceleration: config.luaInput("mouseAcceleration", true)
            property real mouseScrollSpeed: config.luaInput("mouseScrollSpeed", 1.0)
            property bool mouseNaturalScroll: config.luaInput("mouseNaturalScroll", false)
            property bool touchpadTap: config.luaInput("touchpadTap", true)
            property bool touchpadNaturalScroll: config.luaInput("touchpadNaturalScroll", false)
            property bool touchpadTyping: config.luaInput("touchpadTyping", true)
            property real touchpadScrollSpeed: config.luaInput("touchpadScrollSpeed", 1.0)
        }
    }

    // the blur of the Settings app (Blur): windowBlur ... blurContrast above
    FileView {
        id: blurFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/frameshell/blur.json"
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onAdapterUpdated: {
            if (!config.holdWrites)
                writeAdapter();
        }

        adapter: JsonAdapter {
            id: blur
            property bool windowBlur: true
            property int blurSize: 7
            property int blurPasses: 2
            property real blurBrightness: 1.0
            property real blurContrast: 0.9
        }
    }
}
