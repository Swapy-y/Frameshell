pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Store.qml - Small persistent settings (survive restarts / reloads).
//  Stored in ~/.local/state/quickshell/by-shell/<id>/state.json
//
//    notificationsOn   the island's bell (and the Settings app's Notifications page)
//    islandAutoHide    the Settings app (modules/Settings.qml): the island /
//    dockAutoHide      the dock only comes out when the pointer touches its edge
//    islandDisabled    the Settings app's Island page ("Disable island"): no island at all -
//                      nothing of it shows (not on hover either) and no space is kept for it.
//                      The wallpaper / theme switchers and the pop-ups still grow out of the
//                      top edge, as with auto hide (modules/Island.qml, components/IslandSheet.qml)
//    dockDisabled      the Settings app's Dock page ("Disable dock"): no dock at all - no bar or
//                      notch, no corner blocks, not on hover either, no space kept for it. The
//                      power menu and the calendar (SUPER + ,) still open, in the bottom corners
//                      (modules/Overlay.qml)
//    dockNotch         the Settings app's Dock page: the dock as a notch at the bottom, the
//                      power button and the date as blocks in the bottom corners
//    dockPinned        the Settings app's Dock page: the pinned apps, by the id of their
//                      .desktop file ("firefox", "org.gnome.Nautilus"), left to right
//    screenshotCursor  the Settings app's Screenshot page: the pointer is in the picture
//                      (modules/Screenshot.qml)
//    screenshotFollowTheme  the Settings app's Screenshot page ("Follow theme"): the
//                      screenshot screen in the colours of the theme in use, the line round
//                      the area in its windowBorderActive (off: Noir's colours in every
//                      theme; modules/Screenshot.qml)
//    emojiRecent       the emoji picked last in the emoji picker (SUPER + .), the last first
//                      (modules/EmojiPicker.qml)
//    iconPack          the Settings app's Appearance page: the icon pack of the apps in the
//                      shell ("" = the shell's own, YAMIS; services/IconPacks.qml)
//    powerLogo         the Settings app's Appearance page: the bottom bar's power button
//                      shows the Frameshell logo (off: the power sign)
//    showAllWallpapers the Settings app's Wallpaper page ("Show all wallpapers"): the wallpaper
//                      switcher and the Wallpaper page list the pictures of every theme, not
//                      only the theme in use's (services/Wallpapers.qml)
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    property alias notificationsOn: adapter.notificationsOn
    property alias islandAutoHide: adapter.islandAutoHide
    property alias dockAutoHide: adapter.dockAutoHide
    property alias dockNotch: adapter.dockNotch
    property alias islandDisabled: adapter.islandDisabled
    property alias dockDisabled: adapter.dockDisabled
    // nothing of the island / the dock sticks out of the frame and no space is kept for it:
    // auto hide, or switched off
    readonly property bool islandHidden: islandAutoHide || islandDisabled
    readonly property bool dockHidden: dockAutoHide || dockDisabled
    property alias dockPinned: adapter.dockPinned
    property alias screenshotCursor: adapter.screenshotCursor
    property alias screenshotFollowTheme: adapter.screenshotFollowTheme
    property alias emojiRecent: adapter.emojiRecent
    property alias iconPack: adapter.iconPack
    property alias powerLogo: adapter.powerLogo
    property alias showAllWallpapers: adapter.showAllWallpapers

    // While holdWrites is true a change is not written at once: a preset sets several of them in
    // one go (services/Presets.qml), then calls write() - see Config.holdWrites for why.
    property bool holdWrites: false
    function write() {
        file.writeAdapter();
    }

    FileView {
        id: file
        path: Quickshell.statePath("state.json")
        printErrors: false
        watchChanges: false
        atomicWrites: true
        // read before anything is shown: a hidden island / dock never flashes up at start
        blockLoading: true

        onAdapterUpdated: {
            if (!root.holdWrites)
                writeAdapter();
        }
        onLoadFailed: error => {
            // first run: create the file with the defaults
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        adapter: JsonAdapter {
            id: adapter
            property bool notificationsOn: Config.startWithNotificationsOn
            property bool islandAutoHide: false
            property bool dockAutoHide: false
            property bool dockNotch: false
            property bool islandDisabled: false
            property bool dockDisabled: false
            property var dockPinned: []
            property bool screenshotCursor: true
            property bool screenshotFollowTheme: false
            property var emojiRecent: []
            property string iconPack: ""
            property bool powerLogo: true
            property bool showAllWallpapers: false
        }
    }
}
