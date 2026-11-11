pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Themes.qml - the colour themes you can switch between (SUPER + CTRL + Up / Down,
//  the theme switcher in the island, in a loop) and the one in use.
//
//  The themes and their colours are in Config.qml (`themes`); the one in use is
//  Config.themeName. Works like services/Wallpapers.qml.
//
//  GTK and Qt apps follow it: scripts/theme.sh switches their themes (and keeps
//  the name for the next start) when you pick one, and once when the shell
//  starts (after an update of the configs, say).
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    readonly property var list: Config.themes
    readonly property int count: list.length
    // the theme in use
    readonly property int index: Math.max(0, list.findIndex(t => t.name === Config.theme.name))

    // ── switching ─────────────────────────────────────────────────────────
    // SUPER + CTRL + Up / Down move through the themes in a loop; the colours do not
    // change yet. Enter uses the one in the middle (Ui.applySwitcher() calls
    // apply()).
    //
    // `cursor` counts every step and never wraps, so the strip keeps sliding
    // the same way round the loop; it is on list[cursor mod count].
    property int cursor: 0
    readonly property int selectedIndex: count > 0 ? ((cursor % count) + count) % count : -1
    signal jumped                       // the cursor moved without sliding: the strip follows at once
    signal bumped(int direction)        // a single theme: nowhere to go (the strip nudges)

    // the switcher opens: start at the theme in use
    function startBrowsing() {
        cursor = index;
        jumped();
    }

    // SUPER + CTRL + Up = +1, SUPER + CTRL + Down = -1
    function browse(direction) {
        if (count < 2)
            bumped(direction);
        else
            cursor += direction;
    }

    // a click on a theme `offset` places beside the middle one
    function browseBy(offset) {
        if (count > 0)
            cursor += offset;
    }

    // the theme the switcher is on is used from now on
    function apply() {
        if (selectedIndex < 0)
            return;
        const name = list[selectedIndex].name;
        if (name === Config.theme.name)
            return;
        Config.themeName = name;
        follow();
    }

    // a theme becomes the one in use (the Settings app's Theme page)
    function set(name) {
        if (name === Config.theme.name || !list.some(t => t.name === name))
            return;
        Config.themeName = name;
        follow();
    }

    // a theme's five colours, as its card shows them (the switcher, the Settings app):
    // its greys, its text colours and the focused window's border (activeHint), from the
    // darkest to the lightest
    function dots(theme) {
        if (!theme)
            return [];
        const colours = ["iconDim", "textFaint", "textDim", "text", "activeHint"].map(k => Config.themeColor(theme, k));
        const light = c => {
            const q = Qt.lighter(c, 1);     // any colour text as a colour
            return 0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b;
        };
        return colours.map(c => ({ c: c, l: light(c) })).sort((a, b) => a.l - b.l).map(d => d.c);
    }

    // ── window borders ────────────────────────────────────────────────────
    // A colour of Config.qml ("#c4c4c4", "#80c4c4c4") as Hyprland writes it
    // ("rgba(c4c4c4ff)"): the window borders of the theme in use (activeHint /
    // inactiveHint) go to Hyprland like this (modules/HyprSync.qml).
    function hyprColor(c) {
        const q = Qt.lighter(c, 1);         // any colour text as a colour
        const hex = v => ("0" + Math.max(0, Math.min(255, Math.round(v * 255))).toString(16)).slice(-2);
        return "rgba(" + hex(q.r) + hex(q.g) + hex(q.b) + hex(q.a) + ")";
    }

    // ── the login screen ──────────────────────────────────────────────────
    // SDDM's Pixie theme (Config.lockTheme) reads theme.conf and, over it,
    // theme.conf.user. install.sh makes that file yours; the shell writes the login
    // colours of the theme in use into it (loginBackground ... in Config.qml), and
    // the lock screen reads the same two files (modules/Lock.qml).
    property bool loginConfFound: false
    FileView {
        id: loginConf
        path: Config.lockTheme + "/theme.conf.user"
        printErrors: false
        blockLoading: true
        atomicWrites: false             // only this file is yours, not the folder
        onLoaded: {
            root.loginConfFound = true;
            if (Config.themeRead)       // read after the start's follow(): write now
                root.writeLogin();
        }
        onLoadFailed: root.loginConfFound = false
    }

    function writeLogin() {
        if (!loginConfFound)
            return;                     // no Pixie, or install.sh did not make the file
        const t = Config.theme;
        const c = key => Config.themeColor(t, key);
        const text = "[General]\n" +
            "# Written by the shell (services/Themes.qml) for the colour theme \"" + t.name + "\":\n" +
            "# loginBackground ... in ~/.config/quickshell/frame/Config.qml. It wins over theme.conf;\n" +
            "# change the colours in Config.qml, not here.\n" +
            "backgroundColor=" + c("loginBackground") + "\n" +
            "textColor=" + c("loginText") + "\n" +
            "accentColor=" + c("loginAccent") + "\n" +
            "cornerColor=" + c("loginCorners") + "\n" +
            "fieldColor=" + c("loginField") + "\n" +
            "hourColor=" + c("loginHours") + "\n" +
            "minuteColor=" + c("loginMinutes") + "\n" +
            "errorColor=" + c("loginError") + "\n" +
            "accentTextColor=" + c("loginAccentText") + "\n";
        if (loginConf.text() !== text)
            loginConf.setText(text);
    }

    // GTK and Qt apps (and the remembered name) follow the theme in use, and the
    // login screen
    function follow() {
        Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/theme.sh"), Config.theme.name]);
        writeLogin();
    }
    // once at start, when Config.qml has read which theme you picked
    Component.onCompleted: {
        if (Config.themeRead)
            follow();
    }
    Connections {
        target: Config
        function onThemeReadChanged() {
            if (Config.themeRead)
                root.follow();
        }
    }
}
