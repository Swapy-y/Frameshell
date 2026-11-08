import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// ═══════════════════════════════════════════════════════════════════════════
//  Curtain.qml - logging out. The desktop (windows, frame, bar) fades away to
//  just the wallpaper, a little darker, like the login screen behind its clock.
//  scripts/power.sh closes the apps behind it; right before Hyprland quits it
//  fades to black (ipc call ui logoutFade) and the login screen fades in from
//  black. It covers everything and takes the mouse and keyboard, so nothing
//  can be clicked in the meantime.
//
//  Shown while Ui.loggingOut is true (PowerActions.logout()). The picture is
//  read while "Log out?" is asked, so it is there when the fade starts.
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: Ui.loggingOut || shade.opacity > 0.001

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

            Item {
                id: shade
                anchors.fill: parent
                opacity: Ui.loggingOut ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durCurtain
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveStandard
                    }
                }

                // black until the picture is there
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    visible: picture.status !== Image.Ready || picture.opacity < 1
                }

                Image {
                    id: picture
                    anchors.fill: parent
                    source: (Ui.confirm === "logout" || Ui.loggingOut) && Wallpapers.ready ? "file://" + Wallpapers.current : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durOpen
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveStandard
                        }
                    }
                }

                // a little darker, like the login screen; all black at the very end
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: Ui.logoutDark ? 1 : 0.4
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durCurtainDark
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveStandard
                        }
                    }
                }

                // swallow every click
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
    }
}
