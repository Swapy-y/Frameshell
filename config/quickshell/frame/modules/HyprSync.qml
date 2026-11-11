import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// ═══════════════════════════════════════════════════════════════════════════
//  HyprSync.qml - hands the window border's width (Config.windowBorder, the
//  Settings app's Appearance page), the corner rounding (Config.cornerRounding,
//  the same page; else cornerRadius), shadows and shadowStrength
//  to Hyprland, so the window border, the window corners and the window shadows
//  always match the frame and the panels. And the window border colours of the
//  colour theme in use (activeHint / inactiveHint in Config.qml). And the gap
//  round the windows (Config.windowGap, the Appearance page's "Window gap").
//
//  hyprland.lua already reads these when Hyprland starts or reloads (the width
//  and the gap from ~/.local/state/frameshell/appearance.json, the others from
//  Config.qml).
//  A change in the Settings app, or saving Config.qml (which reloads the shell),
//  runs this once more: the new values reach the windows right away, no
//  Hyprland reload needed. Outside Hyprland it does nothing.
//
//  The keyboard, the mouse and the touchpad (the Settings app's Devices page,
//  input.json) go to Hyprland once the shell has read them - so Hyprland has
//  what the Settings app shows even when it started with other values (an older
//  hyprland.lua) - and then whenever one of them changes.
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    id: root

    readonly property int border: Math.max(0, Config.windowBorder)
    // the Settings app's Devices page (Mouse): focus follows the pointer (1) or a click (2);
    // the pointer jumps to a window focused with the keys unless no_warps
    readonly property int followMouse: Config.focusFollowsMouse ? 1 : 2
    readonly property bool noWarps: !Config.cursorFollowsFocus

    // the blur (the Settings app's Blur page): Hyprland's blur is on while windows or the
    // shell want it; windows get none (a rule, "frame-window-blur") without windowBlur, the
    // shell's layers get it (a rule, "frame-shell-blur") with shellBlur - only where they
    // are at least about as solid as the shell's surfaces (ignore_alpha), so not their
    // shadows or the empty middle of the screen
    function num(v) {
        return String(Math.round(v * 100) / 100);
    }
    readonly property string blurConf: "enabled = " + (Config.windowBlur || Config.shellBlur) +
        ", size = " + Math.max(1, Math.round(Config.blurSize)) + ", passes = " + Math.max(1, Math.round(Config.blurPasses)) +
        ", brightness = " + num(Config.blurBrightness) + ", contrast = " + num(Config.blurContrast)
    readonly property string blurRules: "hl.window_rule({ name = 'frame-window-blur', enabled = " + !Config.windowBlur +
        ", match = { class = '.*' }, no_blur = true }); " +
        "hl.layer_rule({ name = 'frame-shell-blur', enabled = " + Config.shellBlur +
        ", match = { namespace = '^frame-(overlay|switcher|launcher|auth|network|confirm|emoji|osk)\\$' }, blur = true, ignore_alpha = " +
        num(Math.max(0, Config.shellAlpha - 0.05)) + " })"
    readonly property int rounding: Math.max(0, Config.cornerRounding)

    // the keyboard, the mouse and the touchpad (the Settings app's Devices page)
    readonly property string inputConf: "repeat_rate = " + Math.round(Config.repeatRate) + ", repeat_delay = " + Math.round(Config.repeatDelay) +
        ", numlock_by_default = " + Config.numlock + ", sensitivity = " + num(Config.mouseSpeed) +
        ", accel_profile = '" + (Config.mouseAccel ? "adaptive" : "flat") + "', scroll_factor = " + num(Config.mouseScrollSpeed) +
        ", natural_scroll = " + Config.mouseNaturalScroll +
        ", touchpad = { tap_to_click = " + Config.touchpadTap + ", natural_scroll = " + Config.touchpadNaturalScroll +
        ", disable_while_typing = " + Config.touchpadTyping + ", scroll_factor = " + num(Config.touchpadScrollSpeed) + " }"
    property string inputSent: ""
    // sent once the shell has read them all (input.json comes in a moment after the
    // start; values from before that are not sent), then on every change
    property bool inputReady: false
    Timer {
        interval: 1500
        running: true
        onTriggered: {
            root.inputReady = true;
            root.resyncInput();
        }
    }
    function resyncInput() {
        if (!inputReady || inputSync.running || inputSent === inputConf)
            return;
        inputSent = inputConf;
        root.run(inputSync, inputCommand());
    }
    onInputConfChanged: resyncInput()

    // Each command below is made right when it is sent, from the values of that moment
    // (run()). As a binding it could still hold the values before the change: the change
    // handler that starts it can come before the binding is updated, and Quickshell
    // starts the process at once - Hyprland got the setting before the last one.
    function run(proc, command) {
        proc.command = command;
        proc.running = true;
    }

    function inputCommand() {
        const accel = Config.mouseAccel ? "adaptive" : "flat";
        return ["sh", "-c",
            // Lua config (Hyprland 0.55+): `hyprctl eval`; older hyprlang configs: `hyprctl keyword`
            '[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl >/dev/null 2>&1 || exit 0; ' +
            'hyprctl eval "hl.config({ input = { ' + root.inputConf + ' } })" | grep -q "^ok" || ' +
            '{ hyprctl keyword input:repeat_rate ' + Math.round(Config.repeatRate) + ' >/dev/null; hyprctl keyword input:repeat_delay ' + Math.round(Config.repeatDelay) + ' >/dev/null; ' +
            'hyprctl keyword input:numlock_by_default ' + Config.numlock + ' >/dev/null; ' +
            'hyprctl keyword input:sensitivity ' + root.num(Config.mouseSpeed) + ' >/dev/null; hyprctl keyword input:accel_profile ' + accel + ' >/dev/null; ' +
            'hyprctl keyword input:scroll_factor ' + root.num(Config.mouseScrollSpeed) + ' >/dev/null; ' +
            'hyprctl keyword input:natural_scroll ' + Config.mouseNaturalScroll + ' >/dev/null; ' +
            'hyprctl keyword input:touchpad:tap-to-click ' + Config.touchpadTap + ' >/dev/null; hyprctl keyword input:touchpad:natural_scroll ' + Config.touchpadNaturalScroll + ' >/dev/null; ' +
            'hyprctl keyword input:touchpad:disable_while_typing ' + Config.touchpadTyping + ' >/dev/null; ' +
            'hyprctl keyword input:touchpad:scroll_factor ' + root.num(Config.touchpadScrollSpeed) + ' >/dev/null; }; true'];
    }

    Process {
        id: inputSync
        onExited: root.resyncInput()
    }

    // SHADOW_ACTIVE / SHADOW_INACTIVE, read from hyprland.lua (the only place they are set)
    FileView {
        id: hyprConf
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/hyprland.lua"
        blockLoading: true
        printErrors: false
    }
    function hyprFactor(name, fallback) {
        const m = (hyprConf.text() || "").match(new RegExp("\\n\\s*local\\s+" + name + "\\s*=\\s*([0-9.]+)"));
        const v = m ? parseFloat(m[1]) : NaN;
        return isNaN(v) ? fallback : v;
    }
    readonly property real activeFactor: hyprFactor("SHADOW_ACTIVE", 0.6)
    readonly property real inactiveFactor: hyprFactor("SHADOW_INACTIVE", 0.6)

    readonly property real strength: Math.max(0, Math.min(1, Config.shadowStrength))
    readonly property bool shadowsOn: Config.shadows && strength > 0
    readonly property string shadowActive: shadowColor(strength * activeFactor)
    readonly property string shadowInactive: shadowColor(strength * inactiveFactor)

    // "rgba(000000XX)": black with the given opacity (0 ... 1)
    function shadowColor(alpha) {
        const v = Math.round(Math.max(0, Math.min(1, alpha)) * 255);
        return "rgba(000000" + (v < 16 ? "0" : "") + v.toString(16) + ")";
    }

    // the window border colours of the shell's theme: activeHint / inactiveHint in Config.qml
    // (a theme that leaves one out gets Default's), as Hyprland writes them ("rgba(c4c4c4ff)")
    readonly property var borders: ({
            active: Themes.hyprColor(Config.activeHint),
            inactive: Themes.hyprColor(Config.inactiveHint)
        })
    readonly property string borderColors: borders.active + " " + borders.inactive

    // sent when the shell knows the theme you picked, and on every switch (SUPER + CTRL + Up / Down)
    property string sentBorders: ""
    function syncBorders() {
        if (!Config.themeRead || borderSync.running || sentBorders === borderColors)
            return;
        sentBorders = borderColors;
        root.run(borderSync, borderCommand());
    }
    onBorderColorsChanged: syncBorders()
    Connections {
        target: Config

        function onThemeReadChanged() {
            root.syncBorders();
        }
    }

    function borderCommand() {
        const active = root.borders.active;
        const inactive = root.borders.inactive;
        return ["sh", "-c",
            '[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl >/dev/null 2>&1 || exit 0; ' +
            "hyprctl eval \"hl.config({ general = { col = { active_border = '" + active + "', inactive_border = '" + inactive + "' } } })\" | grep -q \"^ok\" || " +
            '{ hyprctl keyword general:col.active_border "' + active + '" >/dev/null; hyprctl keyword general:col.inactive_border "' + inactive + '" >/dev/null; }'];
    }

    Process {
        id: borderSync
        // a switch while this was still running: send the newest colours too
        onExited: root.syncBorders()
    }

    // the gap round the windows: hyprland.lua's frameshell_gap() sets Hyprland's gaps and its
    // own WINDOW_GAP (the box of a maximized floating window, of a new one with tiling off);
    // sent once the shell has read appearance.json (not its default first: the tiles would
    // move to it and back) and on every move of the slider (the newest one after a send that
    // was still running)
    readonly property int gap: Config.appearanceRead ? Math.max(0, Config.windowGap) : -1
    property int sentGap: -1
    function syncGap() {
        if (gap < 0 || gapSync.running || sentGap === gap)
            return;
        sentGap = gap;
        root.run(gapSync, gapCommand());
    }
    onGapChanged: syncGap()

    function gapCommand() {
        const g = root.gap;
        const lo = Math.floor(g / 2);
        const hi = g - lo;
        return ["sh", "-c",
            // without frameshell_gap (an older hyprland.lua) only Hyprland's gaps; hyprlang configs: `hyprctl keyword`
            '[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl >/dev/null 2>&1 || exit 0; ' +
            'hyprctl eval "if frameshell_gap then frameshell_gap(' + g + ') else hl.config({ general = { gaps_in = { top = ' + lo + ', left = ' + lo +
                ', right = ' + hi + ', bottom = ' + hi + ' }, gaps_out = ' + g + ', float_gaps = ' + g + ' } }) end" | grep -q "^ok" || ' +
            '{ hyprctl keyword general:gaps_in "' + lo + ' ' + hi + ' ' + hi + ' ' + lo + '" >/dev/null; hyprctl keyword general:gaps_out ' + g + ' >/dev/null; ' +
            'hyprctl keyword general:float_gaps ' + g + ' >/dev/null; }; true'];
    }

    Process {
        id: gapSync
        onExited: root.syncGap()
    }

    // the Process below runs once when the shell starts (every save of Config.qml
    // restarts the shell) and again on every change while it is running (the
    // Settings app's slider); a change that comes while it still runs is sent
    // right after it
    readonly property string wanted: border + " " + rounding + " " + shadowsOn + " " + shadowActive + " " + shadowInactive + " " + followMouse + " " + noWarps + " " + blurConf + " " + blurRules
    property string sent: ""
    function resync() {
        if (sync.running || sent === wanted)
            return;
        sent = wanted;
        root.run(sync, syncCommand());
    }
    onWantedChanged: resync()
    Component.onCompleted: {
        syncBorders();
        syncGap();
        resync();
    }

    function syncCommand() {
        return ["sh", "-c",
            // Lua config (Hyprland 0.55+): `hyprctl eval`; older hyprlang configs: `hyprctl keyword`
            '[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl >/dev/null 2>&1 || exit 0; ' +
            'hyprctl eval "hl.config({ general = { border_size = ' + root.border + ' }, decoration = { rounding = ' + root.rounding +
                ", shadow = { enabled = " + root.shadowsOn + ", color = '" + root.shadowActive + "', color_inactive = '" + root.shadowInactive + "' }" +
                ", blur = { " + root.blurConf + " } }" +
                ", input = { follow_mouse = " + root.followMouse + " }, cursor = { no_warps = " + root.noWarps + " } })\" | grep -q \"^ok\" || " +
            '{ hyprctl keyword general:border_size ' + root.border + ' >/dev/null; hyprctl keyword decoration:rounding ' + root.rounding + ' >/dev/null; ' +
            'hyprctl keyword input:follow_mouse ' + root.followMouse + ' >/dev/null; hyprctl keyword cursor:no_warps ' + root.noWarps + ' >/dev/null; ' +
            'hyprctl keyword decoration:shadow:enabled ' + root.shadowsOn + ' >/dev/null; ' +
            'hyprctl keyword decoration:shadow:color "' + root.shadowActive + '" >/dev/null; ' +
            'hyprctl keyword decoration:shadow:color_inactive "' + root.shadowInactive + '" >/dev/null; ' +
            'hyprctl keyword decoration:blur:enabled ' + (Config.windowBlur || Config.shellBlur) + ' >/dev/null; }; ' +
            // the two blur rules (Lua config only), on their own: should they fail, the rest is set
            'hyprctl eval "' + root.blurRules + '" >/dev/null 2>&1; true'];
    }

    Process {
        id: sync
        onExited: root.resync()
    }
}
