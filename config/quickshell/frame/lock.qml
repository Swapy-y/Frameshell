import QtQuick
import Quickshell
import qs.modules

// ═══════════════════════════════════════════════════════════════════════════
//  lock.qml - the lock screen, as its own small Quickshell process.
//
//  Started by scripts/lock.sh at login (hyprland.lua) and kept in the
//  background, ready: SUPER + Escape, "Lock" in the power menu and hypridle
//  only have to show it (lock.sh). Run on its own,
//  qs -p ~/.config/quickshell/frame/lock.qml, it locks the session at once
//  and quits when the right password is typed.
//
//  It is separate from the shell on purpose: restarting or editing the shell
//  never touches a locked screen, and the lock works even if the shell is not
//  running. The look and the logic are in modules/Lock.qml and LockView.qml.
// ═══════════════════════════════════════════════════════════════════════════
ShellRoot {
    settings.watchFiles: false      // never reload while the screen is locked

    // the shell's font, used when the Pixie theme (and its font) is missing
    FontLoader {
        source: Qt.resolvedUrl("assets/fonts/ClarityCity-Regular.otf")
    }
    FontLoader {
        source: Qt.resolvedUrl("assets/fonts/ClarityCity-Bold.otf")
    }

    Lock {}
}
