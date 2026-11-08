import QtQuick
import qs
import qs.services
import qs.components

// ═══════════════════════════════════════════════════════════════════════════
//  SliderPanel.qml - volume and brightness sliders. Opens when the pointer
//  touches the top-left corner of the frame (a few pixels of the frame itself
//  act as the hot zone, see Overlay.qml).
//
//  Each row: the icon on a soft grey circle, the name and the value (in %)
//  above the slider. A click on the speaker mutes / unmutes.
//
//  The panel only shows the rows that work: if your monitor has no brightness
//  control (no brightnessctl / DDC), the brightness row is left out and the
//  panel is shorter.
// ═══════════════════════════════════════════════════════════════════════════
Panel {
    id: root

    // true while the pointer touches the hot corner of the frame (set by Overlay.qml)
    property bool hot: false

    HoverLatch {
        id: latch
        input: root.hot || panelHover.hovered || (root.open && (volumeSlider.dragging || brightnessSlider.dragging))
    }

    open: latch.open
    attachTop: true
    attachLeft: true

    // space between the panel's edges (the frame's inner edge on the top and left)
    // and the circles / the ends of the sliders
    readonly property real padLeft: Theme.px(17)
    readonly property real padRight: Theme.px(19)
    readonly property real padTop: Theme.px(16)
    readonly property real padBottom: Theme.px(18)
    readonly property real circle: Theme.px(32)       // a row is as tall as its circle
    readonly property real rowGap: Theme.px(13)       // between the two rows
    readonly property real gap: Theme.px(12)          // between the circle and the label / slider
    readonly property bool showBrightness: Backlight.supported || !Backlight.probed

    contentW: Theme.slidersW
    contentH: Theme.frame + padTop + rows.height + padBottom

    HoverHandler {
        id: panelHover
    }

    // the row names and their values
    component Label: Txt {
        font.pixelSize: Theme.px(13)
        font.weight: Font.Medium
    }

    Column {
        id: rows
        x: Theme.frame + root.padLeft
        y: Theme.frame + root.padTop
        width: root.contentW - Theme.frame - root.padLeft - root.padRight
        spacing: root.rowGap

        // A row: the icon on a soft grey circle (like the power menu's), the name and
        // the value next to its top, the slider next to its bottom.

        // ── sound ──
        Item {
            id: soundRow
            width: parent.width
            height: root.circle

            // the speaker: a click mutes / unmutes; it dips when pressed
            Rectangle {
                id: soundCircle
                width: root.circle
                height: width
                radius: width / 2
                color: Config.selected
                antialiasing: true
                scale: muteArea.pressed ? 0.9 : 1

                Behavior on color {
                    CAnim {}
                }
                Behavior on scale {
                    Anim {
                        duration: Theme.durFast
                        curve: Theme.curveSpring
                    }
                }

                VolumeIcon {
                    x: Math.round((parent.width - width) / 2)
                    y: Math.round((parent.height - height) / 2)
                    size: Theme.px(18)
                    level: Volume.volume
                    muted: Volume.muted
                    color: Volume.muted ? Config.textDim : Config.text
                    dim: Config.iconDim
                }

                MouseArea {
                    id: muteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: Volume.ready
                    onClicked: Volume.toggleMute()
                }
            }

            Label {
                x: root.circle + root.gap
                y: 0
                text: "Sound"
            }
            Label {
                anchors.right: parent.right
                y: 0
                text: !Volume.ready ? "" : (Volume.muted ? "Muted" : Math.round(Volume.volume * 100) + "%")
                color: Config.textDim
            }

            FSlider {
                id: volumeSlider
                x: root.circle + root.gap
                y: Theme.px(19)
                width: parent.width - x
                value: Volume.muted ? 0 : Volume.volume
                interactive: Volume.ready
                onMoved: v => Volume.setVolume(v)
            }
        }

        // ── brightness (left out when the screen cannot be controlled) ──
        Item {
            visible: root.showBrightness
            width: parent.width
            height: root.circle

            Rectangle {
                width: root.circle
                height: width
                radius: width / 2
                color: Config.selected
                antialiasing: true

                Icon {
                    x: Math.round((parent.width - width) / 2)
                    y: Math.round((parent.height - height) / 2)
                    size: Theme.px(18)
                    name: "sun"
                }
            }

            Label {
                x: root.circle + root.gap
                y: 0
                text: "Brightness"
            }
            Label {
                anchors.right: parent.right
                y: 0
                text: Backlight.supported ? Math.round(Backlight.value * 100) + "%" : ""
                color: Config.textDim
            }

            FSlider {
                id: brightnessSlider
                x: root.circle + root.gap
                y: Theme.px(19)
                width: parent.width - x
                value: Backlight.value
                interactive: Backlight.supported
                onMoved: v => Backlight.setValue(v)
            }
        }
    }
}
