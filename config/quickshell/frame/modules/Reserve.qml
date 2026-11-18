import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// ═══════════════════════════════════════════════════════════════════════════
//  Reserve.qml - invisible windows that only reserve screen space (layer-shell
//  exclusive zones), so tiled windows stay inside the frame and the border
//  instead of going under it.
//
//  The reserved space is the dark frame (Theme.inset, its border included; frameless,
//  Config.framelessOutline: nothing on the left and the right, only the bar and
//  the notch). Hyprland adds the window gap (Config.windowGap: the Settings app's
//  "Window gap", 15px by default) on top of it, so a window floats inside the
//  frame with a strip of wallpaper around it. A side with nothing to reserve has
//  no window at all (a layer surface may not be 0 px thick).
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    Variants {
        model: Quickshell.screens

        Scope {
            id: scope
            required property var modelData

            component Zone: PanelWindow {
                screen: scope.modelData
                color: "transparent"
                mask: Region {}      // empty region: never receives pointer input
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.namespace: "frame-reserve"
                exclusionMode: ExclusionMode.Auto
            }

            // top: the frame, or the whole notch height so windows never sit under it.
            // Auto hide (the Settings app): only the frame (frameless: nothing) - the
            // island comes out over the windows. Disable island: only the frame too
            Zone {
                anchors {
                    top: true
                    left: true
                    right: true
                }
                implicitHeight: Config.reserveNotch && !Store.islandHidden ? Theme.notchH - Theme.notchShiftTo : Theme.inset
                visible: implicitHeight > 0
            }

            // bottom bar; with auto hide only the frame (frameless: nothing) - the bar
            // comes out over the windows. Disable dock: only the frame too
            Zone {
                anchors {
                    bottom: true
                    left: true
                    right: true
                }
                implicitHeight: Store.dockHidden ? Theme.inset : Theme.insetBottom
                visible: implicitHeight > 0
            }

            // left frame (frameless: nothing)
            Zone {
                anchors {
                    top: true
                    bottom: true
                    left: true
                }
                implicitWidth: Theme.inset
                visible: implicitWidth > 0
            }

            // right frame (frameless: nothing)
            Zone {
                anchors {
                    top: true
                    bottom: true
                    right: true
                }
                implicitWidth: Theme.inset
                visible: implicitWidth > 0
            }
        }
    }
}
