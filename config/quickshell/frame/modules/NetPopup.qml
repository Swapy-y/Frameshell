import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.components

// ═══════════════════════════════════════════════════════════════════════════
//  NetPopup.qml - the Wi-Fi / Bluetooth card. The Wi-Fi and Bluetooth buttons
//  of the island open it (Ui.netPage). Drawn like "Shut down?": a dark card in
//  the middle of the screen over a dimmed desktop. Esc, "Done" or a click
//  outside the card closes it.
//
//  Wi-Fi:      on/off switch, the cable connection (if any), then the networks:
//              connected first, saved ones, then by signal. Click a network to
//              connect (a password field opens when it needs one), click the
//              connected one to disconnect; saved networks show "Forget" on hover.
//  Bluetooth:  on/off switch, then the devices: connected, paired, then new ones
//              found while the card is open. Click to connect / disconnect; a new
//              device is paired first (put it in pairing mode), then trusted.
//
//  The data comes from services/Net.qml (NetworkManager and BlueZ).
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    id: root

    readonly property bool open: Ui.netPage !== ""

    // the page on screen; kept while the card fades out, so it never jumps
    property string page: "wifi"
    Connections {
        target: Ui

        function onNetPageChanged() {
            if (Ui.netPage !== "")
                root.page = Ui.netPage;
        }
    }

    // look for networks / devices only while their list is on screen
    Binding {
        target: Net
        property: "scanWifi"
        value: Ui.netPage === "wifi"
    }
    Binding {
        target: Net
        property: "scanBt"
        value: Ui.netPage === "bluetooth"
    }

    function close() {
        Ui.netPage = "";
    }

    // ── sizes (the card like "Shut down?", the rows like before) ──────────
    readonly property real pad: Theme.px(24)
    readonly property real cardW: Theme.px(380)
    readonly property real listW: cardW - 2 * pad
    readonly property real rowH: Theme.px(38)
    readonly property real rowGap: Theme.px(2)
    readonly property real maxListH: Math.max(1, Config.netMaxRows) * (rowH + rowGap)

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
        WlrLayershell.namespace: "frame-network"
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

        // Esc closes the card (in the password field it closes the field first)
        Item {
            id: keys
            focus: true
            Keys.onPressed: event => {
                if (root.open && event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                }
            }
        }

        // dimmed desktop; a click outside the card closes it
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
                onPressed: root.close()
            }
        }

        Rectangle {
            id: card

            readonly property real wantH: root.pad + top.height + Theme.px(16) + pages.height + Theme.px(18) + doneBtn.height + root.pad

            width: root.cardW
            height: wantH
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

            // clicks on the empty parts stay in the card (and give the keyboard
            // back to it, so Esc works)
            MouseArea {
                anchors.fill: parent
                onPressed: keys.forceActiveFocus()
            }

            // ── icon, title, what is connected, the on/off switch ─────────
            Column {
                id: top
                x: root.pad
                y: root.pad
                width: root.listW
                spacing: Theme.px(10)

                Item {
                    width: parent.width
                    height: Theme.px(30)

                    // the island's icons: Wi-Fi is wider than tall, Bluetooth taller than wide
                    Icon {
                        anchors.centerIn: parent
                        size: root.page === "wifi" ? Theme.px(36) : Theme.px(30)
                        name: root.page === "wifi" ? "wifi" : "bluetooth"
                        color: Config.text
                    }

                    Toggle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.page === "wifi" ? wifiPage.hasDevice : btPage.ready
                        enabled: root.page === "wifi" ? wifiPage.hasDevice && wifiPage.w.hardwareEnabled : btPage.ready && !btPage.b.busy
                        checked: root.page === "wifi" ? wifiPage.hasDevice && wifiPage.w.enabled : btPage.on
                        onToggled: on => {
                            if (root.page === "wifi")
                                wifiPage.w.setEnabled(on);
                            else
                                btPage.b.setEnabled(on);
                        }
                    }
                }

                Txt {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.page === "wifi" ? "Wi-Fi" : "Bluetooth"
                    font.pixelSize: Theme.px(24)
                    font.weight: Font.Medium
                }

                Txt {
                    readonly property string summary: root.page === "wifi" ? wifiPage.summary : btPage.summary
                    width: parent.width
                    visible: summary.length > 0
                    horizontalAlignment: Text.AlignHCenter
                    text: summary
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Config.textDim
                    font.pixelSize: Theme.px(17)
                }
            }

            // ── the list of the page on screen ────────────────────────────
            // its height glides when the list grows or shrinks (the card follows)
            Item {
                id: pages
                x: root.pad
                y: top.y + top.height + Theme.px(16)
                width: root.listW + Theme.px(12)        // + the scroll bar beside the list
                height: Math.max(1, root.page === "wifi" ? wifiPage.wantH : btPage.wantH)
                clip: true

                Behavior on height {
                    enabled: root.open && card.opacity > 0.99
                    Anim {
                        curve: Theme.curveDecel
                        duration: Theme.durOpen
                    }
                }

                // ── Wi-Fi ─────────────────────────────────────────────────────────────
                Item {
                    id: wifiPage
                    width: root.listW
                    height: wantH
                    visible: opacity > 0.01
                    opacity: root.page === "wifi" ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            duration: Theme.durSmall
                        }
                    }

                    readonly property var w: Net.wifi
                    readonly property bool ready: w !== null && w.running
                    readonly property bool hasDevice: ready && w.device !== null
                    readonly property string message: w === null ? "Wi-Fi needs Quickshell's network module" : !w.running ? "NetworkManager isn't running" : w.device === null ? (w.wiredConnected ? "" : "No Wi-Fi adapter") : !w.hardwareEnabled ? "Wi-Fi is switched off on the computer" : !w.enabled ? "Wi-Fi is off" : w.networks.length === 0 ? "Looking for networks…" : ""
                    readonly property var nets: hasDevice && w.enabled ? w.networks : []
                    // room for the password field and an error line on top of the rows
                    readonly property real extraH: wifiPage.ready ? (w.askNet !== null ? Theme.px(46) : 0) + (w.errorNet !== null && w.errorText.length > 0 ? Theme.px(22) : 0) : 0
                    readonly property real listH: Math.min(wifiList.contentHeight, root.maxListH + extraH)
                    readonly property real wantH: listH + (message.length > 0 ? Theme.px(34) : 0)
                    // under the title: what you are connected to
                    readonly property string summary: !ready ? "" : w.current !== null ? "Connected to " + w.current.name : w.wiredConnected ? "Connected by cable" : !hasDevice ? "" : !w.enabled ? "Off" : "Not connected"

                    ListView {
                        id: wifiList
                        x: 0
                        y: 0
                        width: root.listW
                        height: wifiPage.listH
                        clip: true
                        spacing: root.rowGap
                        boundsBehavior: Flickable.StopAtBounds
                        model: wifiPage.nets

                        // the cable, when one is plugged in
                        header: Item {
                            width: wifiList.width
                            height: wifiPage.ready && wifiPage.w.wiredConnected ? root.rowH + root.rowGap : 0
                            visible: height > 0

                            ListRow {
                                width: parent.width
                                title: "Wired connection"
                                status: "Connected"
                                highlighted: true

                                Icon {
                                    anchors.centerIn: parent
                                    size: Theme.px(16)
                                    name: "ethernet"
                                }
                            }
                        }

                        delegate: Column {
                            id: netItem
                            required property var modelData
                            readonly property var net: modelData
                            readonly property var w: wifiPage.w
                            readonly property bool asking: w.askNet === net
                            readonly property bool failed: w.errorNet === net && w.errorText.length > 0

                            width: wifiList.width
                            spacing: 0

                            // the password field takes the keyboard as soon as it opens, and gives
                            // it back to the card when it closes (so Esc closes the card again)
                            onAskingChanged: {
                                if (asking)
                                    Qt.callLater(() => pass.forceActiveFocus());
                                else if (pass.activeFocus)
                                    keys.forceActiveFocus();
                            }

                            ListRow {
                                title: netItem.net.name
                                highlighted: netItem.net.connected
                                showLock: netItem.w.secured(netItem.net) && !netItem.net.known
                                status: netItem.net.stateChanging ? (netItem.net.connected ? "Disconnecting…" : "Connecting…") : netItem.net.connected ? "Connected" : ""
                                hoverStatus: netItem.net.connected && !netItem.net.stateChanging ? "Disconnect" : ""
                                sideAction: netItem.net.known && !netItem.net.connected && !netItem.net.stateChanging ? "Forget" : ""
                                onClicked: netItem.w.activate(netItem.net)
                                onSideClicked: netItem.w.forget(netItem.net)

                                WifiIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: Theme.px(17)
                                    level: netItem.w.level(netItem.net.signalStrength)
                                }
                            }

                            // password: Enter (or the button) connects, Esc closes the field
                            Item {
                                width: parent.width
                                height: netItem.asking ? Theme.px(46) : 0
                                visible: netItem.asking

                                Rectangle {
                                    id: field
                                    x: Theme.px(4)
                                    y: Theme.px(6)
                                    width: parent.width - joinBtn.width - Theme.px(14)
                                    height: Theme.px(34)
                                    radius: Theme.px(10)
                                    color: Config.selected
                                    border.width: Theme.border
                                    border.color: pass.activeFocus ? Config.fieldFocus : Config.selected

                                    TextInput {
                                        id: pass
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.px(12)
                                        anchors.rightMargin: Theme.px(12)
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: TextInput.Password
                                        passwordCharacter: "•"
                                        color: Config.text
                                        selectionColor: Config.textSelection
                                        selectedTextColor: Config.text
                                        font.family: Theme.font
                                        font.pixelSize: Theme.px(15)
                                        renderType: Text.QtRendering
                                        clip: true
                                        focus: netItem.asking

                                        Component.onCompleted: {
                                            if (netItem.asking)
                                                Qt.callLater(() => forceActiveFocus());
                                        }

                                        Keys.onReturnPressed: netItem.w.submit(netItem.net, text)
                                        Keys.onEnterPressed: netItem.w.submit(netItem.net, text)
                                        Keys.onEscapePressed: netItem.w.cancelAsk()
                                    }

                                    Txt {
                                        anchors.fill: pass
                                        visible: pass.text.length === 0
                                        text: "Password"
                                        color: Config.textFaint
                                        font.pixelSize: Theme.px(15)
                                    }
                                }

                                Rectangle {
                                    id: joinBtn
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.px(4)
                                    y: field.y
                                    width: joinText.implicitWidth + Theme.px(24)
                                    height: field.height
                                    radius: Theme.px(10)
                                    color: pass.text.length > 0 ? Config.text : Config.buttonDisabled
                                    scale: joinArea.pressed ? 0.95 : 1

                                    Behavior on color {
                                        CAnim {}
                                    }

                                    Txt {
                                        id: joinText
                                        anchors.centerIn: parent
                                        text: "Join"
                                        font.pixelSize: Theme.px(14)
                                        font.weight: Font.Medium
                                        color: pass.text.length > 0 ? Config.frame : Config.textDim
                                    }

                                    MouseArea {
                                        id: joinArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: netItem.w.submit(netItem.net, pass.text)
                                    }
                                }
                            }

                            // why the last attempt failed
                            Txt {
                                width: parent.width
                                height: netItem.failed ? Theme.px(22) : 0
                                visible: netItem.failed
                                leftPadding: Theme.px(10)
                                text: netItem.failed ? netItem.w.errorText : ""
                                font.pixelSize: Theme.fsTiny + 1
                                color: Config.warning
                                elide: Text.ElideRight
                            }
                        }
                    }

                    ScrollFade {
                        list: wifiList
                    }
                    ListScrollBar {
                        list: wifiList
                    }

                    Note {
                        y: wifiPage.listH
                        visible: wifiPage.message.length > 0
                        text: wifiPage.message
                    }
                }

                // ── Bluetooth ─────────────────────────────────────────────────────────
                Item {
                    id: btPage
                    width: root.listW
                    height: wantH
                    visible: opacity > 0.01
                    opacity: root.page === "bluetooth" ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            duration: Theme.durSmall
                        }
                    }

                    readonly property var b: Net.bt
                    readonly property bool ready: b !== null && b.available
                    readonly property bool on: ready && b.enabled
                    readonly property bool searching: on && b.adapter.discovering
                    readonly property string message: b === null ? "Bluetooth needs Quickshell's Bluetooth module" : !b.available ? "No Bluetooth adapter (is bluetooth.service running?)" : !b.enabled ? "Bluetooth is off" : b.devices.length === 0 ? "Looking for devices…" : searching ? "Looking for new devices…" : ""
                    readonly property var devs: on ? b.devices : []
                    readonly property real listH: Math.min(btList.contentHeight, root.maxListH + (ready && b.errorDev !== null && b.errorText.length > 0 ? Theme.px(22) : 0))
                    readonly property real wantH: listH + (message.length > 0 ? Theme.px(34) : 0)
                    // under the title: what is connected
                    readonly property string summary: {
                        if (!ready)
                            return "";
                        if (!on)
                            return "Off";
                        const c = b.connectedDevices;
                        return c.length === 1 ? "Connected to " + b.label(c[0]) : c.length > 1 ? c.length + " devices connected" : "On";
                    }

                    ListView {
                        id: btList
                        x: 0
                        y: 0
                        width: root.listW
                        height: btPage.listH
                        clip: true
                        spacing: root.rowGap
                        boundsBehavior: Flickable.StopAtBounds
                        model: btPage.devs

                        delegate: Column {
                            id: devItem
                            required property var modelData
                            readonly property var dev: modelData
                            readonly property var b: btPage.b
                            readonly property bool known: dev.paired || dev.bonded
                            readonly property bool failed: b.errorDev === dev && b.errorText.length > 0
                            readonly property string battery: dev.connected && dev.batteryAvailable ? Math.round(dev.battery * 100) + "%  ·  " : ""
                            readonly property string glyph: b.glyph(dev)

                            width: btList.width

                            ListRow {
                                readonly property string busyText: devItem.b.stateText(devItem.dev)
                                readonly property bool idle: busyText.length === 0
                                title: devItem.b.label(devItem.dev)
                                highlighted: devItem.dev.connected
                                status: !idle ? busyText : devItem.dev.connected ? devItem.battery + "Connected" : ""
                                hoverStatus: devItem.dev.pairing ? "Cancel" : !idle ? "" : devItem.dev.connected ? "Disconnect" : !devItem.known ? "Pair" : ""
                                sideAction: idle && devItem.known && !devItem.dev.connected ? "Forget" : ""
                                onClicked: devItem.b.activate(devItem.dev)
                                onSideClicked: devItem.b.forget(devItem.dev)

                                // the kind of device (headphones, mouse …), else the Bluetooth sign
                                Icon {
                                    anchors.centerIn: parent
                                    size: devItem.glyph === "bluetooth" ? Theme.px(15) : Theme.px(18)
                                    name: devItem.glyph
                                    color: Config.text
                                }
                            }

                            Txt {
                                width: parent.width
                                height: devItem.failed ? Theme.px(22) : 0
                                visible: devItem.failed
                                leftPadding: Theme.px(10)
                                text: devItem.failed ? devItem.b.errorText : ""
                                font.pixelSize: Theme.fsTiny + 1
                                color: Config.warning
                                elide: Text.ElideRight
                            }
                        }
                    }

                    ScrollFade {
                        list: btList
                    }
                    ListScrollBar {
                        list: btList
                    }

                    Note {
                        y: btPage.listH
                        visible: btPage.message.length > 0
                        text: btPage.message
                    }
                }
            }

            // ── Done ──────────────────────────────────────────────────────
            Rectangle {
                id: doneBtn
                x: root.pad
                y: pages.y + pages.height + Theme.px(18)
                width: root.listW
                height: Theme.px(42)
                radius: Theme.px(14)
                color: doneArea.containsMouse ? Config.buttonHover : Config.selected
                scale: doneArea.pressed ? 0.97 : 1

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
                    text: "Done"
                    font.pixelSize: Theme.px(17)
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: doneArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.open
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }
    }

    // ── building blocks ───────────────────────────────────────────────────
    // one network / device
    component ListRow: Item {
        id: row
        property string title
        property string status            // right side, dim
        property string hoverStatus       // right side while the pointer is on the row
        property string sideAction        // e.g. "Forget": its own click, shown on hover
        property bool highlighted         // connected: grey background
        property bool showLock
        default property alias icon: iconSlot.data
        readonly property bool hovered: rowArea.containsMouse || sideArea.containsMouse
        signal clicked
        signal sideClicked

        width: parent ? parent.width : 0
        height: root.rowH

        Rectangle {
            anchors.fill: parent
            radius: Theme.px(10)
            color: row.highlighted ? Config.selected : Config.hover
            opacity: row.highlighted ? 1 : (row.hovered ? 1 : 0)

            Behavior on opacity {
                Anim {
                    duration: Theme.durFast
                }
            }
        }

        Item {
            id: iconSlot
            x: Theme.px(10)
            width: Theme.px(18)
            height: parent.height
        }

        Txt {
            id: nameText
            anchors.left: iconSlot.right
            anchors.leftMargin: Theme.px(10)
            anchors.right: side.left
            anchors.rightMargin: Theme.px(8)
            anchors.verticalCenter: parent.verticalCenter
            text: row.title
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.pixelSize: Theme.px(15)
            color: Config.text
        }

        // right side: status text, or the lock of a secured network
        Item {
            id: side
            anchors.right: parent.right
            anchors.rightMargin: Theme.px(10)
            height: parent.height
            width: Math.max(statusText.visible ? statusText.implicitWidth : 0, lock.visible ? lock.width : 0, sideText.visible ? sideText.implicitWidth : 0)

            readonly property string shownStatus: row.hovered && row.hoverStatus.length > 0 ? row.hoverStatus : row.status

            Txt {
                id: statusText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !sideText.visible && side.shownStatus.length > 0
                text: side.shownStatus
                font.pixelSize: Theme.fsTiny + 1
                color: Config.textDim
            }

            Icon {
                id: lock
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: row.showLock && !statusText.visible && !sideText.visible
                size: Theme.px(12)
                name: "lock"
                color: Config.textDim
            }

            Txt {
                id: sideText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: row.hovered && row.sideAction.length > 0
                text: row.sideAction
                font.pixelSize: Theme.fsTiny + 1
                color: sideArea.containsMouse ? Config.text : Config.textDim
            }
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }

        // on top of the row's own click area
        MouseArea {
            id: sideArea
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: sideText.implicitWidth + Theme.px(20)
            height: parent.height
            enabled: row.sideAction.length > 0 && row.hovered
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.sideClicked()
        }
    }

    // a grey line of text: "Wi-Fi is off", "Looking for networks…"
    component Note: Txt {
        x: 0
        width: root.listW
        height: Theme.px(34)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fsSmall
        color: Config.textDim
    }

    // the bottom of a list fades out while there is more to scroll to
    component ScrollFade: Rectangle {
        required property ListView list
        x: list.x
        y: list.y + list.height - height
        width: list.width
        height: Theme.px(22)
        opacity: list.contentHeight > list.height + 1 && !list.atYEnd ? 1 : 0
        visible: opacity > 0.01
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(Config.surface.r, Config.surface.g, Config.surface.b, 0)
            }
            GradientStop {
                position: 1
                color: Config.surface
            }
        }

        Behavior on opacity {
            Anim {
                duration: Theme.durFast
            }
        }
    }

    // a thin bar in the right margin showing where you are in a long list
    component ListScrollBar: Rectangle {
        required property ListView list
        readonly property bool overflows: list.contentHeight > list.height + 1
        x: list.x + list.width + Theme.px(5)
        y: list.y + Math.max(0, list.visibleArea.yPosition) * list.height
        width: Theme.px(3)
        height: Math.min(list.visibleArea.heightRatio, 1 - Math.max(0, list.visibleArea.yPosition)) * list.height
        radius: width / 2
        color: Config.scrollbar
        opacity: overflows ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            Anim {
                duration: Theme.durFast
            }
        }
    }
}
