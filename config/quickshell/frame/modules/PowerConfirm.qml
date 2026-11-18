import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.components

// ═══════════════════════════════════════════════════════════════════════════
//  PowerConfirm.qml - "Shut down?", "Restart?" and "Log out?" before it happens
//  (Shut down / Restart / Log out in the power menu, SUPER + M open it: Ui.ask()).
//  Drawn like the password dialog: a black card that grows out of the island
//  (components/IslandSheet.qml), or with Island popups off (Config.dynamicPopups)
//  sits in the middle of the screen over a dimmed desktop. No countdown: nothing happens until you choose.
//
//  Enter or the white button goes ahead; Esc, "Cancel" or a click outside the
//  card closes it. Logging out fades the screen to black first
//  (PowerActions.logout(), modules/Curtain.qml).
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    id: root

    readonly property bool open: Ui.confirm !== ""

    // what the card says; kept while it fades out, so the text never jumps
    readonly property var kinds: ({
            shutdown: {
                icon: "power",
                title: "Shut down?",
                text: "The computer will turn off. Unsaved work in open apps may be lost.",
                button: "Shut down"
            },
            reboot: {
                icon: "restart",
                title: "Restart?",
                text: "The computer will restart. Unsaved work in open apps may be lost.",
                button: "Restart"
            },
            logout: {
                icon: "logout",
                title: "Log out?",
                text: "All your apps will close and the login screen comes back. Unsaved work in open apps may be lost.",
                button: "Log out"
            }
        })
    property string shown: "shutdown"
    readonly property var kind: kinds[shown] || kinds.shutdown

    Connections {
        target: Ui
        function onConfirmChanged() {
            if (Ui.confirm !== "" && root.kinds[Ui.confirm] !== undefined)
                root.shown = Ui.confirm;
        }
    }

    function confirm() {
        if (!open)
            return;
        const action = shown;
        if (action === "logout") {
            PowerActions.logout();      // closes the card itself
            return;
        }
        Ui.confirm = "";
        PowerActions.run(action);
    }

    function cancel() {
        Ui.confirm = "";
    }

    // the keyboard arrives a moment after the window maps
    Timer {
        id: focusTimer
        interval: 50
        onTriggered: keys.forceActiveFocus()
    }

    PanelWindow {
        id: win
        // black like the frame, in every theme: the frame's colours for its pieces too
        readonly property bool framePalette: true

        visible: root.open || sheet.shown

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "frame-confirm"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        onVisibleChanged: {
            if (visible)
                focusTimer.restart();
        }

        // Esc / Enter
        Item {
            id: keys
            focus: true
            Keys.onPressed: event => {
                if (!root.open)
                    return;
                if (event.key === Qt.Key_Escape) {
                    root.cancel();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.confirm();
                    event.accepted = true;
                }
            }
        }

        // dimmed desktop; a click outside the card says no
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.open && sheet.centered ? 0.35 : 0      // (out of the island: no dimming)
            Behavior on opacity {
                Anim {
                    duration: root.open ? Theme.durSmall : Theme.durFast
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: root.open
                onPressed: root.cancel()
            }
        }

        // the card: out of the island, or in the middle (Island popups, components/IslandSheet.qml)
        IslandSheet {
            id: sheet
            open: root.open
            sheetW: card.width
            sheetH: sheet.contentTop + card.height
            cardRadius: Theme.px(26)

            Item {
                id: card

                readonly property real pad: Theme.px(24)

                width: Theme.px(380)
                height: column.height + 2 * pad
                x: 0
                y: sheet.contentTop



                // swallow clicks so they do not reach the backdrop
                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    id: column
                    x: card.pad
                    y: card.pad
                    width: card.width - 2 * card.pad
                    spacing: Theme.px(10)

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: Theme.px(30)
                        name: root.kind.icon
                        color: Config.text
                    }

                    Txt {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.kind.title
                        font.pixelSize: Theme.px(24)
                        font.family: Theme.fontDisplay
                        font.weight: Font.Medium
                    }

                    Txt {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.kind.text
                        wrapMode: Text.Wrap
                        color: Config.frameColors.textSecondary
                        font.pixelSize: Theme.px(17)
                    }

                    Item {
                        width: 1
                        height: Theme.px(8)
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.px(10)

                        Repeater {
                            model: [
                                {
                                    cancel: true
                                },
                                {
                                    cancel: false
                                }
                            ]

                            Rectangle {
                                id: button
                                required property var modelData
                                readonly property bool primary: !modelData.cancel

                                width: (parent.width - parent.spacing) / 2
                                height: Theme.px(42)
                                radius: Theme.px(14)
                                color: primary ? Config.text : (buttonArea.containsMouse ? Config.frameColors.controlHover : Config.frameColors.controlBackground)
                                border.width: primary ? 0 : Theme.outlineW
                                border.color: Theme.outlineColor
                                scale: buttonArea.pressed ? 0.97 : 1

                                Behavior on color {
                                    CAnim {}
                                }
                                Behavior on scale {
                                    Anim {
                                        duration: Theme.durFast
                                    }
                                }

                                Txt {
                                    anchors.centerIn: parent
                                    text: button.primary ? root.kind.button : "Cancel"
                                    color: button.primary ? Config.frameColors.background : Config.text
                                    font.pixelSize: Theme.px(17)
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: buttonArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: root.open
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (button.primary)
                                            root.confirm();
                                        else
                                            root.cancel();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
