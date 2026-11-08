import QtQuick
import qs
import qs.services
import qs.components

// ═══════════════════════════════════════════════════════════════════════════
//  PowerMenu.qml - panel that opens from the bottom-left corner when the power
//  button is pressed: Shut down (asks first) · Restart · Lock · Log out (asks first).
//  Each row: the icon on a soft grey circle, the label (Clarity City Medium),
//  a thin line under it; Shut down in red. Under the pointer a rounded
//  highlight lights up behind the circle and the label, and the circle fills
//  (white, red for Shut down) with the icon dark on it.
//
//  Its width follows the longest label, its height follows the number of rows.
//  To add or remove an action, edit `actions` below
//  (the `action` names are handled in services/PowerActions.qml).
// ═══════════════════════════════════════════════════════════════════════════
Panel {
    id: root

    open: Ui.powerOpen
    attachBottom: true
    attachLeft: true

    readonly property var actions: [
        {
            label: "Shut down",
            icon: "power",
            action: "shutdown",
            red: true
        },
        {
            label: "Restart",
            icon: "restart",
            action: "reboot",
            red: false
        },
        {
            label: "Lock",
            icon: "lock",
            action: "lock",
            red: false
        },
        {
            label: "Log out",
            icon: "logout",
            action: "logout",
            red: false
        }
    ]

    // a row: the line under it is its last pixel row; the hover highlight is as far
    // from the line above as from the line below
    readonly property real rowH: Theme.px(47)
    readonly property real hoverGap: Theme.px(2)
    readonly property real ringSize: Theme.px(32)
    readonly property real gap: Theme.px(12)                // between the ring and the label
    // about 15 px all round: from the edge of the screen to the circles, from the
    // lines' ends to the border, from the top to the first circle
    readonly property real padLeft: Theme.frame + Theme.px(12)
    readonly property real padRight: Theme.px(15)
    readonly property real padTop: Theme.px(9)

    FontMetrics {
        id: fm
        font.family: Theme.font
        font.pixelSize: Theme.px(15)
        font.weight: Font.Medium
    }

    // widest label decides the width
    readonly property real labelW: Math.ceil(Math.max.apply(null, actions.map(a => fm.advanceWidth(a.label))))
    readonly property real rowW: ringSize + gap + labelW + Theme.px(16)

    contentW: padLeft + rowW + padRight
    contentH: padTop + actions.length * rowH + Theme.px(4) + Theme.bar

    Column {
        x: root.padLeft
        y: root.padTop
        width: root.rowW

        Repeater {
            model: root.actions

            Item {
                id: row
                required property var modelData
                required property int index

                readonly property color tint: modelData.red ? Config.warning : Config.text

                width: root.rowW
                height: root.rowH

                // the row without its line (the last pixel row): the highlight, the
                // circle and the label are centred in it
                readonly property real cellH: height - 1

                // hover highlight behind the circle and the label, as long as the
                // dividing line
                Rectangle {
                    x: 0
                    y: root.hoverGap
                    width: parent.width
                    height: row.cellH - 2 * root.hoverGap
                    radius: Theme.px(10)
                    color: Config.selected
                    opacity: area.containsMouse ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            duration: Theme.durFast
                        }
                    }
                }

                // the icon on a soft grey circle; under the pointer it fills (white, red
                // for Shut down) and the icon turns dark
                RingButton {
                    id: ring
                    x: 0
                    y: Math.round((row.cellH - height) / 2)
                    width: root.ringSize
                    icon: row.modelData.icon
                    iconSize: Theme.px(16)
                    iconColor: row.tint
                    onColor: row.tint
                    fillOnHover: true
                    outline: false
                    offColor: Config.selected
                    interactive: false
                    hot: area.containsMouse
                    down: area.pressed
                }

                Txt {
                    x: root.ringSize + root.gap
                    y: Math.round((row.cellH - height) / 2)
                    text: row.modelData.label
                    font.pixelSize: Theme.px(15)
                    font.weight: Font.Medium
                    color: row.tint
                }

                // thin line between the rows, from the circles on (none under the last one)
                Rectangle {
                    visible: row.index < root.actions.length - 1
                    x: 0
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Config.divider
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Ui.powerOpen = false;
                        // shutting down and logging out ask first (modules/PowerConfirm.qml)
                        const action = row.modelData.action;
                        if (action === "shutdown" || action === "logout")
                            Ui.ask(action);
                        else
                            PowerActions.run(action);
                    }
                }
            }
        }
    }
}
