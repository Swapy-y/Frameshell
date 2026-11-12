pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Presets.qml - your look saved under a name (the Settings app's Presets page):
//  the island's and the dock's switches (Auto hide, Notch mode), the wallpaper,
//  the colour theme, the Appearance page (the borders, the corner rounding, the
//  window gap, the power button and the app icons) and the Blur page. A click on
//  one sets all of them at once. The pinned apps, the devices and the
//  notifications are not part of a preset.
//
//  Two come with the shell (`builtIn`, below): "Default" - the shell as it is
//  installed - and "Swapy". The ones you save are kept in
//  ~/.local/state/frameshell/presets.json ({ "presets": [{ "name", "values" }] }).
//
//    list            the presets: the shell's first, then yours in the order you saved them
//    now             the settings as they are now, as a preset's `values`
//    matches(p)      are the settings now the same as preset p's (the page rings it)
//    apply(p)        preset p's settings become the ones in use
//    save(name)      the settings now become your preset `name` (the same name saves over
//                    it); "" if done, else why not
//    remove(name)    your preset `name` is deleted
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    // ── what a preset holds ───────────────────────────────────────────────
    //   islandAutoHide, dockAutoHide, dockNotch, powerLogo   Store (switches)
    //   iconPack                                            Store ("" = the shell's own, YAMIS)
    //   wallpaper                                           a picture of the wallpapers folder by its
    //                                                       file name (any other: its whole path)
    //   theme                                               the name of a theme in Config.themes
    //   frameBorder, windowBorder, windowGap, cornerRounding  Config (px)
    //   windowBlur, shellBlur, shellOpacity, blurSize, blurPasses, blurBrightness, blurContrast
    //                                                       Config (the Blur page)
    readonly property var storeKeys: ["islandAutoHide", "dockAutoHide", "dockNotch", "powerLogo"]
    readonly property var blurKeys: ["windowBlur", "shellBlur", "shellOpacity", "blurSize", "blurPasses", "blurBrightness", "blurContrast"]

    // the shell as it is installed: the defaults of Store.qml and Config.qml (the window gap
    // and the corner rounding: WINDOW_GAP in hyprland.lua and cornerRadius, as before you
    // move their sliders)
    readonly property var defaults: ({
            islandAutoHide: false,
            dockAutoHide: false,
            dockNotch: false,
            powerLogo: true,
            iconPack: "",
            wallpaper: wallKey(Config.wallpaper),
            theme: "Default",
            frameBorder: 2,
            windowBorder: 2,
            windowGap: Config.hyprWindowGap,
            cornerRounding: Config.cornerRadius,
            windowBlur: true,
            shellBlur: false,
            shellOpacity: 0.8,
            blurSize: 7,
            blurPasses: 2,
            blurBrightness: 1.0,
            blurContrast: 0.9
        })

    // the presets that come with the shell (they can't be deleted or saved over)
    readonly property var builtIn: [
        {
            name: "Default",
            builtIn: true,
            values: defaults
        },
        {
            name: "Swapy",
            builtIn: true,
            values: Object.assign({}, defaults, {
                frameBorder: 1,
                wallpaper: "blue-waves.png",
                theme: "Noir",
                iconPack: "Papirus-Dark",
                blurPasses: 1,
                blurBrightness: 0.75,
                blurContrast: 1.0
            })
        }
    ]

    // yours, as presets.json has them (a broken entry is left out)
    readonly property var saved: (adapter.presets || []).filter(p => p && typeof p.name === "string" && p.name.trim() !== "" && p.values && typeof p.values === "object").map(p => ({
                name: p.name.trim(),
                builtIn: false,
                values: p.values
            }))

    readonly property var list: builtIn.concat(saved)

    // the icon pack as a preset keeps it: "" for the shell's own
    function packKey(pack) {
        const p = pack || "";
        return p === IconPacks.qtTheme ? "" : p;
    }

    // the wallpaper as a preset keeps it: a picture of the wallpapers folder by its file
    // name (so it still works if the folder moves), any other by its path - and back
    function wallKey(path) {
        const dir = Config.wallpaperDir + "/";
        const p = path || "";
        return p.startsWith(dir) && p.indexOf("/", dir.length) < 0 ? p.slice(dir.length) : p;
    }
    function wallPath(key) {
        const k = key || "";
        return k === "" || k.startsWith("/") ? k : Config.wallpaperDir + "/" + k;
    }

    // ── the settings now ─────────────────────────────────────────────────
    readonly property var now: ({
            islandAutoHide: Store.islandAutoHide,
            dockAutoHide: Store.dockAutoHide,
            dockNotch: Store.dockNotch,
            powerLogo: Store.powerLogo,
            iconPack: packKey(Store.iconPack),
            wallpaper: wallKey(Wallpapers.current),
            theme: Config.theme.name,
            frameBorder: Config.frameBorder,
            windowBorder: Config.windowBorder,
            windowGap: Config.windowGap,
            cornerRounding: Config.cornerRounding,
            windowBlur: Config.windowBlur,
            shellBlur: Config.shellBlur,
            shellOpacity: Config.shellOpacity,
            blurSize: Config.blurSize,
            blurPasses: Config.blurPasses,
            blurBrightness: Config.blurBrightness,
            blurContrast: Config.blurContrast
        })

    // every setting a preset has is the same now (numbers: to a thousandth - the
    // sliders' steps of 0.05 are not exact; the icon pack: "" and YAMIS are one; a
    // wallpaper no longer in the folder doesn't count)
    function matches(p) {
        if (!p || !p.values)
            return false;
        const v = p.values;
        const cur = now;
        for (const k in cur) {
            if (v[k] === undefined)
                continue;
            if (k === "wallpaper" && Wallpapers.files.indexOf(wallPath(v[k])) < 0)
                continue;
            const a = k === "iconPack" ? packKey(v[k]) : v[k];
            const b = cur[k];
            if (typeof a === "number" && typeof b === "number") {
                if (Math.abs(a - b) > 0.001)
                    return false;
            } else if (a !== b) {
                return false;
            }
        }
        return true;
    }

    // ── using one ────────────────────────────────────────────────────────
    // only what the preset has, and only values of the right kind (presets.json can be
    // edited by hand). The files are written once all are set (Config.holdWrites says why);
    // the shell hands the lot to Hyprland (modules/HyprSync.qml).
    function apply(p) {
        if (!p || !p.values)
            return;
        Store.holdWrites = true;
        Config.holdWrites = true;
        try {
            setValues(p.values);
        } finally {
            Store.holdWrites = false;
            Config.holdWrites = false;
            Store.write();
            Config.writeSettings();
        }
    }
    function setValues(v) {
        const isNum = x => typeof x === "number" && isFinite(x);
        for (const k of storeKeys) {
            if (typeof v[k] === "boolean" && Store[k] !== v[k])
                Store[k] = v[k];
        }
        if (typeof v.iconPack === "string" && Store.iconPack !== packKey(v.iconPack))
            Store.iconPack = packKey(v.iconPack);
        // only a picture still in the folder (Wallpapers.set() checks); it fades in as when you
        // pick it, and the lock and login screens get it too
        if (typeof v.wallpaper === "string" && v.wallpaper !== "")
            Wallpapers.set(wallPath(v.wallpaper));
        if (typeof v.theme === "string")
            Themes.set(v.theme);
        if (isNum(v.frameBorder) && Config.frameBorder !== Math.max(0, Math.round(v.frameBorder)))
            Config.frameBorder = Math.max(0, Math.round(v.frameBorder));
        if (isNum(v.windowBorder) && Config.windowBorder !== Math.max(0, Math.round(v.windowBorder)))
            Config.windowBorder = Math.max(0, Math.round(v.windowBorder));
        if (isNum(v.windowGap) && Config.windowGap !== Math.max(0, Math.round(v.windowGap)))
            Config.setWindowGap(v.windowGap);
        if (isNum(v.cornerRounding) && Config.cornerRounding !== Math.max(0, Math.round(v.cornerRounding)))
            Config.setCornerRounding(v.cornerRounding);
        for (const k of blurKeys) {
            const x = v[k];
            if (typeof Config[k] === "boolean" ? typeof x === "boolean" : isNum(x)) {
                if (Config[k] !== x)
                    Config[k] = x;
            }
        }
    }

    // ── saving and deleting yours ─────────────────────────────────────────
    function isBuiltIn(name) {
        const n = (name || "").trim().toLowerCase();
        return builtIn.some(p => p.name.toLowerCase() === n);
    }

    function save(name) {
        const n = (name || "").trim();
        if (n === "")
            return "Type a name for it first.";
        if (isBuiltIn(n))
            return "“" + n + "” comes with the shell - pick another name.";
        // a copy of the settings now (not the live object)
        const values = JSON.parse(JSON.stringify(now));
        const all = (adapter.presets || []).slice();
        const at = all.findIndex(p => p && typeof p.name === "string" && p.name.trim().toLowerCase() === n.toLowerCase());
        if (at >= 0)
            all[at] = {
                name: n,
                values: values
            };
        else
            all.push({
                name: n,
                values: values
            });
        adapter.presets = all;
        return "";
    }

    function remove(name) {
        const n = (name || "").trim().toLowerCase();
        adapter.presets = (adapter.presets || []).filter(p => !(p && typeof p.name === "string" && p.name.trim().toLowerCase() === n));
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/frameshell/presets.json"
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: adapter
            property var presets: []
        }
    }
}
