import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// ═══════════════════════════════════════════════════════════════════════════
//  Curtain.qml - logging out. The whole screen (windows, frame, bar) fades to
//  black; scripts/power.sh closes the apps behind it and quits Hyprland, and
//  the login screen fades in from black. It covers everything and takes the
//  mouse and keyboard, so nothing can be clicked in the meantime.
//
//  Shown while Ui.loggingOut is true (PowerActions.logout()). The window is
//  already there while "Log out?" is asked - see-through, every click goes
//  through it - so nothing new appears when the fade starts: Hyprland animates
//  a layer as it appears (the "frame-popups-fade" rule in hyprland.lua lets it
//  only fade), which could slide the black in from the top.
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: Ui.loggingOut || Ui.confirm === "logout" || shade.opacity > 0.001

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "frame-curtain"
            WlrLayershell.keyboardFocus: Ui.loggingOut ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            // clicks go through to "Log out?" until you log out
            mask: Ui.loggingOut ? allInput : noInput
            Region {
                id: allInput
                item: shade
            }
            Region {
                id: noInput
            }

            Rectangle {
                id: shade
                anchors.fill: parent
                color: "black"
                opacity: Ui.loggingOut ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durCurtain
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveStandard
                    }
                }

                // swallow every click
                MouseArea {
                    anchors.fill: parent
                    enabled: Ui.loggingOut
                    hoverEnabled: true
                }
            }
        }
    }
}
