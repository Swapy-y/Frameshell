//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma IconTheme YAMIS

import QtQuick
import Quickshell
import qs.modules

// ═══════════════════════════════════════════════════════════════════════════
//  shell.qml - entry point of the "frame" shell for Hyprland + Quickshell.
//
//  Run with:  qs -c frame
//
//  What lives where:
//    Config.qml              all settings (edit this one)
//    Theme.qml               sizes and animation curves
//    modules/Wallpaper.qml   wallpaper (background layer)
//    modules/Overlay.qml     frame, island, bottom bar and the panels
//    modules/Reserve.qml     keeps windows inside the frame
//    modules/Switcher.qml    Super+Space    (`qs -c frame ipc call switcher ...`)
//    modules/Launcher.qml    Super+R        (`qs -c frame ipc call launcher toggle`)
//    modules/Screenshot.qml  Print          (`qs -c frame ipc call screenshot area`)
//    modules/EmojiPicker.qml Super+.        (`qs -c frame ipc call emoji toggle`)
//    modules/OnScreenKeyboard.qml  Super+\  (`qs -c frame ipc call keyboard toggle`)
//    modules/HyprSync.qml    gives the window border width / cornerRadius to Hyprland's windows
//    modules/PowerConfirm.qml  "Shut down?" / "Log out?"
//    modules/Curtain.qml     logging out: the screen fades to black
//    lock.qml                the lock screen, its own process (scripts/lock.sh starts it):
//                            modules/Lock.qml + modules/LockView.qml
//    modules/UiIpc.qml       keyboard access to panels (`qs -c frame ipc call ui ...`)
//    modules/Settings.qml    the Settings app (`qs -c frame ipc call ui settings`)
//    components/             building blocks (icons, panels, sliders ...)
//    services/               data: clock, battery, volume, apps, notifications ...
// ═══════════════════════════════════════════════════════════════════════════
ShellRoot {
    // Clarity City, bundled so the shell looks right even before the font is installed system-wide
    FontLoader {
        source: Qt.resolvedUrl("assets/fonts/ClarityCity-Regular.otf")
    }
    FontLoader {
        source: Qt.resolvedUrl("assets/fonts/ClarityCity-Medium.otf")
    }
    FontLoader {
        source: Qt.resolvedUrl("assets/fonts/ClarityCity-SemiBold.otf")
    }
    FontLoader {
        source: Qt.resolvedUrl("assets/fonts/ClarityCity-Bold.otf")
    }

    Wallpaper {}
    Reserve {}
    Overlay {}
    Switcher {}
    Launcher {}
    Screenshot {}    // Print / Shift + Print
    EmojiPicker {}   // SUPER + .
    OnScreenKeyboard {}  // SUPER + \
    UiIpc {}
    HyprSync {}
    PowerConfirm {}
    NetPopup {}      // the Wi-Fi / Bluetooth card (the island's buttons)
    Settings {}      // the Settings app's window, while it is open
    Curtain {}       // last: logging out covers everything

    // the password dialog when an app needs admin rights (polkit agent).
    // Loaded separately: a Quickshell built without polkit support only loses
    // this part, and hyprpolkitagent shows its own dialog instead.
    Loader {
        source: "modules/PolkitAuth.qml"
        onStatusChanged: {
            if (status === Loader.Error)
                Quickshell.execDetached(["sh", "-c", "systemctl --user start hyprpolkitagent.service 2>/dev/null || exec /usr/lib/hyprpolkitagent/hyprpolkitagent"]);
        }
    }
}
