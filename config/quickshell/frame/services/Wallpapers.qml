pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Wallpapers.qml - the wallpapers you can switch between (SUPER + CTRL + Left /
//  Right, the switcher in the island, from the first to the last) and the one you picked.
//
//  Each colour theme has its own: the pictures in its folder of
//  ~/.local/share/frameshell/wallpapers (Config.themeWallpaperDir(): Default,
//  Noir, TokyoNight ...), in the order of their file names - drop a picture in
//  there (or add one in the Settings app, which adds it to the theme in use)
//  and it is in the switcher. Only the theme in use's pictures are listed
//  (`files`): a theme without any uses Default's, and without those (an
//  install from before the folders) the pictures right in the wallpapers folder.
//
//  Switching the theme switches the wallpaper to that theme's: the one you
//  picked for it last time (`picks`, ~/.local/state/frameshell/wallpapers.json),
//  else its own (Config.themeWallpapers), else its first picture.
//
//  The Settings app can also pick the wallpaper (set()) and remove the pictures
//  you added (remove(); the ones that come with frameshell stay: `bundled`). The
//  one on screen is kept in ~/.local/state/frameshell/wallpaper; scripts/
//  wallpaper.sh writes it and gives the login screen the same picture. The lock
//  screen reads that file too (modules/Lock.qml).
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/frameshell"
    readonly property string stateFile: stateDir + "/wallpaper"

    // ── the pictures, sorted by file name ─────────────────────────────────
    // the theme in use (Config.theme: an old name already mapped to its new one)
    readonly property string themeName: Config.theme.name
    readonly property string themeDir: Config.themeWallpaperDir(themeName)
    readonly property string defaultDir: Config.themeWallpaperDir("Default")
    // where pictures added in the Settings app go: the theme's own folder
    readonly property string addDir: themeDir

    property var files: []
    property bool listed: false

    // one folder's pictures (`paths`); `updated` when they are read
    component Folder: FolderListModel {
        property var paths: []
        // Ready, or the folder is missing (it never gets Ready then: Timer below)
        property bool done: false
        property string dir
        signal updated
        folder: "file://" + dir
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        caseSensitive: false
        showDirs: false
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name
        onDirChanged: {
            done = false;
            paths = [];             // not the last folder's while this one is read
        }
        onStatusChanged: read()
        onCountChanged: read()
        function read() {
            if (status !== FolderListModel.Ready)
                return;
            const out = [];
            for (let i = 0; i < count; i++)
                out.push(get(i, "filePath"));
            paths = out;
            done = true;
            updated();
        }
    }

    Folder {
        id: themeFolder
        dir: root.themeDir
        onUpdated: root.list()
    }
    Folder {
        id: defaultFolder
        dir: root.defaultDir
        onUpdated: root.list()
    }
    // the folder itself: where the pictures were before each theme had its own
    Folder {
        id: rootFolder
        dir: Config.wallpaperDir
        onUpdated: root.list()
    }

    // a folder that is not there never says it is Ready: after a moment it counts as empty
    Timer {
        id: missing
        interval: 1500
        running: true
        onTriggered: {
            for (const f of [themeFolder, defaultFolder, rootFolder])
                f.done = true;
            root.list();
        }
    }
    onThemeDirChanged: missing.restart()

    function list() {
        if (!themeFolder.done)
            return;                                       // the theme's folder first
        let out = themeFolder.paths;
        if (out.length === 0 && root.themeDir !== root.defaultDir)
            out = defaultFolder.paths;
        if (out.length === 0)
            out = rootFolder.paths;
        if (JSON.stringify(out) !== JSON.stringify(files))
            files = out;
        listed = true;
        settle();
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

    // the one picked for each theme: { "Tokyo Night": "/home/.../TokyoNight/x.png", ... }
    property bool picksRead: false
    FileView {
        id: picksFile
        path: root.stateDir + "/wallpapers.json"
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            root.picksRead = true;
            root.settle();
        }
        onLoadFailed: {
            root.picksRead = true;
            root.settle();
        }

        adapter: JsonAdapter {
            id: picks
            property var byTheme: ({})
        }
    }
    function remember(path) {
        if (picks.byTheme[root.themeName] === path)
            return;
        const o = Object.assign({}, picks.byTheme);
        o[root.themeName] = path;
        picks.byTheme = o;
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

    // a picture of the list: that path, else one of the same file name (a preset kept
    // from before each theme had its folder: "meadow.png"); "" if none
    function find(path) {
        const p = path || "";
        if (p === "")
            return "";
        if (files.indexOf(p) >= 0)
            return p;
        const name = p.slice(p.lastIndexOf("/") + 1);
        return files.find(f => f.slice(f.lastIndexOf("/") + 1) === name) || "";
    }

    // a wallpaper asked for before its theme's pictures are listed (a preset switches
    // the theme and the wallpaper at once): taken when they are, if it is one of them
    property string pending: ""
    Timer {
        id: pendingTimeout
        interval: 3000
        onTriggered: root.pending = ""
    }

    // the theme the list was last settled for
    property string settledFor: ""

    // the right picture for the theme's list: one asked for (a preset); after the theme
    // changed, the one you picked for it; the one on screen if it is in the list; else
    // your pick of the last start, the one you picked for the theme, the theme's own
    // (Config.themeWallpapers), Default's default, the first picture
    function settle() {
        if (!listed || !savedRead || !picksRead)
            return;
        const themeChanged = settledFor !== "" && settledFor !== themeName;
        settledFor = themeName;
        const asked = find(pending);
        if (asked !== "") {
            pending = "";
            if (asked !== current) {
                current = asked;
                remember(asked);
                save.restart();
            }
            return;
        }
        // a theme without pictures of its own shows Default's: back on Default (or on
        // another such theme) the picture on screen may be in the list too, but the one
        // picked for this theme comes back
        const picked = find(picks.byTheme[themeName] || "");
        if (themeChanged && picked !== "" && picked !== current) {
            current = picked;
            save.restart();
            return;
        }
        if (files.indexOf(current) >= 0)
            return;                                       // still there: keep it
        const before = current;
        const pick = picks.byTheme[themeName] || "";
        if (files.length === 0)
            current = legacy;
        else if (before === "" && files.indexOf(saved) >= 0)
            current = saved;
        else if (find(pick) !== "")
            current = find(pick);
        else if (files.indexOf(Config.themeWallpaper(themeName)) >= 0)
            current = Config.themeWallpaper(themeName);
        else if (files.indexOf(Config.wallpaper) >= 0)
            current = Config.wallpaper;
        else
            current = files[0];
        // the theme changed (or the picture was deleted): the lock and login screens follow
        if (before !== "" && current !== before)
            save.restart();
    }

    // ── switching ─────────────────────────────────────────────────────────
    // SUPER + CTRL + Left / Right move through the pictures, from the first to the last
    // (no loop: past either end nothing happens); the desktop does not
    // change yet. Enter makes the one in the middle the wallpaper
    // (Ui.applySwitcher() calls apply()).
    //
    // `cursor`: the picture the switcher is on, files[cursor].
    property int cursor: 0
    readonly property int selectedIndex: count > 0 ? Math.max(0, Math.min(count - 1, cursor)) : -1
    readonly property string selected: selectedIndex >= 0 ? files[selectedIndex] : ""
    signal jumped                       // the cursor moved without sliding: the strip follows at once

    // the switcher opens: start at the wallpaper on screen
    function startBrowsing() {
        cursor = Math.max(0, index);
        jumped();
    }

    // SUPER + CTRL + Right = +1, SUPER + CTRL + Left = -1
    function browse(direction) {
        const next = selectedIndex + direction;
        if (next >= 0 && next < count)
            cursor = next;          // past the first / last: nothing happens
    }

    // a click on a picture `offset` places beside the middle one
    function browseBy(offset) {
        if (count > 0)
            cursor = Math.max(0, Math.min(count - 1, selectedIndex + offset));
    }

    // the picture the switcher is on becomes the wallpaper
    function apply() {
        if (selected.length === 0 || selected === current)
            return;
        current = selected;
        remember(current);
        save.restart();
    }

    // a picture of the list becomes the wallpaper (the Settings app)
    function set(path) {
        if (files.indexOf(path) < 0 || path === current)
            return;
        current = path;
        remember(current);
        save.restart();
    }

    // a preset's wallpaper: at once if it is one of the theme's pictures, else as soon
    // as its theme's are listed (the preset switches the theme too)
    function request(path) {
        const found = find(path);
        if (found !== "" && themeFolder.done && themeFolder.dir === themeDir) {
            pending = "";
            set(found);
        } else {
            pending = path || "";
            pendingTimeout.restart();
            settle();
        }
    }

    // ── adding pictures ───────────────────────────────────────────────────
    // The Settings app's "Add" tile: scripts/wallpaper-add.sh opens a file dialog
    // and copies the pictures you pick into the theme's folder, where they show up.
    readonly property bool adding: adder.running
    function add() {
        if (!adder.running)
            adder.running = true;
    }
    Process {
        id: adder
        command: ["bash", Quickshell.shellPath("scripts/wallpaper-add.sh"), root.addDir]
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
            Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/wallpaper-add.sh"), root.addDir].concat(paths));
        else
            Quickshell.execDetached(["notify-send", "-a", "Settings", "-i", "preferences-desktop-wallpaper", "Wallpaper", "Only pictures on this computer can be added (PNG, JPEG or WebP)."]);
        return paths.length;
    }

    // ── removing pictures ─────────────────────────────────────────────────
    // The pictures that come with frameshell (its wallpapers folder; install.sh puts
    // them here): they stay. The Settings app removes only the ones you added.
    readonly property var bundled: ["0-winding-road.png", "3-sunset-lake.png", "arch-blue.png", "black-hole.png", "blackv2.png", "blue-waves.png", "chrome-hud.png", "crane.png", "dark-bloom.png", "everblush-5.png", "everforest.png", "fog_forest_1.png", "gruvbox.png", "kanagava1.png", "kanagawa.png", "marine-tunnel.png", "meadow.png", "night-clouds.png", "nord.png", "nord1.png", "nord2.png", "power-lines.png", "rose-pine2.png", "ship-2.png", "sky-town.png", "summer-clouds.png", "tokyo-night.png"]

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
