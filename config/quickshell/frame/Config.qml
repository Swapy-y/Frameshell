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

    // Wallpapers, drawn by the shell itself (no hyprpaper needed). SUPER + CTRL + Left /
    // Right switches between the pictures in this folder (in the order of their
    // file names; add your own there). `wallpaper` is the one used until you pick
    // another. The login and lock screen show the same picture.
    property string wallpaperDir: Quickshell.env("HOME") + "/.local/share/frameshell/wallpapers"
    property string wallpaper: wallpaperDir + "/meadow.png"

    // ── Look ───────────────────────────────────────────────────────────────

    // Width of the border round the frame, the island, the panels and the pop-ups
    // (frameBorder), and of the ring round every window (windowBorder: Hyprland's
    // border_size), in REAL pixels (not scaled with the screen), 0 = none. Set them
    // with the sliders in the Settings app (Appearance, 0 - 4 px; 2 until you do):
    // they are kept in ~/.local/state/frameshell/appearance.json (below), which
    // Hyprland reads when it starts (hyprland.lua), and the shell hands a change to
    // the windows right away (modules/HyprSync.qml).
    property alias frameBorder: appearance.frameBorder
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
    //   shellBlur       the frame, the island, the panels and the pop-ups become
    //                   see-through (shellOpacity) with a blur behind them; their
    //                   text and icons stay solid
    //   blurSize, blurPasses, blurBrightness, blurContrast   Hyprland's blur, for both
    property alias windowBlur: blur.windowBlur
    property alias shellBlur: blur.shellBlur
    property alias blurSize: blur.blurSize
    property alias blurPasses: blur.blurPasses
    property alias blurBrightness: blur.blurBrightness
    property alias blurContrast: blur.blurContrast
    property alias shellOpacity: blur.shellOpacity
    // how solid the shell's surfaces are now: 1 without the shell's blur
    readonly property real shellAlpha: shellBlur ? Math.max(0.3, Math.min(1, shellOpacity)) : 1

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
    // there) and, like the login screen, the colours of the colour theme in use
    // (loginBackground ... in `themes` below: the shell writes them into the
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
    // Every colour the shell draws with is here (Default lists what each one is
    // for). Change a theme's colours, or add a theme: a name and the colours it
    // changes - a colour it leaves out is Default's.
    // GTK and Qt apps switch along (scripts/theme.sh): Default uses the GTK theme
    // Frame and the Kvantum theme Frame, the others Frame-<name> / Frame<name>
    // (made by themes/make-themes.py and themes/Kvantum/make-frame.py in the
    // frameshell folder; a theme of your own without them uses Default's).
    readonly property var themes: [
        {
            name: "Default",
            frame: "#1a1a1a",        // main colour: frame, island, panels
            outline: "#313131",      // the border colour
            divider: "#313131",      // the thin lines between the power menu's rows and under the calendar's weekdays
            selected: "#2a2a2a",     // selected / pressed row, buttons (Cancel, Done ...)
            hover: "#222222",        // hovered row
            buttonHover: "#313131",  // Done / Cancel buttons under the pointer
            buttonPrimaryHover: "#ffffff", // Authenticate / Shut down / Log out under the pointer (Config.text when not)
            buttonDisabled: "#3a3a3a", // Wi-Fi's Join button before a password is typed
            text: "#ffffff",
            textDim: "#8c8c8c",
            textFaint: "#575757",
            textSelection: "#3e3e3e", // selected text in the shell's text fields (kitty's selection_background and the GTK / Qt themes use the same)
            notificationText: "#e8e8e8", // the text of a notification
            fieldFocus: "#4a4a4a",   // the outline of the Wi-Fi password field while you type
            iconDim: "#494949",      // the grey part of icons (empty battery, unlit bars ...)
            pillUntiled: "#696969",  // the small workspace pill of a workspace with tiling off (SUPER + Page Down)
            dockLine: "#494949",     // the line in the dock between the pinned apps and the other open apps
            iconTile: "#ffffff",     // the tile shown for an app without an icon
            pickerIcon: "#d6d6d6",   // the colour picker's icon (Config.text under the pointer)
            slider: "#ffffff",       // the filled part and knob of the sliders (volume, brightness)
            scrollbar: "#3a3a3a",    // the thin scroll bar of the Wi-Fi / Bluetooth lists
            thumbOutline: "#ffffff", // the outline of the picture / theme in the middle of the switchers (the others: inactiveHint)
            shotOutline: "#ffffff",  // the line round the area picked on the screenshot screen (Print)
            shotDim: "#bd000000",    // the screenshot screen around that area: black at 74 % (#AARRGGBB)
            activeHint: "#c4c4c4",   // the border round the focused window (Hyprland's active border), and one of the dots on the theme's card
            inactiveHint: "#313131", // the border round the other windows, and the outline of the pictures / cards beside the middle in the switchers
            accent: "#ffb454",       // battery while charging
            warning: "#ff6b6b",      // battery below 15 %, wrong password
            // the login screen (SDDM, Pixie) and the lock screen
            loginBackground: "#1a1a1a", // the card (the password field: a little lighter)
            loginText: "#e3e3e3",    // its text
            loginAccent: "#c4c4c4",  // the avatar letter, the session icon
            loginHours: "#ffffff",   // the clock's hours
            loginMinutes: "#ffffff", // the clock's minutes
            loginCorners: "#c4c4c4", // the date and the power icons and labels in the top corners
            loginField: "#c4c4c4",   // the password field's border and the round button
            loginAccentText: "#1a1a1a", // the arrow on the round button
            loginError: "#442222"    // the card after a wrong password (it shakes)
        },
        {
            name: "Noir",
            frame: "#000000",
            outline: "#000000",
            divider: "#060606",
            selected: "#060606",
            hover: "#060606",
            buttonHover: "#0c0c0c",
            buttonPrimaryHover: "#ffffff",
            buttonDisabled: "#3a3a3a",
            text: "#ffffff",
            textDim: "#8c8c8c",
            textFaint: "#575757",
            textSelection: "#222222",
            notificationText: "#e8e8e8",
            fieldFocus: "#4a4a4a",
            iconDim: "#1a1a1a",
            pillUntiled: "#3a3a3a",
            dockLine: "#3a3a3a",
            iconTile: "#ffffff",
            pickerIcon: "#d6d6d6",
            slider: "#ffffff",
            scrollbar: "#3a3a3a",
            thumbOutline: "#ffffff",
            shotOutline: "#ffffff",
            shotDim: "#bd000000",
            activeHint: "#7d7d7d",
            inactiveHint: "#060606",
            accent: "#ffb454",
            warning: "#ff6b6b",
            loginBackground: "#000000",
            loginText: "#ffffff",
            loginAccent: "#ffffff",
            loginHours: "#ffffff",
            loginMinutes: "#ffffff",
            loginCorners: "#c4c4c4",
            loginField: "#060606",
            loginAccentText: "#ffffff",
            loginError: "#0e0606"
        },
        {
            name: "Mocha",           // Catppuccin Mocha
            frame: "#181825",        // Mantle
            outline: "#45475a",      // Surface1
            divider: "#45475a",      // Surface1
            selected: "#313244",     // Surface0
            hover: "#1e1e2e",        // Base
            buttonHover: "#45475a",  // Surface1
            buttonPrimaryHover: "#ffffff",
            buttonDisabled: "#3a3a3a",
            text: "#cdd6f4",         // Text
            textDim: "#9399b2",      // Overlay2
            textFaint: "#6c7086",    // Overlay0
            textSelection: "#474859",
            notificationText: "#e8e8e8",
            fieldFocus: "#4a4a4a",
            iconDim: "#585b70",      // Surface2
            pillUntiled: "#6c7086",  // Overlay0
            dockLine: "#585b70",     // Surface2
            iconTile: "#ffffff",
            pickerIcon: "#d6d6d6",
            slider: "#ffffff",
            scrollbar: "#3a3a3a",
            thumbOutline: "#bac2de", // Subtext1
            shotOutline: "#cdd6f4",  // Text
            shotDim: "#bd000000",
            activeHint: "#bec7e6",
            inactiveHint: "#45475a", // Surface1
            accent: "#fab387",       // Peach
            warning: "#f38ba8",      // Red
            loginBackground: "#181825", // Mantle
            loginText: "#cdd6f4",    // Text
            loginAccent: "#bec7e6",  // like activeHint
            loginHours: "#2444b3",
            loginMinutes: "#2444b3",
            loginCorners: "#bec7e6",
            loginField: "#bec7e6",
            loginAccentText: "#181825", // Mantle
            loginError: "#442222"
        }
    ]

    // the theme in use: the one picked in the switcher (services/Themes.qml sets
    // it, scripts/theme.sh keeps it), else the first one
    property string themeName: ""
    readonly property var theme: themes.find(t => t.name === themeName) || themes[0]

    // a colour of a theme (an entry of `themes`); one it does not set is Default's
    function themeColor(t, key) {
        return t && t[key] !== undefined ? t[key] : themes[0][key];
    }

    readonly property color frame: themeColor(theme, "frame")
    // the frame colour of a pop-up card (switcher, launcher ...): see-through with the
    // shell's blur (shellAlpha), else the same as frame
    readonly property color surface: Qt.rgba(frame.r, frame.g, frame.b, shellAlpha)
    readonly property color outline: themeColor(theme, "outline")
    readonly property color divider: themeColor(theme, "divider")
    readonly property color selected: themeColor(theme, "selected")
    readonly property color hover: themeColor(theme, "hover")
    readonly property color buttonHover: themeColor(theme, "buttonHover")
    readonly property color buttonPrimaryHover: themeColor(theme, "buttonPrimaryHover")
    readonly property color buttonDisabled: themeColor(theme, "buttonDisabled")
    readonly property color text: themeColor(theme, "text")
    readonly property color textDim: themeColor(theme, "textDim")
    readonly property color textFaint: themeColor(theme, "textFaint")
    readonly property color textSelection: themeColor(theme, "textSelection")
    readonly property color notificationText: themeColor(theme, "notificationText")
    readonly property color fieldFocus: themeColor(theme, "fieldFocus")
    readonly property color iconDim: themeColor(theme, "iconDim")
    readonly property color pillUntiled: themeColor(theme, "pillUntiled")
    readonly property color dockLine: themeColor(theme, "dockLine")
    readonly property color iconTile: themeColor(theme, "iconTile")
    readonly property color pickerIcon: themeColor(theme, "pickerIcon")
    readonly property color slider: themeColor(theme, "slider")
    readonly property color scrollbar: themeColor(theme, "scrollbar")
    readonly property color thumbOutline: themeColor(theme, "thumbOutline")
    readonly property color shotOutline: themeColor(theme, "shotOutline")
    readonly property color shotDim: themeColor(theme, "shotDim")
    // the window borders: hyprland.lua reads them from here when Hyprland starts, the shell hands
    // them to Hyprland when the theme changes (modules/HyprSync.qml)
    readonly property color activeHint: themeColor(theme, "activeHint")
    readonly property color inactiveHint: themeColor(theme, "inactiveHint")
    readonly property color accent: themeColor(theme, "accent")
    readonly property color warning: themeColor(theme, "warning")
    readonly property color loginBackground: themeColor(theme, "loginBackground")
    readonly property color loginText: themeColor(theme, "loginText")
    readonly property color loginAccent: themeColor(theme, "loginAccent")
    readonly property color loginCorners: themeColor(theme, "loginCorners")
    readonly property color loginField: themeColor(theme, "loginField")
    readonly property color loginHours: themeColor(theme, "loginHours")
    readonly property color loginMinutes: themeColor(theme, "loginMinutes")
    readonly property color loginError: themeColor(theme, "loginError")
    readonly property color loginAccentText: themeColor(theme, "loginAccentText")

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

    // the border widths, the window gap and the corner rounding of the Settings app
    // (Appearance): frameBorder / windowBorder / windowGap / cornerRounding above
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/frameshell/appearance.json"
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onAdapterUpdated: writeAdapter()
        onLoaded: config.appearanceRead = true
        onLoadFailed: config.appearanceRead = true

        adapter: JsonAdapter {
            id: appearance
            property int frameBorder: 2
            property int windowBorder: 2
            property int windowGap: -1
            property int cornerRounding: -1
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

    // the blur of the Settings app (Blur): windowBlur ... shellOpacity above
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/frameshell/blur.json"
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: blur
            property bool windowBlur: true
            property bool shellBlur: false
            property int blurSize: 7
            property int blurPasses: 2
            property real blurBrightness: 1.0
            property real blurContrast: 0.9
            property real shellOpacity: 0.8
        }
    }
}
