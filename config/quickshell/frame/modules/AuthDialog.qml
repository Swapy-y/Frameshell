import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

// ═══════════════════════════════════════════════════════════════════════════
//  AuthDialog.qml - the password dialog for apps that need admin rights
//  (pkexec, saving a system file, installing software). It is drawn like the
//  launcher: a black rounded card that grows out of the island
//  (components/IslandSheet.qml), or with Island popups off (Config.dynamicPopups)
//  sits in the middle of the screen over a dimmed desktop, with only the lock, "Authentication required", the password field
//  and the two buttons (the password is asked for the account polkit picks).
//
//  Type the password and press Enter (or Authenticate); Esc or Cancel says no.
//  A wrong password shakes the card and you can try again.
//
//  This file only draws the dialog. PolkitAuth.qml is the agent that receives
//  the requests and sets `flow` (a Quickshell AuthFlow, null when nothing is
//  being asked).
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    id: root

    property var flow: null
    readonly property bool open: flow !== null && flow !== undefined

    property bool busy: false           // password sent, waiting for the answer
    property string errorText: ""

    // what the card shows; kept while it fades out after the request is done
    property string prompt: ""
    property bool showInput: false      // the request wants the typed text visible (not a password)

    onFlowChanged: {
        if (!flow)
            return;
        busy = false;
        errorText = "";
        refreshPrompt();
        input.text = "";
        focusTimer.restart();
    }

    function refreshPrompt() {
        if (!flow)
            return;
        // "Password: " -> "Password"
        const p = (flow.inputPrompt || "").replace(/[:\s]+$/, "");
        prompt = p.length > 0 ? p : "Password";
        showInput = !!flow.responseVisible;
        if (flow.supplementaryMessage && flow.supplementaryMessage.length > 0)
            errorText = flow.supplementaryMessage;
    }

    function submit() {
        if (!flow || busy || !flow.isResponseRequired)
            return;
        busy = true;
        errorText = "";
        flow.submit(input.text);
    }

    function cancel() {
        if (flow)
            flow.cancelAuthenticationRequest();
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true

        function onIsResponseRequiredChanged() {
            if (root.flow.isResponseRequired) {
                root.busy = false;
                root.refreshPrompt();
                focusTimer.restart();
            }
        }
        function onInputPromptChanged() {
            root.refreshPrompt();
        }
        function onResponseVisibleChanged() {
            root.refreshPrompt();
        }
        function onSupplementaryMessageChanged() {
            root.refreshPrompt();
        }
        function onAuthenticationFailed() {
            root.busy = false;
            root.errorText = "Wrong password, try again";
            input.text = "";
            shake.restart();
            focusTimer.restart();
        }
    }

    // the keyboard arrives a moment after the window maps
    Timer {
        id: focusTimer
        interval: 50
        onTriggered: input.forceActiveFocus()
    }

    PanelWindow {
        id: win
        // black like the frame, in every theme: the frame's colours for its pieces too
        readonly property bool framePalette: true

        visible: root.open || sheet.shown

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "frame-auth"
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

        // dimmed desktop; it catches every click while the dialog is open
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
                onPressed: input.forceActiveFocus()
            }
        }

        // the card: out of the island, or in the middle (Island popups, components/IslandSheet.qml)
        IslandSheet {
            id: sheet
            open: root.open
            sheetW: card.width
            sheetH: sheet.contentTop + card.height
            cardRadius: Theme.px(22)

            Item {
                id: card

                readonly property real pad: Theme.px(20)
                readonly property real innerW: width - 2 * pad
                property real shakeX: 0

                width: Theme.px(360)
                height: column.height + 2 * pad
                x: Math.round(shakeX)
                y: sheet.contentTop



                // a wrong password: a short shake
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: card; property: "shakeX"; to: -Theme.px(10); duration: 50 }
                    NumberAnimation { target: card; property: "shakeX"; to: Theme.px(10); duration: 70 }
                    NumberAnimation { target: card; property: "shakeX"; to: -Theme.px(6); duration: 60 }
                    NumberAnimation { target: card; property: "shakeX"; to: Theme.px(4); duration: 50 }
                    NumberAnimation { target: card; property: "shakeX"; to: 0; duration: 40 }
                }

                // swallow clicks so they do not reach the backdrop
                MouseArea {
                    anchors.fill: parent
                    onPressed: input.forceActiveFocus()
                }

                Column {
                    id: column
                    x: card.pad
                    y: card.pad
                    width: card.innerW
                    spacing: Theme.px(8)

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: Theme.px(26)
                        name: "lock"
                        color: Config.text
                    }

                    Txt {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Authentication required"
                        font.pixelSize: Theme.px(20)
                        font.family: Theme.fontDisplay
                        font.weight: Font.Medium
                    }

                    Item {
                        width: 1
                        height: Theme.px(4)
                    }

                    // password field, like the launcher's search bar: a filled field, no outline
                    Rectangle {
                        width: parent.width
                        height: Theme.px(40)
                        radius: Theme.px(12)
                        color: Config.frameColors.controlBackground

                        TextInput {
                            id: input
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(14)
                            anchors.rightMargin: Theme.px(14)
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: root.showInput ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "•"
                            enabled: root.open && !root.busy
                            color: Config.text
                            selectionColor: Config.frameColors.selectionBackground
                            selectedTextColor: Config.text
                            font.family: Theme.font
                            font.pixelSize: Theme.px(17)
                            renderType: Text.QtRendering
                            clip: true

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    root.cancel();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.submit();
                                    event.accepted = true;
                                }
                            }
                        }

                        Txt {
                            anchors.fill: input
                            visible: input.text.length === 0
                            text: root.busy ? "Checking…" : root.prompt
                            color: Config.frameColors.textTertiary
                            font.pixelSize: Theme.px(17)
                        }
                    }

                    // wrong password / messages from the system
                    Txt {
                        width: parent.width
                        height: Theme.px(16)
                        horizontalAlignment: Text.AlignHCenter
                        text: root.errorText
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Config.frameColors.warning
                        font.pixelSize: Theme.px(13)
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.px(8)

                        Repeater {
                            model: [
                                { label: "Cancel", primary: false },
                                { label: "Authenticate", primary: true }
                            ]

                            Rectangle {
                                id: button
                                required property var modelData
                                readonly property bool usable: !modelData.primary || (input.text.length > 0 && !root.busy)

                                width: (parent.width - parent.spacing) / 2
                                height: Theme.px(36)
                                radius: Theme.px(12)
                                color: modelData.primary
                                    ? Config.text
                                    : (buttonArea.containsMouse ? Config.frameColors.controlHover : Config.frameColors.controlBackground)
                                border.width: modelData.primary ? 0 : Theme.outlineW
                                border.color: Theme.outlineColor
                                opacity: usable ? 1 : 0.45
                                scale: buttonArea.pressed && usable ? 0.97 : 1

                                Behavior on color {
                                    CAnim {}
                                }
                                Behavior on opacity {
                                    Anim {
                                        duration: Theme.durFast
                                    }
                                }
                                Behavior on scale {
                                    Anim {
                                        duration: Theme.durFast
                                    }
                                }

                                Txt {
                                    anchors.centerIn: parent
                                    text: button.modelData.label
                                    color: button.modelData.primary ? Config.frameColors.background : Config.text
                                    font.pixelSize: Theme.px(15)
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: buttonArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: button.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (!button.usable)
                                            return;
                                        if (button.modelData.primary)
                                            root.submit();
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
