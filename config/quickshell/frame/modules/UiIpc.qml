import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

// ═══════════════════════════════════════════════════════════════════════════
//  UiIpc.qml - Keyboard access to the panels, for Hyprland binds:
//    qs -c frame ipc call ui power      toggle the power menu
//    qs -c frame ipc call ui calendar   toggle the calendar
//    qs -c frame ipc call ui wifi       toggle the Wi-Fi list (under the island)
//    qs -c frame ipc call ui bluetooth  toggle the Bluetooth list
//    qs -c frame ipc call ui close      close everything that is open
//    qs -c frame ipc call ui settings   open the Settings app (or bring it to the front)
//    qs -c frame ipc call ui logout     ask "Log out?"
//    qs -c frame ipc call ui cover 'DP-1' the screens a window covers like fullscreen ('' = none):
//                                       the frame, notch and bar hide there (hyprland.lua sends
//                                       the same as an event on Hyprland's socket, below: faster)
//    qs -c frame ipc call wallpaper next / prev   the next / previous wallpaper (SUPER + CTRL + Right / Left)
//    qs -c frame ipc call theme next / prev       the next / previous colour theme (SUPER + CTRL + Up / Down)
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    IpcHandler {
        target: "ui"

        function power(): void {
            Ui.togglePower();
        }

        function calendar(): void {
            Ui.toggleCalendar();
        }

        function wifi(): void {
            Ui.toggleNet("wifi");
        }

        function bluetooth(): void {
            Ui.toggleNet("bluetooth");
        }

        function close(): void {
            Ui.closePopups();
        }

        // the Settings app (its menu entry, frame-settings.desktop, runs this)
        function settings(): void {
            Ui.openSettings();
        }

        // "Log out?" (SUPER + M)
        function logout(): void {
            Ui.ask("logout");
        }

        // F11 on a workspace without tiling: the window covers the screen as a floating window
        // (so the others stay visible under it); Hyprland does not hide the shell for that, so
        // hyprland.lua tells which screens are covered, a space-separated list of names
        function cover(screens: string): void {
            Ui.coveredScreens = screens.split(" ").filter(s => s.length > 0);
        }
    }

    // ... hyprland.lua tells it at once on Hyprland's event socket (the same list):
    // "custom>>frameshell-cover DP-1" - or "frameshell-cover-now DP-1": a screen new in the list
    // hides at once, without the fade (a window is about to leave Hyprland's own fullscreen there,
    // and Hyprland shows the shell again as it does)
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "custom" || !event.data.startsWith("frameshell-cover"))
                return;
            const now = event.data.startsWith("frameshell-cover-now");
            Ui.setCovered(event.data.slice(now ? 20 : 16).split(" ").filter(s => s.length > 0), now);
        }
    }

    // started (or restarted) while a screen is covered: ask hyprland.lua for the list
    // (a hyprland.lua without frameshell_cover_sync: nothing)
    Component.onCompleted: {
        if (Hyprland.usingLua)
            Hyprland.dispatch("(frameshell_cover_sync or function() return function() end end)()");
    }

    // the wallpaper switcher (modules/Island.qml): it opens and moves one picture;
    // the one you stay on becomes the wallpaper
    IpcHandler {
        target: "wallpaper"

        function next(): void {
            if (Wallpapers.count > 0)
                Ui.browseWallpapers(1);
        }

        function prev(): void {
            if (Wallpapers.count > 0)
                Ui.browseWallpapers(-1);
        }
    }

    // the theme switcher (the same place in the island): it opens and moves one
    // theme; the one you stay on is used
    IpcHandler {
        target: "theme"

        function next(): void {
            if (Themes.count > 0)
                Ui.browseThemes(1);
        }

        function prev(): void {
            if (Themes.count > 0)
                Ui.browseThemes(-1);
        }
    }
}
