pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  IconPacks.qml - the icon pack of the apps in the shell: the dock, the
//  launcher, the app switcher, the notifications and the Settings app's lists.
//  Picked on the Settings app's Appearance page ("App icons"), kept in
//  Store.iconPack ("" = the shell's own theme).
//
//  The shell's own icon theme is YAMIS (`//@ pragma IconTheme YAMIS` at the top
//  of shell.qml): Qt finds its icons (Quickshell.iconPath). Qt can't switch to
//  another theme while the shell runs, so for the others scripts/icon-index.py
//  lists the files of the pack's icons (with the themes it builds on, hicolor -
//  where apps put their own icons - and /usr/share/pixmaps), and the shell shows
//  those files. The list is made once such a pack is in use (when the shell
//  starts, or when you pick it), when the Settings app's Appearance page opens
//  and again when apps come or go. Only the shell's icons change: GTK and Qt
//  apps keep the icon theme they are set to (README, section 6).
//
//    path(name)          the picture of icon `name` in the pack in use ("" if it
//                        has none: AppIcon then shows the app's first letter)
//    pathIn(name, pack)  the same in another pack (the Settings app's previews)
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    // the packs to pick from: `name` is the theme's folder (in /usr/share/icons or
    // ~/.local/share/icons), `title` what the Settings app calls it (else its name),
    // `about` what it says about it. Papirus: its Dark variant (the same app icons; the
    // small ones, as in notifications, light for a dark shell)
    readonly property var packs: [
        {
            name: "YAMIS",
            about: "Monochrome, in one colour"
        },
        {
            name: "Adwaita",
            about: "The apps' own icons"
        },
        {
            name: "Papirus-Dark",
            title: "Papirus",
            about: "Flat and colourful"
        }
    ]

    // the theme Qt started with: shell.qml's IconTheme pragma
    FileView {
        id: shellFile
        path: Quickshell.shellPath("shell.qml")
        blockLoading: true
        printErrors: false
    }
    readonly property string qtTheme: {
        const m = (shellFile.text() || "").match(/^\/\/@ pragma IconTheme (\S+)/m);
        return m ? m[1] : "YAMIS";
    }

    // what icon-index.py found: { name: { found, dirs, icons } } (dirs and icons not for
    // qtTheme): icon n is the file dirs[icons[n] / 3] + "/" + n + one of the three endings
    property var found: ({})
    property bool scanned: false

    // a pack can be picked when it is installed (until the scan is done: when it is listed)
    function available(name) {
        if (!packs.some(p => p.name === name))
            return false;
        const f = found[name];
        return f ? f.found : !scanned;
    }

    // the pack in use
    readonly property string current: {
        const want = Store.iconPack || "";
        return want !== "" && want !== qtTheme && available(want) ? want : qtTheme;
    }

    function path(name) {
        return pathIn(name, current);
    }

    function pathIn(name, pack) {
        if (!name)
            return "";
        // a file instead of a name, and the shell's own theme: as before, Qt finds them
        if (pack === qtTheme || name.charAt(0) === "/")
            return Quickshell.iconPath(name, true);
        const f = found[pack];
        if (!f || !f.icons || !f.dirs)
            return "";
        // like Qt: "foo-bar-baz" not there, then "foo-bar", then "foo"
        let n = name;
        while (true) {
            const v = Object.prototype.hasOwnProperty.call(f.icons, n) ? f.icons[n] : undefined;
            if (typeof v === "number" && f.dirs[Math.floor(v / 3)] !== undefined) {
                const file = f.dirs[Math.floor(v / 3)] + "/" + n + [".svg", ".png", ".xpm"][v % 3];
                return "file://" + file.split("/").map(encodeURIComponent).join("/");
            }
            const dash = n.lastIndexOf("-");
            if (dash <= 0)
                return "";
            n = n.slice(0, dash);
        }
    }

    // a few icons for a pack's preview: the dock's pinned apps first, then apps most
    // people have, up to `count` (only apps that are installed)
    function samples(count) {
        const out = [];
        const add = id => {
            const e = id ? DesktopEntries.byId(id) : null;
            if (e && e.icon && out.indexOf(e.icon) < 0 && out.length < count)
                out.push(e.icon);
        };
        const pinned = Store.dockPinned || [];
        for (let i = 0; i < pinned.length; i++)
            add(pinned[i]);
        const common = ["firefox", "org.gnome.Nautilus", "kitty", "org.gnome.TextEditor", "io.missioncenter.MissionCenter", "org.gnome.Calculator", "io.github.celluloid_player.Celluloid"];
        for (let i = 0; i < common.length; i++)
            add(common[i]);
        return out;
    }

    // look again (the Settings app's Appearance page asks when it opens)
    function rescan() {
        if (scan.running)
            scanAgain = true;
        else
            scan.running = true;
    }
    property bool scanAgain: false

    Process {
        id: scan
        command: {
            const cmd = ["python3", Quickshell.shellPath("scripts/icon-index.py"), "--check", root.qtTheme];
            for (let i = 0; i < root.packs.length; i++) {
                if (root.packs[i].name !== root.qtTheme)
                    cmd.push(root.packs[i].name);
            }
            return cmd;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.found = JSON.parse(text);
                } catch (e) {
                    root.found = {};
                }
                root.scanned = true;
            }
        }
        onRunningChanged: {
            if (running)
                return;
            root.scanned = true;            // also when it could not run (no python3)
            if (root.scanAgain) {
                root.scanAgain = false;
                running = true;
            }
        }
    }

    // a pack other than the shell's own is picked (also when the saved pick is read)
    readonly property bool wanted: (Store.iconPack || "") !== "" && Store.iconPack !== qtTheme
    onWantedChanged: {
        if (wanted && !scanned)
            rescan();
    }
    Component.onCompleted: {
        if (wanted)
            rescan();
    }

    // an app installed or removed: its icons come or go too (a moment later, once)
    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            rescanTimer.restart();
        }
    }
    Timer {
        id: rescanTimer
        interval: 2000
        onTriggered: {
            if (root.scanned || root.wanted)
                root.rescan();
        }
    }
}
