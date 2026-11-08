import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.components

// ═══════════════════════════════════════════════════════════════════════════
//  PowerConfirm.qml - "Shut down?" and "Log out?" before it happens (Shut down
//  / Log out in the power menu, SUPER + M open it: Ui.ask()).
//  Drawn like the password dialog: a dark card in the middle of the screen
//  over a dimmed desktop. No countdown: nothing happens until you choose.
//
//  Enter or the white button goes ahead; Esc, "Cancel" or a click outside the
//  card closes it. Logging out fades the desktop to the wallpaper first
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

        visible: root.open || card.opacity > 0.01

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
            opacity: root.open ? 0.35 : 0
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

        Rectangle {
            id: card

            readonly property real pad: Theme.px(24)

            width: Theme.px(380)
            height: column.height + 2 * pad
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            radius: Theme.px(26)
            color: Config.surface               // see-through with the shell's blur
            border.width: Theme.border
            border.color: Config.outline

            Loader {
                z: -1
                anchors.fill: parent
                active: Config.shadows && Config.shadowStrength > 0
                source: "../components/CardShadow.qml"
            }

            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.94
            Behavior on opacity {
                Anim {
                    duration: root.open ? Theme.durSmall : Theme.durFast
                }
            }
            Behavior on scale {
                Anim {
                    curve: root.open ? Theme.curveDecel : Theme.curveAccel
                    duration: root.open ? Theme.durOpen : Theme.durClose
                }
            }

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
                    font.weight: Font.Medium
                }

                Txt {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.kind.text
                    wrapMode: Text.Wrap
                    color: Config.textDim
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
                            color: primary ? (buttonArea.containsMouse ? Config.buttonPrimaryHover : Config.text) : (buttonArea.containsMouse ? Config.buttonHover : Config.selected)
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
                                color: button.primary ? Config.frame : Config.text
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
