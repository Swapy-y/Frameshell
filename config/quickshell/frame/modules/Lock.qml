import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Lock.qml - the lock screen. It is the Pixie login screen (SDDM theme
//  "pixie", installed by install.sh) drawn by Quickshell: same wallpaper,
//  colours, fonts, stacked clock and login card, so locking and logging in
//  look the same. LockView.qml draws it, this file has the logic.
//
//  It runs as its own small Quickshell process (lock.qml), separate from the
//  shell. scripts/lock.sh starts it at login and it waits in the background,
//  ready, so locking is instant (see "locking" below). If it ever fails,
//  lock.sh starts hyprlock instead, and Hyprland keeps the screen locked in
//  between.
//
//  It fades in over the desktop and, after the right password, fades out
//  again to show the desktop (see "fading in and out" below).
//
//  The password is checked by PAM with /etc/pam.d/hyprlock (installed with
//  hyprlock; it asks for your normal password), or /etc/pam.d/login.
//
//  Settings: Config.lockTheme (where the theme is) and Config.lockPowerButtons.
//  Wallpaper, colours and fonts come from the theme's theme.conf and, over it,
//  theme.conf.user (where the shell writes the login colours of the colour theme
//  in use, services/Themes.qml) - the same two files the login screen reads.
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    id: root

    // ── the Pixie theme: theme.conf and theme.conf.user ([General] section) ──
    readonly property string themeDir: Config.lockTheme
    property var themeBase: ({})            // theme.conf
    property var themeUser: ({})            // theme.conf.user: its keys win, like in SDDM
    readonly property var theme: Object.assign({}, themeBase, themeUser)
    property bool themeFound: false

    // The wallpaper you picked on the desktop (SUPER + CTRL + Left / Right;
    // scripts/wallpaper.sh writes this file). While the theme shows frameshell's
    // copy of the desktop wallpaper (theme.conf background=assets/wallpaper.png,
    // what install.sh writes) the lock screen shows that picture itself, so it is
    // always the one on the desktop.
    property string desktopWallpaper: ""
    property string brokenWallpaper: ""         // could not be read: the theme's own copy instead
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/frameshell/wallpaper"
        printErrors: false
        blockLoading: true
        watchChanges: true                      // picked another one while the lock screen waits
        onFileChanged: reload()
        onLoaded: root.desktopWallpaper = text().trim()
        onLoadFailed: root.desktopWallpaper = ""
    }

    // values of theme.conf(.user); without them, the colour theme's login colours (Config.qml)
    readonly property string background: {
        const b = theme.background || "";
        const desktopCopy = b.length === 0 || b === "assets/wallpaper.png" || b === themeDir + "/assets/wallpaper.png";
        if (desktopCopy && desktopWallpaper.length > 0 && desktopWallpaper !== brokenWallpaper)
            return desktopWallpaper;
        if (b.length === 0)
            return Config.wallpaper;            // no theme: the default desktop wallpaper
        return b.startsWith("/") ? b : themeDir + "/" + b;
    }
    readonly property color baseColor: theme.backgroundColor || Config.loginBackground
    readonly property color textColor: theme.textColor || Config.loginText
    readonly property color configuredAccent: theme.accentColor || Config.loginAccent
    readonly property color accentTextColor: theme.accentTextColor || (themeFound ? "white" : Config.loginAccentText)
    readonly property bool autoColor: theme.autoColor === "true"       // like Pixie: only when it says so
    readonly property bool use24h: theme.use24HourClock === undefined ? Config.clock24h : theme.use24HourClock === "true"
    readonly property string fontFamily: theme.fontFamily || ""
    readonly property color surfaceColor: Qt.lighter(baseColor, 1.3)
    readonly property color surfaceVariantColor: Qt.lighter(baseColor, 1.6)

    // the accent: theme.conf accentColor, or (autoColor=true) picked from the
    // wallpaper by LockView, the same way Pixie does it
    property color extracted: configuredAccent
    property string extractedFor: ""
    readonly property bool accentReady: !autoColor || extractedFor === background
    readonly property color accent: autoColor && accentReady ? extracted : configuredAccent
    // the date and the power icons (cornerColor) and the password field's border and the
    // round button (fieldColor): like Pixie, the accent when theme.conf(.user) leaves them
    // empty or picks the colours from the wallpaper (autoColor=true)
    readonly property color cornerColor: !autoColor && theme.cornerColor ? theme.cornerColor : (themeFound ? accent : Config.loginCorners)
    readonly property color fieldColor: !autoColor && theme.fieldColor ? theme.fieldColor : (themeFound ? accent : Config.loginField)
    // the clock's hours and minutes (hourColor / minuteColor): "" = like Pixie, the colour
    // LockView makes from the accent; the card after a wrong password (errorColor)
    readonly property string hourColor: !autoColor && theme.hourColor ? theme.hourColor : (themeFound ? "" : String(Config.loginHours))
    readonly property string minuteColor: !autoColor && theme.minuteColor ? theme.minuteColor : (themeFound ? "" : String(Config.loginMinutes))
    readonly property color errorColor: theme.errorColor || (themeFound ? "#442222" : Config.loginError)

    function setExtracted(c) {
        extracted = c;
        extractedFor = background;
    }

    function parseIni(text) {
        const out = {};
        let section = "";
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.length === 0 || line.startsWith("#") || line.startsWith(";"))
                continue;
            if (line.startsWith("[")) {
                section = line;
                continue;
            }
            const eq = line.indexOf("=");
            if (section === "[General]" && eq > 0)
                out[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
        }
        return out;
    }

    FileView {
        path: root.themeDir + "/theme.conf"
        printErrors: false
        blockLoading: true          // known before the first frame is drawn
        watchChanges: true          // edited while the lock screen keeps running: read it again
        onFileChanged: reload()
        onLoaded: {
            root.themeBase = root.parseIni(text());
            root.themeFound = true;
        }
        onLoadFailed: {
            root.themeBase = {};
            root.themeFound = false;
        }
    }
    FileView {
        path: root.themeDir + "/theme.conf.user"
        printErrors: false
        blockLoading: true
        watchChanges: true          // the shell writes it when you switch colour themes
        onFileChanged: reload()
        onLoaded: root.themeUser = root.parseIni(text())
        onLoadFailed: root.themeUser = {}
    }

    // ── who is locked in ──────────────────────────────────────────────────
    readonly property string user: Quickshell.env("USER") || "user"
    property string realName: ""                 // from /etc/passwd, like SDDM shows it
    readonly property string shownName: {
        // SDDM: the real name, else the user name; "-" and "_" become spaces
        let s = realName.length > 0 ? realName : user;
        s = s.replace(/[-_]/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // read again each time the screen locks (the Settings app's Profile card may have changed it)
    FileView {
        id: passwd
        path: "/etc/passwd"
        printErrors: false
        onLoaded: {
            const lines = text().split("\n");
            for (let i = 0; i < lines.length; i++) {
                const f = lines[i].split(":");
                if (f[0] === root.user && f.length > 4) {
                    root.realName = f[4].split(",")[0].trim();
                    break;
                }
            }
        }
    }

    // the picture: ~/.face (the Settings app's Profile card saves it there), else
    // ~/.face.icon, else the theme's avatar (install.sh and the Settings app copy it
    // there for the login screen, which can't read your home folder) - looked for
    // again each time the screen locks; its time makes a new picture in the same
    // file read again
    property string avatar: ""
    property string avatarStamp: ""
    // the session pill shows when the login screen has more than one session to pick
    property int sessionCount: 0
    readonly property string sessionName: {
        const d = Quickshell.env("XDG_SESSION_DESKTOP") || Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland";
        const s = d.split(":")[0].replace(/[-_]/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    Process {
        id: probe
        // line 1: the avatar file (or nothing), line 2: how many sessions SDDM can offer,
        // line 3: the avatar's time
        command: ["sh", "-c", 'a=""; for f in "$HOME/.face" "$HOME/.face.icon" "$1/assets/avatar.jpg"; do ' + 'if [ -r "$f" ] && [ -s "$f" ]; then a="$f"; break; fi; done; printf "%s\\n" "$a"; ' + 'ls /usr/share/wayland-sessions/*.desktop /usr/share/xsessions/*.desktop 2>/dev/null | wc -l; ' + '[ -n "$a" ] && stat -c %Y "$a" 2>/dev/null', "sh", root.themeDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.avatar = lines[0].trim();
                root.sessionCount = parseInt(lines[1]) || 0;
                root.avatarStamp = (lines[2] || "").trim();
            }
        }
    }

    // Caps Lock state, from Hyprland (the card says "Caps Lock is on", like the
    // login screen): read when the screen locks, when the card shows, when Caps
    // Lock is pressed and released (it turns ON on the press but OFF only on the
    // release), and every second while the card is up (another keyboard, a key
    // event the card did not get)
    property bool capsLock: false
    Timer {
        interval: 1000
        repeat: true
        running: root.loginVisible && !root.unlocked && root.onHyprland
        onTriggered: root.checkCapsLock()
    }
    function checkCapsLock() {
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
            capsLockTimer.restart();
    }
    Timer {
        id: capsLockTimer
        interval: 120          // after the key press has been handled
        onTriggered: capsLockProc.running = true
    }
    Process {
        id: capsLockProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards || [];
                    root.capsLock = kb.some(k => k.capsLock === true);
                } catch (e) {
                    root.capsLock = false;
                }
            }
        }
    }

    // PAM service: hyprlock's (hyprlock is installed as the fallback locker), else login
    property bool hyprlockPam: false
    FileView {
        path: "/etc/pam.d/hyprlock"
        printErrors: false
        onLoaded: root.hyprlockPam = true
        onLoadFailed: root.hyprlockPam = false
    }

    // ── locking ───────────────────────────────────────────────────────────
    // lock.sh starts this process once per login and keeps it in the
    // background, unlocked ("resident", FRAME_LOCK_RESIDENT=1): everything is
    // loaded and the wallpaper is decoded already, so locking only has to
    // show it. lock.sh asks over IPC:
    //   qs -p ~/.config/quickshell/frame/lock.qml ipc call lock lock   fade in
    //   qs -p ~/.config/quickshell/frame/lock.qml ipc call lock now    at once (before a suspend)
    // and follows it through the file FRAME_LOCK_MARKER: "locked" once the
    // lock screen is up, "unlocked" after the right password ("ended" if the
    // lock ended some other way). Started on its own (qs -p .../lock.qml) it
    // locks right away and quits once you are back in.
    readonly property bool resident: Quickshell.env("FRAME_LOCK_RESIDENT") === "1"
    readonly property string startMode: Quickshell.env("FRAME_LOCK_START") || (Quickshell.env("FRAME_LOCK_INSTANT") === "1" ? "now" : "lock")

    Component.onCompleted: {
        probe.running = true;
        if (startMode !== "idle")
            lockScreen(startMode === "now");
    }

    function lockScreen(now) {
        if (lockObj.locked) {
            if (unlocked) {
                // locked again while it was still fading out after the password: stay locked
                unlocked = false;
                fadingOut = false;
                waking = false;
                wake.stop();
                fadeOut.stop();
                fadeOutAnyway.stop();
                loginVisible = false;
                failed = false;
                writeState("locked");
                if (now)
                    showNow();
                else
                    fadeIn.start();
            } else if (now) {
                showNow();
            }
            return;
        }
        quitTimer.stop();
        released.stop();
        refreshWarm.stop();
        // your picture and name, as they are now
        passwd.reload();
        if (!probe.running)
            probe.running = true;
        unlocked = false;
        busy = false;
        failed = false;
        pending = "";
        loginVisible = false;
        fadingOut = false;
        waking = false;
        fadeStarted = false;
        drew = false;
        fadeIn.stop();
        fadeOut.stop();
        fadeOutAnyway.stop();
        wake.stop();
        // nearly invisible, not 0: the first frame (the slowest one: textures,
        // shaders) is drawn before the fade starts, so none of the fade is lost
        shown = now || Theme.durLock === 0 ? 1 : 0.02;
        checkCapsLock();
        confirmTimer.restart();
        lockObj.locked = true;
    }

    // the lock state for lock.sh
    readonly property string marker: Quickshell.env("FRAME_LOCK_MARKER") || ""
    FileView {
        id: markerFile
        path: root.marker
        blockWrites: true
        printErrors: false
    }
    function writeState(s) {
        if (marker.length > 0)
            markerFile.setText(s + "\n");
    }

    // Hyprland has not confirmed the lock after 5 s: something is wrong, exit
    // with an error so lock.sh starts hyprlock instead
    Timer {
        id: confirmTimer
        interval: 5000
        onTriggered: {
            if (lockObj.locked && !lockObj.secure && !root.unlocked) {
                console.error("lock: the compositor did not confirm the lock");
                Qt.exit(1);
            }
        }
    }

    // resident: keep the wallpaper decoded (a 4K picture takes a moment), so
    // the lock screen does not wait for it. Read again a little after each
    // unlock, so a new wallpaper shows the next time. (Started to lock right
    // away, the lock screen reads it itself the first time.)
    property bool keepWarm: startMode === "idle"
    readonly property string warmSource: resident && keepWarm && background.length > 0 ? "file://" + background : ""
    Image {
        id: warm
        visible: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop    // like LockView's: part of what makes it the same picture to Qt's cache
        source: root.warmSource
    }
    Timer {
        id: refreshWarm
        interval: 3000
        onTriggered: {
            warm.source = "";
            warm.source = Qt.binding(() => root.warmSource);
        }
    }

    // ── state ─────────────────────────────────────────────────────────────
    property bool loginVisible: false            // false = clock, true = password card
    property bool busy: false                    // PAM is checking the password
    property bool failed: false                  // wrong password (red card, shake)
    property bool unlocked: false
    // the password was sent: PAM checks it, or it was right and the lock screen
    // fades out. The card keeps its "logging in" look (greyed field without the
    // outline, the "⋯" button) all that time, like the login screen's
    readonly property bool loggingIn: busy || unlocked
    property string pending: ""                  // the password until PAM asks for it
    signal shake

    function showLogin() {
        if (!unlocked)
            loginVisible = true;
        checkCapsLock();
    }

    function hideLogin() {
        if (busy)
            return;
        loginVisible = false;
        failed = false;
    }

    function submit(password) {
        if (busy || unlocked)
            return;
        busy = true;
        failed = false;
        pending = password;
        pam.config = hyprlockPam ? "hyprlock" : "login";
        if (pam.active)
            pam.abort();
        if (!pam.start())
            fail();
    }

    function fail() {
        busy = false;
        pending = "";
        failed = true;
        shake();
    }

    // ── fading in and out ─────────────────────────────────────────────────
    // The lock screen fades in over the desktop, and out again once you are
    // back in. For that Hyprland keeps drawing the desktop under it
    // (misc:session_lock_xray), but only during the fades: lock.sh switches it
    // on, it goes off as soon as the lock screen is fully there (so while you
    // are away nothing of the desktop is drawn) and on again for the fade out.
    // Before a suspend (lock.sh --instant) the lock screen appears at once, so
    // the screen never wakes up half see-through.
    readonly property bool onHyprland: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "").length > 0
    property real shown: 0                       // 0 = see-through, 1 = the lock screen
    property bool drew: false                    // the lock screen has drawn its first frame
    property bool fadeStarted: false
    property bool fadingOut: false
    // whatever theme.conf says, the bottom of the lock screen is never see-through
    readonly property color solidBase: Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 1)

    NumberAnimation {
        id: fadeIn
        target: root
        property: "shown"
        to: 1
        duration: Theme.durLock
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveStandard
        onFinished: xrayOff.running = root.onHyprland && !root.unlocked
    }

    NumberAnimation {
        id: fadeOut
        target: root
        property: "shown"
        to: 0
        duration: Theme.durLock
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveStandard
        onFinished: root.release()
    }

    Process {
        id: xrayOff
        command: ["hyprctl", "eval", "hl.config({ misc = { session_lock_xray = false } })"]
    }
    Process {
        id: xrayOn
        command: ["hyprctl", "eval", "hl.config({ misc = { session_lock_xray = true } })"]
        onExited: root.wakeDesktop()
    }

    // While locked, Hyprland did not draw the desktop, so the shell stopped
    // drawing too. For a moment before the fade out the lock screen keeps
    // drawing (an invisible change), so Hyprland draws the desktop under it and
    // the shell wakes up and draws a fresh frame: the fade out always shows the
    // real desktop, never a stale or dark one.
    property bool waking: false
    NumberAnimation {
        id: wake
        target: root
        property: "shown"
        to: 0.995
        duration: 160
        onFinished: root.startFadeOut()
    }
    function wakeDesktop() {
        if (waking || fadingOut || !unlocked)
            return;
        waking = true;
        fadeOutAnyway.stop();
        wake.start();
    }
    // hyprctl did not answer quickly: fade out anyway (rather late than over a
    // black screen with the desktop popping in halfway)
    Timer {
        id: fadeOutAnyway
        interval: 600
        onTriggered: root.wakeDesktop()
    }

    // The fade starts once Hyprland confirmed the lock AND the lock screen
    // drew its first frame (never more than 0.3 s after the confirmation).
    function surfaceDrew() {
        if (drew)
            return;
        drew = true;
        maybeFadeIn();
    }
    function maybeFadeIn() {
        if (fadeStarted || unlocked || !lockObj.locked || !lockObj.secure || !drew)
            return;
        fadeStarted = true;
        if (shown < 1)
            fadeIn.start();
        else
            xrayOff.running = onHyprland;
    }
    Timer {
        id: drawWait
        interval: 300
        onTriggered: {
            root.drew = true;
            root.maybeFadeIn();
        }
    }

    // a suspend is next (lock.sh --instant while this one is still fading in)
    function showNow() {
        if (unlocked)
            return;
        fadeIn.stop();
        fadeStarted = true;
        shown = 1;
        xrayOff.running = onHyprland;
    }

    function startFadeOut() {
        if (fadingOut || !unlocked)
            return;
        fadingOut = true;
        fadeOutAnyway.stop();
        wake.stop();
        fadeIn.stop();
        fadeOut.start();
    }

    IpcHandler {
        target: "lock"

        // fade in
        function lock(): void {
            root.lockScreen(false);
        }

        // at once (or finish a fade that is still going)
        function now(): void {
            root.lockScreen(true);
        }
    }

    // the right password: tell lock.sh (so it never falls back to hyprlock
    // after this), fade out, unlock
    function unlock() {
        if (unlocked)
            return;
        unlocked = true;
        busy = false;
        pending = "";
        // "unlocking", not "unlocked" yet: lock.sh must not stop Hyprland drawing
        // the desktop under the lock screen while it still fades out
        writeState("unlocking");
        // the desktop has to be drawn under the lock screen before it fades out
        if (onHyprland) {
            xrayOn.running = true;
            fadeOutAnyway.start();
        } else {
            startFadeOut();
        }
    }

    function release() {
        lockObj.locked = false;
        released.start();
    }

    // the fade is over and the unlock has reached Hyprland: now tell lock.sh
    Timer {
        id: released
        interval: 150
        onTriggered: {
            root.writeState("unlocked");
            if (root.resident) {
                root.keepWarm = true;
                refreshWarm.restart();
            } else {
                Qt.quit();
            }
        }
    }

    Timer {
        id: quitTimer
        interval: 200           // lets the "unlock" reach the compositor first
        onTriggered: Qt.quit()
    }

    // a PAM check never takes this long (a wrong password: ~2 s): give the field back
    Timer {
        interval: 15000
        running: root.busy
        onTriggered: {
            pam.abort();
            root.fail();
        }
    }

    PamContext {
        id: pam

        // PAM asks for the password (and maybe more): answer with what was typed
        onPamMessage: {
            if (responseRequired) {
                respond(root.pending);
                root.pending = "";
            }
        }
        onCompleted: result => {
            if (result === PamResult.Success)
                root.unlock();
            else
                root.fail();
        }
        onError: () => root.fail()
    }

    // ── the lock itself ───────────────────────────────────────────────────
    WlSessionLock {
        id: lockObj
        locked: false           // lockScreen() locks

        // the lock ended without the password (another locker took over)
        onLockStateChanged: {
            if (!locked && !root.unlocked) {
                root.writeState("ended");
                if (!root.resident)
                    quitTimer.start();
            }
        }

        // Hyprland confirmed the lock: it is on every screen now
        onSecureStateChanged: {
            if (secure) {
                root.writeState("locked");
                drawWait.restart();
                root.maybeFadeIn();
            }
        }

        WlSessionLockSurface {
            // see-through, so the desktop shows while the lock screen fades
            // (Quickshell: transparent window + a coloured item on it)
            color: "transparent"

            Item {
                id: face
                anchors.fill: parent
                opacity: root.shown
                // while it fades, the lock screen fades as one picture: otherwise its
                // dark grey base shines through the wallpaper on it for a moment
                layer.enabled: root.shown < 1

                // the first frame is on the screen
                Connections {
                    target: face.Window.window
                    enabled: !root.drew
                    function onFrameSwapped() {
                        root.surfaceDrew();
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: root.solidBase
                }

                LockView {
                    anchors.fill: parent
                    lock: root
                }
            }
        }
    }
}
