pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

// ═══════════════════════════════════════════════════════════════════════════
//  Ui.qml - Shared UI state (what is open right now).
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    property bool powerOpen: false
    property bool calendarOpen: false
    property bool noteEditing: false
    property bool clipboardSearching: false // typing in the clipboard's search field (modules/ClipboardPanel.qml)
    property string confirm: ""             // "shutdown" / "logout": the "Shut down?" / "Log out?" card (modules/PowerConfirm.qml)
    property bool loggingOut: false         // the screen fades to the wallpaper and the session ends (modules/Curtain.qml, PowerActions.logout())
    property bool logoutDark: false         // ... and right before Hyprland quits, to black (power.sh: ipc call ui logoutFade)

    // After logging in the whole desktop (wallpaper, frame, bar) fades in together,
    // once the wallpaper has loaded (modules/Wallpaper.qml sets these, Overlay follows).
    // Instant after a reload of the shell.
    property bool revealed: false
    property bool revealInstant: false

    onLoggingOutChanged: {
        if (!loggingOut)
            logoutDark = false;
    }
    property string netPage: ""             // "wifi" / "bluetooth": the card in the middle of the screen (modules/NetPopup.qml)
    property bool wallpaperOpen: false      // the wallpaper switcher in the island (SUPER + CTRL + Left / Right, modules/Island.qml)
    property bool themeOpen: false          // the theme switcher in the island (SUPER + CTRL + Up / Down, the same place)
    property bool settingsOpen: false       // the Settings app's window (modules/Settings.qml)
    // the screens where a window covers the whole screen as a floating window (F11 on a
    // workspace without tiling, hyprland.lua: ipc call ui cover): the overlay hides there, as
    // Hyprland hides it for its own fullscreen (modules/Overlay.qml)
    property var coveredScreens: []
    signal wallpaperShown                   // ... a key was pressed: the picture it is on counts from now
    signal themeShown                       // ... the same for the theme switcher

    // the panels of the overlay (the Wi-Fi / Bluetooth card is its own window, with its own backdrop),
    // and the wallpaper / theme switcher: they take the keyboard (Esc closes them) and a click
    // outside closes them
    readonly property bool anyPopup: powerOpen || calendarOpen || noteEditing || clipboardSearching || wallpaperOpen || themeOpen

    function togglePower() {
        calendarOpen = false;
        netPage = "";
        powerOpen = !powerOpen;
    }

    // the Wi-Fi / Bluetooth buttons of the island: open that list, or close it
    function toggleNet(page) {
        powerOpen = false;
        calendarOpen = false;
        netPage = netPage === page ? "" : page;
    }

    // SUPER + CTRL + Left / Right: the island turns into the wallpaper switcher and
    // moves one picture (an open Wi-Fi / Bluetooth card closes, it would cover
    // it). Opening it starts at the wallpaper on screen. Enter (applySwitcher())
    // makes the picture in the middle the wallpaper; closed any other way (Esc,
    // a click outside, closePopups(), SUPER + CTRL + Up / Down) the wallpaper stays.
    function browseWallpapers(direction) {
        netPage = "";
        // the theme switcher was open: it turns into the wallpaper switcher (opened
        // first, so the island stays open), the theme stays
        const opening = !wallpaperOpen;
        if (opening)
            Wallpapers.startBrowsing();
        wallpaperOpen = true;
        themeOpen = false;
        Wallpapers.browse(direction);
        // opening: it grows open on the next picture already, like the island
        // grows open (no sideways slide at the same time); later presses slide
        if (opening)
            Wallpapers.jumped();
        wallpaperShown();
    }

    // Enter in the wallpaper / theme switcher (modules/Overlay.qml), or a click on the
    // picture / theme in the middle (modules/Island.qml): it is used, the switcher closes
    function applySwitcher() {
        if (wallpaperOpen) {
            Wallpapers.apply();
            wallpaperOpen = false;
        }
        if (themeOpen) {
            Themes.apply();
            themeOpen = false;
        }
    }

    // the arrow keys while the switcher is open (modules/Overlay.qml): one step in
    // the one that is open; false when none is
    function browseSwitcher(direction) {
        if (wallpaperOpen) {
            if (Wallpapers.count > 0)
                browseWallpapers(direction);
            return true;
        }
        if (themeOpen) {
            if (Themes.count > 0)
                browseThemes(direction);
            return true;
        }
        return false;
    }

    // SUPER + CTRL + Up / Down: the same with the colour themes (services/Themes.qml);
    // from the wallpaper switcher: that one closes without a change
    function browseThemes(direction) {
        netPage = "";
        const opening = !themeOpen;
        if (opening)
            Themes.startBrowsing();
        themeOpen = true;
        wallpaperOpen = false;
        Themes.browse(direction);
        if (opening)
            Themes.jumped();
        themeShown();
    }

    // The Settings app: opens its window, or brings it to the front (it may be on
    // another workspace, or minimized) when it is open already.
    function openSettings() {
        if (!settingsOpen) {
            settingsOpen = true;
            return;
        }
        const list = ToplevelManager.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            if (Apps.isSettings(list[i])) {
                Apps.activate(list[i]);
                return;
            }
        }
    }

    // opening the calendar also closes the quick note (they share the right edge)
    function toggleCalendar() {
        powerOpen = false;
        netPage = "";
        calendarOpen = !calendarOpen;
        if (calendarOpen)
            noteEditing = false;
    }

    // "Shut down?" / "Log out?" (the power menu, SUPER + M)
    function ask(action) {
        if (loggingOut)
            return;
        powerOpen = false;
        calendarOpen = false;
        netPage = "";
        confirm = action;
    }

    function closePopups() {
        powerOpen = false;
        calendarOpen = false;
        noteEditing = false;
        clipboardSearching = false;
        confirm = "";
        netPage = "";
        wallpaperOpen = false;
        themeOpen = false;
    }

    // Safety net next to the overlay's focus grab: when another window becomes the
    // active one (you clicked it, Super+Space, a new window opened) the open panels fold.
    // `null` is ignored — that is just the shell taking the keyboard for a text cursor.
    Connections {
        target: ToplevelManager

        function onActiveToplevelChanged() {
            if (ToplevelManager.activeToplevel && root.anyPopup)
                root.closePopups();
        }
    }
}
