pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Presets.qml - your look saved under a name (the Settings app's Presets page):
//  the island's and the dock's switches (Auto hide, Notch mode, 10 workspaces,
//  Island popups, Clean dock), the Appearance page's switches for the media, the
//  sliders and the island's icons, the wallpaper,
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
    //   islandDisabled, dockDisabled                        Store (Disable island / dock)
    //   showAllWallpapers                                   Store (the Wallpaper page's "Show all
    //                                                       wallpapers"; set before the wallpaper,
    //                                                       so a preset's picture of another theme
    //                                                       can be found)
    //   iconPack                                            Store ("" = the shell's own, YAMIS)
    //   wallpaper                                           a picture of the wallpapers folder by its
    //                                                       path in it ("Noir/dark-bloom.png"; any
    //                                                       other: its whole path) - one of the
    //                                                       preset's theme's (with Show all
    //                                                       wallpapers: of any theme)
    //                                                       (services/Wallpapers.qml)
    //   theme                                               the name of a theme in Config.themes
    //   windowBorder, windowGap, cornerRounding             Config (px) (a frameBorder of an
    //                                                       older preset is left alone: the frame's
    //                                                       edge is fixed now, Theme.border)
    //   frameOverlay                                        Config (the Appearance page's
    //                                                       "Frame overlay"; a preset saved
    //                                                       before it has framelessOutline,
    //                                                       the other way round: frame())
    //   tenWorkspaces, dynamicPopups, cleanDock             Config (the Island page's "10
    //                                                       workspaces" and "Island popups", the
    //                                                       Dock page's "Clean dock")
    //   detailedMedia, flatSliders, minimalSliders,         Config (the Appearance page's cards:
    //   detailedBattery, glowingIcons                       Detailed media controls, Flat sliders,
    //                                                       Minimalistic sliders block, Detailed
    //                                                       battery icon, Glowing icons)
    //   noButtonOutline                                     Config (the Appearance page's "No
    //                                                       outline buttons")
    //   clickToExpand                                       Config (the Experimental page's
    //                                                       "Click to expand")
    //   switcherWindowInfo                                  Config (the Experimental page's
    //                                                       "More window info in app switcher";
    //                                                       a preset saved before it leaves it as is)
    //   windowBlur, blurSize, blurPasses, blurBrightness, blurContrast
    //                                                       Config (the Blur page)
    readonly property var storeKeys: ["islandAutoHide", "dockAutoHide", "dockNotch", "powerLogo", "islandDisabled", "dockDisabled", "showAllWallpapers"]
    readonly property var switchKeys: ["frameOverlay", "tenWorkspaces", "dynamicPopups", "cleanDock", "detailedMedia", "flatSliders", "minimalSliders", "detailedBattery", "glowingIcons", "noButtonOutline", "clickToExpand", "switcherWindowInfo"]
    readonly property var blurKeys: ["windowBlur", "blurSize", "blurPasses", "blurBrightness", "blurContrast"]

    // the shell as it is installed: the defaults of Store.qml and Config.qml (the window gap
    // and the corner rounding: WINDOW_GAP in hyprland.lua and cornerRadius, as before you
    // move their sliders)
    readonly property var defaults: ({
            islandAutoHide: false,
            dockAutoHide: false,
            dockNotch: false,
            powerLogo: true,
            islandDisabled: false,
            dockDisabled: false,
            showAllWallpapers: false,
            iconPack: "",
            wallpaper: wallKey(Config.wallpaper),
            theme: "Default",
            windowBorder: 2,
            windowGap: Config.hyprWindowGap,
            cornerRounding: Config.cornerRadius,
            frameOverlay: false,
            tenWorkspaces: false,
            dynamicPopups: true,
            cleanDock: false,
            detailedMedia: false,
            flatSliders: false,
            minimalSliders: false,
            detailedBattery: false,
            glowingIcons: false,
            noButtonOutline: false,
            clickToExpand: false,
            switcherWindowInfo: false,
            windowBlur: true,
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
                wallpaper: "Noir/dark-bloom.png",          // Noir's wallpaper
                theme: "Noir",
                iconPack: "Papirus-Dark",
                cleanDock: true,
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
    // (a pack no longer offered - Adwaita - too: the shell shows its own then)
    function packKey(pack) {
        const p = pack || "";
        return p === IconPacks.qtTheme || !IconPacks.packs.some(k => k.name === p) ? "" : p;
    }

    // the wallpaper as a preset keeps it: a picture of the wallpapers folder by its path in
    // there ("Default/meadow.png": still right if the folder moves), any other by its whole
    // path - and back. (A preset from before each theme had its folder says "meadow.png":
    // Wallpapers.find() takes the picture of that name among the theme's.)
    function wallKey(path) {
        const dir = Config.wallpaperDir + "/";
        const p = path || "";
        return p.startsWith(dir) ? p.slice(dir.length) : p;
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
            islandDisabled: Store.islandDisabled,
            dockDisabled: Store.dockDisabled,
            showAllWallpapers: Store.showAllWallpapers,
            iconPack: packKey(Store.iconPack),
            wallpaper: wallKey(Wallpapers.current),
            theme: Config.theme.name,
            windowBorder: Config.windowBorder,
            windowGap: Config.windowGap,
            cornerRounding: Config.cornerRounding,
            frameOverlay: Config.frameOverlay,
            tenWorkspaces: Config.tenWorkspaces,
            dynamicPopups: Config.dynamicPopups,
            cleanDock: Config.cleanDock,
            detailedMedia: Config.detailedMedia,
            flatSliders: Config.flatSliders,
            minimalSliders: Config.minimalSliders,
            detailedBattery: Config.detailedBattery,
            glowingIcons: Config.glowingIcons,
            noButtonOutline: Config.noButtonOutline,
            clickToExpand: Config.clickToExpand,
            switcherWindowInfo: Config.switcherWindowInfo,
            windowBlur: Config.windowBlur,
            blurSize: Config.blurSize,
            blurPasses: Config.blurPasses,
            blurBrightness: Config.blurBrightness,
            blurContrast: Config.blurContrast
        })

    // every setting a preset has is the same now (numbers: to a thousandth - the
    // sliders' steps of 0.05 are not exact; the icon pack: "" and YAMIS are one; a
    // wallpaper no longer in the folder doesn't count)
    // a preset's values with "Frame overlay" in them: one saved while the switch was
    // "Frameless overlay" has framelessOutline (the other way round) instead
    function frame(values) {
        if (typeof values.frameOverlay !== "boolean" && typeof values.framelessOutline === "boolean")
            return Object.assign({}, values, {
                frameOverlay: !values.framelessOutline
            });
        return values;
    }

    function matches(p) {
        if (!p || !p.values)
            return false;
        const v = frame(p.values);
        const cur = now;
        for (const k in cur) {
            if (v[k] === undefined)
                continue;
            if (k === "wallpaper") {
                // a picture no longer there (or not one of the theme's) doesn't count
                const w = Wallpapers.find(wallPath(v[k]));
                if (w !== "" && w !== Wallpapers.current)
                    return false;
                continue;
            }
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
            setValues(frame(p.values));
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
        // the theme first: the wallpaper is one of its pictures (Wallpapers.request() waits for
        // them to be listed; only a picture still there counts). It fades in as when you pick
        // it, and the lock and login screens get it too
        if (typeof v.theme === "string")
            Themes.set(v.theme);
        if (typeof v.wallpaper === "string" && v.wallpaper !== "")
            Wallpapers.request(wallPath(v.wallpaper));
        if (isNum(v.windowBorder) && Config.windowBorder !== Math.max(0, Math.round(v.windowBorder)))
            Config.windowBorder = Math.max(0, Math.round(v.windowBorder));
        if (isNum(v.windowGap) && Config.windowGap !== Math.max(0, Math.round(v.windowGap)))
            Config.setWindowGap(v.windowGap);
        if (isNum(v.cornerRounding) && Config.cornerRounding !== Math.max(0, Math.round(v.cornerRounding)))
            Config.setCornerRounding(v.cornerRounding);
        // Config's switches (a preset saved before it had one leaves it as it is)
        for (const k of switchKeys) {
            if (typeof v[k] === "boolean" && Config[k] !== v[k])
                Config[k] = v[k];
        }
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
