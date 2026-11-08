pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Profile.qml - your picture and your name, as the lock screen and the login
//  screen show them, for the Settings app's Profile card (System page) - where
//  you change them too (scripts/profile.sh).
//
//    picture   ~/.face (what GNOME, KDE and SDDM use), else ~/.face.icon, else
//              the login theme's assets/avatar.jpg; a new one is cut square in
//              the middle, 512 px, and saved to ~/.face and to the login screen's
//              copy (Settings.qml does the cutting: it needs a window); taken away
//              (resetPicture), the lock and login screen show the first letter of
//              your name again
//    name      your full name in /etc/passwd (else your user name), like SDDM:
//              a new one with pkexec usermod, which asks for your password
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") || "user"
    property string realName: ""
    // like the lock and login screen: the full name, else the user name ("-" and "_" become spaces)
    readonly property string shownName: {
        let s = realName.length > 0 ? realName : user;
        s = s.replace(/[-_]/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    property string picture: ""             // its file ("": none)
    property string pictureStamp: ""        // its time: a new picture in the same file is read again
    readonly property string pictureUrl: picture.length > 0 ? "file://" + picture + "?" + pictureStamp : ""

    property bool busy: false               // a picture or a name is being saved (or a picture taken away)
    property string busyText: ""            // what it is doing meanwhile ("Saving...", "Removing...")
    property string message: ""             // how the last change went, when worth saying

    function refresh() {
        passwd.reload();
        if (!probe.running)
            probe.running = true;
    }

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
                    return;
                }
            }
            root.realName = "";
        }
    }

    // line 1: the picture's file, line 2: its time
    Process {
        id: probe
        command: ["sh", "-c", 'for f in "$HOME/.face" "$HOME/.face.icon" "$1/assets/avatar.jpg"; do ' +
            'if [ -r "$f" ] && [ -s "$f" ]; then printf "%s\\n%s\\n" "$f" "$(stat -c %Y "$f" 2>/dev/null)"; exit 0; fi; done', "sh", Config.lockTheme]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.picture = (lines[0] || "").trim();
                root.pictureStamp = (lines[1] || "").trim();
                root.refreshed();
            }
        }
    }
    signal refreshed                        // the picture was looked for again

    Component.onCompleted: refresh()

    // ── a new picture ─────────────────────────────────────────────────────
    // pickPicture() opens the file dialog; the picture you pick comes back in `picked`,
    // Settings.qml cuts it square and hands the two files to savePicture()
    signal picked(string path)

    function pickPicture() {
        if (busy || pick.running)
            return;
        message = "";
        pick.running = true;
    }
    Process {
        id: pick
        command: ["bash", Quickshell.shellPath("scripts/profile.sh"), "pick"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim().split("\n")[0] || "";
                if (path.length > 0)
                    root.picked(path);
            }
        }
    }

    function savePicture(png, jpg) {
        busy = true;
        busyText = "Saving...";
        loginCopied = false;
        pictureSave.command = ["bash", Quickshell.shellPath("scripts/profile.sh"), "picture", png, jpg, Config.lockTheme];
        pictureSave.running = true;
    }
    Process {
        id: pictureSave
        stdout: StdioCollector {
            onStreamFinished: root.loginCopied = text.indexOf("login") >= 0
        }
        onExited: code => {
            root.busy = false;
            if (code !== 0)
                root.message = "Could not save the picture.";
            else if (!root.loginCopied)
                root.message = "The login screen keeps its picture until you run ./install.sh again.";
            root.refresh();
        }
    }
    property bool loginCopied: false

    // no picture any more: ~/.face and ~/.face.icon go to the trash, the login screen's
    // copy is emptied (it then shows the first letter of your name too)
    function resetPicture() {
        if (busy) {
            refreshed();
            return;
        }
        busy = true;
        busyText = "Removing...";
        loginCopied = false;
        message = "";
        pictureReset.command = ["bash", Quickshell.shellPath("scripts/profile.sh"), "reset", Config.lockTheme];
        pictureReset.running = true;
    }
    Process {
        id: pictureReset
        stdout: StdioCollector {
            onStreamFinished: root.loginCopied = text.indexOf("login") >= 0
        }
        onExited: code => {
            root.busy = false;
            if (code !== 0)
                root.message = "Could not take the picture away.";
            else if (!root.loginCopied)
                root.message = "The login screen keeps its picture until you run ./install.sh again.";
            root.refresh();
        }
    }

    // ── a new name ────────────────────────────────────────────────────────
    // only what /etc/passwd can hold: no ":" or "," (they divide its fields), one line
    function cleanName(name) {
        return String(name || "").replace(/[:,\x00-\x1f\x7f]/g, " ").replace(/\s+/g, " ").trim().slice(0, 64);
    }

    function setName(name) {
        const n = cleanName(name);
        if (busy || n === realName)
            return;
        busy = true;
        busyText = "Saving...";
        message = "";
        nameSave.command = ["bash", Quickshell.shellPath("scripts/profile.sh"), "name", n];
        nameSave.running = true;
    }
    Process {
        id: nameSave
        onExited: code => {
            root.busy = false;
            if (code === 126 || code === 127)
                root.message = "The name was not changed: it needs your password.";
            else if (code === 3)
                root.message = "Changing the name needs polkit (pkexec).";
            else if (code !== 0)
                root.message = "Could not change the name.";
            root.refresh();
        }
    }
}
