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
//  The reserved space is the dark frame plus the border. Hyprland adds the
//  window gap (Config.windowGap: the Settings app's "Window gap", 15px by
//  default) on top of it, so a window floats inside the frame with a strip of
//  wallpaper around it.
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
            // Auto hide (the Settings app): only the frame - the island comes out over
            // the windows
            Zone {
                anchors {
                    top: true
                    left: true
                    right: true
                }
                implicitHeight: (Config.reserveNotch && !Store.islandAutoHide ? Theme.notchH : Theme.frame) + Theme.border
            }

            // bottom bar; with auto hide only the frame - the bar comes out over the windows
            Zone {
                anchors {
                    bottom: true
                    left: true
                    right: true
                }
                implicitHeight: Store.dockAutoHide ? Theme.inset : Theme.insetBottom
            }

            // left frame
            Zone {
                anchors {
                    top: true
                    bottom: true
                    left: true
                }
                implicitWidth: Theme.inset
            }

            // right frame
            Zone {
                anchors {
                    top: true
                    bottom: true
                    right: true
                }
                implicitWidth: Theme.inset
            }
        }
    }
}
