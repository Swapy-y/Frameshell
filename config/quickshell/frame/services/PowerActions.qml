pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  PowerActions.qml - Shut down / restart / lock / log out.
//  The logic lives in scripts/power.sh
//
//  Logging out (after "Log out?", modules/PowerConfirm.qml): the desktop fades
//  to the wallpaper (modules/Curtain.qml), then power.sh closes every app, quits
//  Hyprland and ends the session, so the login screen comes back.
// ═══════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/power.sh")

    function run(action) {
        runner.command = ["bash", script, action];
        runner.running = true;
    }

    Process {
        id: runner
    }

    function logout() {
        if (Ui.loggingOut)
            return;
        // this order: the curtain keeps the wallpaper it read while "Log out?" was asked
        Ui.loggingOut = true;
        Ui.closePopups();
        logoutStart.restart();
        logoutFailed.restart();
    }

    // once the screen is black. Detached: power.sh has to outlive the shell,
    // which quits together with Hyprland
    Timer {
        id: logoutStart
        interval: Theme.durCurtain
        onTriggered: Quickshell.execDetached(["bash", root.script, "logout"])
    }

    // Still here long after power.sh should have ended the session (it gives
    // the apps 3 s, then Hyprland 10 s): the log out failed. Give the desktop back.
    Timer {
        id: logoutFailed
        interval: 25000
        onTriggered: {
            console.warn("PowerActions: logging out did not work (see scripts/power.sh)");
            Ui.loggingOut = false;
        }
    }
}
