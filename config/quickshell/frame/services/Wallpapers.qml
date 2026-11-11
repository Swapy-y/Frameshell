pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Wallpapers.qml - the wallpapers you can switch between (SUPER + CTRL + Left /
//  Right, the switcher in the island, in a loop) and the one you picked.
//
//  They are the pictures in ~/.local/share/frameshell/wallpapers (Config.
//  wallpaperDir), in the order of their file names: drop a picture in there
//  (or add one in the Settings app) and it is in the switcher. The Settings
//  app can also pick the wallpaper (set()) and remove the pictures you added
//  (remove(); the ones that come with frameshell stay: `bundled`). Your pick is kept in
//  ~/.local/state/frameshell/wallpaper; scripts/wallpaper.sh writes it and
//  gives the login screen the same picture. The lock screen reads that file
//  too (modules/Lock.qml).
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/frameshell/wallpaper"

    // ── the pictures, sorted by file name ─────────────────────────────────
    property var files: []
    property bool listed: false

    FolderListModel {
        id: folder
        folder: "file://" + Config.wallpaperDir
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        caseSensitive: false
        showDirs: false
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name
        onStatusChanged: root.list()
        onCountChanged: root.list()
    }

    function list() {
        if (folder.status !== FolderListModel.Ready)
            return;
        const out = [];
        for (let i = 0; i < folder.count; i++)
            out.push(folder.get(i, "filePath"));
        files = out;
        listed = true;
        settle();
    }

    // no folder at all (an older install): don't wait for it
    Timer {
        interval: 1500
        running: !root.listed
        onTriggered: {
            root.listed = true;
            root.settle();
        }
    }

    // ── the one you picked ────────────────────────────────────────────────
    property string saved: ""
    property bool savedRead: false

    FileView {
        path: root.stateFile
        printErrors: false
        blockLoading: true
        onLoaded: {
            root.saved = text().trim();
            root.savedRead = true;
            root.settle();
        }
        onLoadFailed: {
            root.savedRead = true;
            root.settle();
        }
    }

    // The wallpaper on screen. Empty until it is known: the desktop waits for
    // it before it fades in after logging in.
    property string current: ""
    readonly property bool ready: current.length > 0
    readonly property int index: files.indexOf(current)
    readonly property int count: files.length

    // the one picture of earlier versions (before the folder): used while the
    // folder is missing or empty, e.g. the shell was updated without install.sh
    readonly property string legacy: Quickshell.env("HOME") + "/.local/share/frameshell/wallpaper.png"

    // your pick if it is still there, else the default (Config.wallpaper), else
    // the first picture
    function settle() {
        if (!listed || !savedRead)
            return;
        if (files.indexOf(current) >= 0)
            return;                                       // still there: keep it
        if (files.length === 0)
            current = legacy;
        else if (files.indexOf(saved) >= 0)
            current = saved;
        else if (files.indexOf(Config.wallpaper) >= 0)
            current = Config.wallpaper;
        else
            current = files[0];
    }

    // ── switching ─────────────────────────────────────────────────────────
    // SUPER + CTRL + Left / Right move through the pictures in a loop; the desktop
    // does not change yet. Enter makes the one in the middle the wallpaper
    // (Ui.applySwitcher() calls apply()).
    //
    // `cursor` counts every step and never wraps, so the strip keeps sliding
    // the same way round the loop; it is on files[cursor mod count].
    property int cursor: 0
    readonly property int selectedIndex: count > 0 ? ((cursor % count) + count) % count : -1
    readonly property string selected: selectedIndex >= 0 ? files[selectedIndex] : ""
    signal jumped                       // the cursor moved without sliding: the strip follows at once
    signal bumped(int direction)        // a single picture: nowhere to go (the strip nudges)

    // the switcher opens: start at the wallpaper on screen
    function startBrowsing() {
        cursor = Math.max(0, index);
        jumped();
    }

    // SUPER + CTRL + Right = +1, SUPER + CTRL + Left = -1
    function browse(direction) {
        if (count < 2)
            bumped(direction);
        else
            cursor += direction;
    }

    // a click on a picture `offset` places beside the middle one
    function browseBy(offset) {
        if (count > 0)
            cursor += offset;
    }

    // the picture the switcher is on becomes the wallpaper
    function apply() {
        if (selected.length === 0 || selected === current)
            return;
        current = selected;
        save.restart();
    }

    // a picture of the folder becomes the wallpaper (the Settings app)
    function set(path) {
        if (files.indexOf(path) < 0 || path === current)
            return;
        current = path;
        save.restart();
    }

    // ── adding pictures ───────────────────────────────────────────────────
    // The Settings app's "Add" tile: scripts/wallpaper-add.sh opens a file dialog
    // and copies the pictures you pick into the folder, where they show up.
    readonly property bool adding: adder.running
    function add() {
        if (!adder.running)
            adder.running = true;
    }
    Process {
        id: adder
        command: ["bash", Quickshell.shellPath("scripts/wallpaper-add.sh"), Config.wallpaperDir]
    }

    // the pictures among dropped files (file:// links): their paths
    function picturesIn(urls) {
        const out = [];
        for (const u of urls || []) {
            const s = String(u);
            if (!s.startsWith("file://"))
                continue;
            let path = s.slice(7);
            try {
                path = decodeURIComponent(path);
            } catch (e) {
                continue;
            }
            if (path.startsWith("/") && /\.(png|jpe?g|webp)$/i.test(path))
                out.push(path);
        }
        return out;
    }

    // pictures dropped on the "Add" tile: copied in the same way (no dialog). Anything
    // else dropped there (a link from a browser, another kind of file): a note says so.
    function addDropped(urls) {
        const paths = picturesIn(urls);
        if (paths.length > 0)
            Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/wallpaper-add.sh"), Config.wallpaperDir].concat(paths));
        else
            Quickshell.execDetached(["notify-send", "-a", "Settings", "-i", "preferences-desktop-wallpaper", "Wallpaper", "Only pictures on this computer can be added (PNG, JPEG or WebP)."]);
        return paths.length;
    }

    // ── removing pictures ─────────────────────────────────────────────────
    // The pictures that come with frameshell (its wallpapers folder; install.sh puts
    // them here): they stay. The Settings app removes only the ones you added.
    readonly property var bundled: ["arch-blue.png", "blue-waves.png", "chrome-hud.png", "dark-bloom.png", "meadow.png", "power-lines.png", "sky-town.png"]

    function removable(path) {
        const name = path.slice(path.lastIndexOf("/") + 1);
        return files.length > 1 && files.indexOf(path) >= 0 && path.startsWith(Config.wallpaperDir + "/") && bundled.indexOf(name) < 0;
    }

    // a picture you added: moved to the trash (it can come back from there); the folder
    // then lists it no more. The wallpaper itself: the default takes its place first
    // (else the first picture).
    function remove(path) {
        if (!removable(path))
            return;
        if (path === current) {
            const rest = files.filter(f => f !== path);
            current = rest.indexOf(Config.wallpaper) >= 0 ? Config.wallpaper : rest[0];
            save.restart();
        }
        Quickshell.execDetached(["sh", "-c", 'gio trash -- "$1" 2>/dev/null || rm -f -- "$1"', "sh", path]);
    }

    // remember it and give the login screen the same picture
    Timer {
        id: save
        interval: 300
        onTriggered: {
            if (root.current.length > 0)
                Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/wallpaper.sh"), root.current, Config.lockTheme]);
        }
    }
}
