pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Apps.qml - the running windows (from the compositor's toplevel list):
//  most-recently-used order for the app switcher (Super+Space), name/icon
//  lookup, focus, close, and bringing back minimized windows - and the dock's
//  pinned apps (the Settings app's Dock page, Store.dockPinned).
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    // every window, in the order they were opened
    readonly property var list: ToplevelManager.toplevels.values
    readonly property var focused: ToplevelManager.activeToplevel

    // most recently used first (used by the app switcher)
    property var mru: []
    readonly property var ordered: {
        const present = list;
        const out = [];
        for (let i = 0; i < mru.length; i++) {
            if (present.indexOf(mru[i]) >= 0)
                out.push(mru[i]);
        }
        for (let j = 0; j < present.length; j++) {
            if (out.indexOf(present[j]) < 0)
                out.push(present[j]);
        }
        return out;
    }

    function touch(t) {
        if (!t)
            return;
        const present = list;
        const next = [t];
        for (let i = 0; i < mru.length && next.length < 64; i++) {
            if (mru[i] !== t && present.indexOf(mru[i]) >= 0)
                next.push(mru[i]);
        }
        mru = next;
    }

    Connections {
        target: ToplevelManager

        function onActiveToplevelChanged() {
            root.touch(ToplevelManager.activeToplevel);
        }
    }

    Component.onCompleted: {
        touch(ToplevelManager.activeToplevel);
        syncPinned();
    }

    // The shell's own Settings window (modules/Settings.qml). Its app id is the
    // shell's, "org.quickshell"; it is told apart by its title.
    function isSettings(t) {
        return !!t && t.appId === "org.quickshell" && t.title === "Settings";
    }

    // { name, icon } for a toplevel. `icon` is a file path or "" when nothing was found.
    function info(t) {
        if (isSettings(t)) {
            // its icon: install.sh puts it in ~/.local/share/icons (frame-settings.svg);
            // until then the copy in the shell's assets
            const path = IconPacks.path("frame-settings");
            return {
                name: "Settings",
                icon: path.length > 0 ? path : Qt.resolvedUrl("../assets/icons/frame-settings.svg").toString()
            };
        }
        const id = t && t.appId ? t.appId : "";
        const entry = id.length > 0 ? DesktopEntries.heuristicLookup(id) : null;
        let name = entry && entry.name ? entry.name : prettify(id);
        if (name.length === 0)
            name = t && t.title ? t.title : "Window";
        // look in the icon pack (IconPacks): the .desktop file's icon first, then the window's app id
        let icon = "";
        if (entry && entry.icon)
            icon = IconPacks.path(entry.icon);
        if (icon.length === 0 && id.length > 0)
            icon = IconPacks.path(id);
        if (icon.length === 0 && id.length > 0)
            icon = IconPacks.path(id.toLowerCase());
        return {
            name: name,
            icon: icon
        };
    }

    function prettify(id) {
        if (!id)
            return "";
        let s = id;
        const dot = s.lastIndexOf(".");
        if (dot >= 0 && dot < s.length - 1)
            s = s.slice(dot + 1);
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // Hyprland has no minimized state: SUPER+H ("Minimize window", hyprland.lua)
    // moves the window to this hidden workspace instead.
    readonly property string minimizedWorkspace: "special:minimized"

    // Hyprland's own record of a window (workspace, address), or null
    function hyprlandOf(t) {
        if (!t)
            return null;
        const hts = Hyprland.toplevels.values;
        for (let i = 0; i < hts.length; i++) {
            if (hts[i].wayland === t)
                return hts[i];
        }
        return null;
    }

    function isMinimized(t) {
        const h = hyprlandOf(t);
        return !!(h && h.workspace && h.workspace.name === minimizedWorkspace);
    }

    // Focus a window. On Hyprland this goes through the focus dispatcher so the
    // workspace switches too; otherwise it uses the protocol request. A
    // minimized window is first brought back to the workspace you are on:
    // hyprland.lua's frameshell_restore() opens it like a new app (it fades in
    // and grows into its place); with an older hyprland.lua it is simply moved.
    // With hyprland.lua's frameshell_activate() Hyprland itself tells which it
    // is: what the shell knows of a window's workspace can be a moment late, and
    // focusing a window still in the hidden workspace would show that workspace.
    function activate(t) {
        if (!t)
            return;
        const h = hyprlandOf(t);
        if (h && h.address) {
            const addr = "address:0x" + h.address;
            if (Hyprland.usingLua) {
                let fallback = 'hl.dsp.focus({ window = "' + addr + '" })';
                if (isMinimized(t)) {
                    const ws = Hyprland.focusedWorkspace;
                    const here = ws && ws.id > 0 ? ws.id : 1;
                    fallback = 'frameshell_restore and frameshell_restore("0x' + h.address + '") or hl.dsp.window.move({ window = "' + addr + '", workspace = ' + here + ' })';
                }
                Hyprland.dispatch('frameshell_activate and frameshell_activate("0x' + h.address + '") or ' + fallback);
                return;
            }
            if (isMinimized(t)) {
                const ws = Hyprland.focusedWorkspace;
                Hyprland.dispatch("movetoworkspace " + (ws && ws.id > 0 ? ws.id : 1) + "," + addr);
            }
            Hyprland.dispatch("focuswindow " + addr);
            return;
        }
        t.activate();
    }

    // Focus a window that is already in place (no bringing back from minimized -
    // but with frameshell_activate one that turns out to be minimized still comes back
    // instead of its hidden workspace showing).
    function focusOnly(t) {
        const h = hyprlandOf(t);
        if (h && h.address)
            Hyprland.dispatch(Hyprland.usingLua ? 'frameshell_activate and frameshell_activate("0x' + h.address + '") or hl.dsp.focus({ window = "address:0x' + h.address + '" })' : "focuswindow address:0x" + h.address);
        else if (t)
            t.activate();
    }

    function close(t) {
        if (t)
            t.close();
    }

    // ── pinned apps ───────────────────────────────────────────────────────
    // Kept by the id of their .desktop file. The dock shows them first, a line,
    // then the other windows. A pinned app's icon stands for its first window; its
    // other windows (a second terminal) are after the line, like any app's.

    // { name, icon } for a .desktop entry (like the launcher's)
    function entryInfo(e) {
        if (!e)
            return {
                name: "",
                icon: ""
            };
        let icon = e.icon ? IconPacks.path(e.icon) : "";
        if (icon.length === 0 && e.id === "frame-settings")
            icon = Qt.resolvedUrl("../assets/icons/frame-settings.svg").toString();
        return {
            name: e.name ? e.name : e.id,
            icon: icon
        };
    }

    // the .desktop id a window belongs to (else its app id)
    function entryIdOf(t) {
        if (!t)
            return "";
        if (isSettings(t))
            return "frame-settings";            // frame-settings.desktop opens it
        const id = t.appId || "";
        const entry = id.length > 0 ? DesktopEntries.heuristicLookup(id) : null;
        return entry ? entry.id : id;
    }

    // every window with the .desktop id it belongs to, in the order they were opened
    // (again when the apps are read again: a window can then find its .desktop file)
    readonly property var tagged: {
        const apps = DesktopEntries.applications.values;    // (only so this follows the list)
        const out = [];
        for (let i = 0; i < list.length; i++)
            out.push({
                window: list[i],
                id: entryIdOf(list[i])
            });
        return out;
    }

    // the pinned apps that are installed, left to right: [ .desktop entry ]
    // (`pinned` and `unpinned` only change when what is in them changes: the dock
    // makes its icons again when they do)
    property var pinned: []
    property var unpinned: []
    readonly property var pinnedNow: {
        const apps = DesktopEntries.applications.values;
        const ids = Store.dockPinned || [];
        const out = [];
        for (let i = 0; i < ids.length; i++) {
            for (let j = 0; j < apps.length; j++) {
                if (apps[j].id === ids[i]) {
                    if (out.indexOf(apps[j]) < 0)
                        out.push(apps[j]);
                    break;
                }
            }
        }
        return out;
    }
    readonly property var pinnedIds: pinned.map(e => e.id)

    // the windows after the line in the dock: all but the first of each pinned app
    readonly property var unpinnedNow: {
        const ids = pinnedNow.map(e => e.id);
        const taken = {};
        const out = [];
        for (let i = 0; i < tagged.length; i++) {
            const x = tagged[i];
            if (ids.indexOf(x.id) >= 0 && !taken[x.id]) {
                taken[x.id] = true;
                continue;
            }
            out.push(x.window);
        }
        return out;
    }

    function sameItems(a, b) {
        if (a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i])
                return false;
        }
        return true;
    }
    function syncPinned() {
        if (!sameItems(pinned, pinnedNow))
            pinned = pinnedNow;
        if (!sameItems(unpinned, unpinnedNow))
            unpinned = unpinnedNow;
    }
    onPinnedNowChanged: syncPinned()
    onUnpinnedNowChanged: syncPinned()

    // the installed app with this .desktop id (null: none). It follows the list when
    // the apps are read again (each read makes new entries).
    function entryById(id) {
        const apps = DesktopEntries.applications.values;
        for (let i = 0; i < apps.length; i++) {
            if (apps[i].id === id)
                return apps[i];
        }
        return null;
    }

    // the window a pinned app's icon stands for: the first of its windows still
    // open (null: it is not open)
    function pinnedWindowOf(id) {
        for (let i = 0; i < tagged.length; i++) {
            if (tagged[i].id === id)
                return tagged[i].window;
        }
        return null;
    }

    function isPinned(id) {
        return (Store.dockPinned || []).indexOf(id) >= 0;
    }

    function pin(id) {
        if (id && !isPinned(id))
            Store.dockPinned = (Store.dockPinned || []).concat([id]);
    }

    function unpin(id) {
        Store.dockPinned = (Store.dockPinned || []).filter(x => x !== id);
    }

    // one place to the left (-1) or the right (+1). (Pins of apps that are not
    // installed now stay in the list, at its end: they come back with the app.)
    function movePin(id, dir) {
        const ids = pinnedIds.slice();
        const i = ids.indexOf(id);
        const j = i + dir;
        if (i < 0 || j < 0 || j >= ids.length)
            return;
        ids[i] = ids[j];
        ids[j] = id;
        Store.dockPinned = ids.concat((Store.dockPinned || []).filter(x => ids.indexOf(x) < 0));
    }

    // start an app from its .desktop entry (like the launcher)
    function launch(entry) {
        if (!entry)
            return;
        if (entry.runInTerminal)
            Quickshell.execDetached([Config.terminal, "-e"].concat(Array.from(entry.command)));
        else
            entry.execute();
    }
}
