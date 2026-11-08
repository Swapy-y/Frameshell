import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// ═══════════════════════════════════════════════════════════════════════════
//  LockView.qml - what the lock screen shows: the Pixie login screen
//  (github.com/xCaptaiN09/pixie-sddm, MIT) redrawn for the shell, using the
//  wallpaper, colours and fonts of the installed theme.
//
//  Pixie draws for 1920x1080; everything here is multiplied by `s` (screen
//  height / 1080), exactly like install.sh scales the SDDM login screen, so
//  both look the same on any screen.
//
//  Two states, like Pixie:
//    clock   stacked clock, date, power buttons, "Press any key to unlock"
//    login   blurred wallpaper with the card: avatar, name, password, arrow
//  Any key or a click opens the card, Escape goes back, Enter unlocks.
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: view

    required property var lock          // Lock.qml: theme, colours, state, submit()

    readonly property real s: height > 0 ? height / 1080 : 1
    // space between the date / the power buttons and the screen edges (top row)
    readonly property real edgeGap: px(38)
    function px(v) {
        return Math.round(v * s);
    }

    focus: true
    Component.onCompleted: forceActiveFocus()

    // ── fonts of the theme ────────────────────────────────────────────────
    readonly property string fontDir: lock.themeFound ? "file://" + lock.themeDir + "/assets/fonts/" : ""
    FontLoader {
        id: fontRegular
        source: view.fontDir.length > 0 ? view.fontDir + "FlexRounded-R.ttf" : ""
    }
    FontLoader {
        id: fontMedium          // the clock's weight (Medium) of the same family
        source: view.fontDir.length > 0 ? view.fontDir + "FlexRounded-M.ttf" : ""
    }
    FontLoader {
        id: fontBold
        source: view.fontDir.length > 0 ? view.fontDir + "FlexRounded-B.ttf" : ""
    }
    FontLoader {
        id: iconFont
        source: view.fontDir.length > 0 ? view.fontDir + "MaterialDesignIcons.ttf" : ""
    }
    readonly property bool iconsLoaded: iconFont.status === FontLoader.Ready

    // theme.conf fontFamily if it is installed, else the theme's font, else the shell's
    readonly property string activeFontRegular: {
        const f = lock.fontFamily;
        if (f.length > 0 && Qt.fontFamilies().indexOf(f) >= 0)
            return f;
        return fontRegular.status === FontLoader.Ready ? fontRegular.name : Theme.font;
    }
    readonly property string activeFontBold: {
        const f = lock.fontFamily;
        if (f.length > 0 && Qt.fontFamilies().indexOf(f) >= 0)
            return f;
        return fontBold.status === FontLoader.Ready ? fontBold.name : Theme.font;
    }
    // the password field's font: the one the login screen (SDDM) draws it in - your
    // system's sans font ("Sans Serif" is the name Qt gives it there). The shell's own
    // font (what Qt apps get from qt6ct) has no "●", so the dots came from another,
    // taller font and the field grew when you started typing.
    readonly property string fieldFont: "Sans Serif"

    // ── colours ───────────────────────────────────────────────────────────
    readonly property color accent: lock.accent
    readonly property color corners: lock.cornerColor      // the date, the power icons, the battery
    readonly property color field: lock.fieldColor          // the password field's border, the round button
    // the clock and the controls appear once the accent is known (never wait
    // more than 2 s, a broken wallpaper must not hide the password field)
    property bool waitedEnough: false
    readonly property bool uiReady: lock.accentReady || waitedEnough
    Timer {
        interval: 2000
        running: !view.uiReady
        onTriggered: view.waitedEnough = true
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── wallpaper ─────────────────────────────────────────────────────────
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: view.lock.background.length > 0 ? "file://" + view.lock.background : ""
        fillMode: Image.PreserveAspectCrop
        onStatusChanged: {
            if (status === Image.Ready)
                extractor.start();
            else if (status === Image.Error && view.lock.background === view.lock.desktopWallpaper)
                view.lock.brokenWallpaper = view.lock.desktopWallpaper;   // the picked one is gone: the theme's copy
            else if (status === Image.Error)
                view.waitedEnough = true;     // no wallpaper: show the controls with the theme accent
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: backgroundImage
        blurEnabled: true
        blurMax: Math.min(64, Math.round(32 * view.s))
        blur: view.lock.loginVisible ? 1.0 : 0.0
        opacity: view.lock.loginVisible ? 1.0 : 0.0
        visible: opacity > 0            // no blur work while the clock shows
        autoPaddingEnabled: false

        Behavior on opacity {
            NumberAnimation {
                duration: 400
                easing.type: Easing.InOutQuad
            }
        }
        Behavior on blur {
            NumberAnimation {
                duration: 400
                easing.type: Easing.InOutQuad
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: view.lock.loginVisible ? 0.6 : 0.4
        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
        }
    }

    // ── accent from the wallpaper (theme.conf autoColor=true) ─────────────
    // Pixie's own method: the most common vibrant hue of a 60x60 thumbnail.
    // The result is kept in Lock.qml, so it is only worked out once per wallpaper.
    Canvas {
        id: extractor
        width: 60
        height: 60
        x: -100
        y: -100
        z: -1
        renderTarget: Canvas.Image
        property int retries: 0
        readonly property bool needed: view.lock.autoColor && !view.lock.accentReady

        function start() {
            if (needed) {
                retries = 0;
                requestPaint();
            }
        }
        Component.onCompleted: {
            if (backgroundImage.status === Image.Ready)
                start();
        }

        Timer {
            id: retry
            interval: 250
            onTriggered: extractor.requestPaint()
        }

        onPaint: {
            if (!needed)
                return;
            const ctx = getContext("2d");
            const res = 60;
            ctx.clearRect(0, 0, res, res);
            ctx.drawImage(backgroundImage, 0, 0, res, res);
            const img = ctx.getImageData(0, 0, res, res).data;
            if (!img || img.length === 0) {
                retry.restart();
                return;
            }

            // all black: the GPU was not ready yet - or a truly black wallpaper
            let sum = 0;
            for (let p = 0; p < img.length; p++)
                sum += img[p];
            if (sum === 0) {
                retries++;
                if (retries > 3)
                    view.lock.setExtracted("#D0D0D0");
                else
                    retry.restart();
                return;
            }

            // 36 buckets of 10 degrees, weighted by saturation x value
            const histogram = new Array(36).fill(0);
            const samples = new Array(36).fill(null);
            let vibrant = false;
            for (let i = 0; i < img.length; i += 4) {
                const c = Qt.rgba(img[i] / 255, img[i + 1] / 255, img[i + 2] / 255, 1);
                if (c.hsvSaturation > 0.3 && c.hsvValue > 0.15) {
                    const h = c.hsvHue * 360;
                    if (h < 0)
                        continue;
                    const b = Math.floor(h / 10) % 36;
                    const w = c.hsvSaturation * c.hsvValue;
                    histogram[b] += w;
                    if (!samples[b] || w > samples[b].hsvSaturation * samples[b].hsvValue)
                        samples[b] = c;
                    vibrant = true;
                }
            }

            if (!vibrant) {
                // grey wallpaper: light or dark neutral depending on its brightness
                let total = 0;
                for (let k = 0; k < img.length; k += 4)
                    total += 0.299 * img[k] / 255 + 0.587 * img[k + 1] / 255 + 0.114 * img[k + 2] / 255;
                view.lock.setExtracted(total / (img.length / 4) < 0.5 ? "#D0D0D0" : "#404040");
                return;
            }

            histogram[0] += histogram[35];      // red wraps around
            let best = -1;
            let winner = -1;
            for (let j = 0; j < 35; j++) {
                if (histogram[j] > best) {
                    best = histogram[j];
                    winner = j;
                }
            }
            if (winner !== -1 && samples[winner]) {
                const c = samples[winner];
                const sat = Math.max(0.35, Math.min(0.55, c.hsvSaturation * 0.9));
                view.lock.setExtracted(Qt.hsva(c.hsvHue, sat, 0.95, 1));
            }
        }
    }

    // a Text whose ink (the visible shape), not its line box, is centred on its row
    component InkText: Text {
        id: inkText
        readonly property rect inkRect: inkMetrics.tightBoundingRect
        readonly property real advance: inkMetrics.advanceWidth
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: height / 2 - baselineOffset - (inkRect.y + inkRect.height / 2)
        TextMetrics {
            id: inkMetrics
            font: inkText.font
            text: inkText.text
        }
    }

    // ── power buttons (top right) ─────────────────────────────────────────
    // On the date's line (centred on its capital letters); the space right of
    // them is the same as the space above them.
    Row {
        id: powerRow
        y: dateText.y + dateText.baselineOffset + dateCaps.tightBoundingRect.y + dateCaps.tightBoundingRect.height / 2 - height / 2
        anchors.right: parent.right
        anchors.rightMargin: y + (height - inkHeight) / 2 - rightInset
        spacing: view.px(20)
        height: view.px(30)
        z: 100
        opacity: view.uiReady ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }

        // empty space right of the last icon's ink
        readonly property real rightInset: {
            if (!Config.lockPowerButtons)
                return 0;
            if (!view.iconsLoaded)
                return (view.px(20) - view.px(18)) / 2;
            return lastInk.advanceWidth - lastInk.tightBoundingRect.x - lastInk.tightBoundingRect.width;
        }
        // height of the tallest button
        readonly property real inkHeight: view.iconsLoaded ? allInk.tightBoundingRect.height : view.px(18)
        TextMetrics {
            id: allInk
            font.family: iconFont.name
            font.pixelSize: view.px(20)
            text: "󰤄󰑐󰐥"                 // suspend, restart, shut down
        }
        TextMetrics {
            id: lastInk
            font.family: iconFont.name
            font.pixelSize: view.px(20)
            text: "󰐥"                 // the last button, shut down
        }
        // battery (laptops only)
        Row {
            spacing: view.px(5)
            visible: Battery.present
            anchors.verticalCenter: parent.verticalCenter

            InkText {
                text: Math.round(Battery.level * 100) + "%"
                color: view.corners
                font.pixelSize: view.px(14)
                font.weight: Font.Medium
            }
            InkText {
                visible: view.iconsLoaded
                text: Battery.charging ? "󱐋" : "󰁹"
                color: view.corners
                font.pixelSize: view.px(18)
                font.family: iconFont.name
            }
        }

        Repeater {
            // Pixie's suspend / restart / shut down; Config.lockPowerButtons hides them
            model: Config.lockPowerButtons ? [
                {
                    glyph: "󰤄",
                    icon: "moon",
                    cmd: ["systemctl", "suspend"]
                },
                {
                    glyph: "󰑐",
                    icon: "restart",
                    cmd: ["systemctl", "reboot"]
                },
                {
                    glyph: "󰐥",
                    icon: "power",
                    cmd: ["systemctl", "poweroff"]
                }
            ] : []

            Item {
                id: powerButton
                required property var modelData
                width: view.iconsLoaded ? glyph.advance : view.px(20)
                height: view.px(30)
                anchors.verticalCenter: parent.verticalCenter

                InkText {
                    id: glyph
                    visible: view.iconsLoaded
                    text: powerButton.modelData.glyph
                    color: view.corners
                    font.pixelSize: view.px(20)
                    font.family: iconFont.name
                }
                // without the theme's icon font: the shell's own icons
                Icon {
                    anchors.centerIn: parent
                    visible: !view.iconsLoaded
                    size: view.px(18)
                    name: powerButton.modelData.icon
                    color: view.corners
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(powerButton.modelData.cmd)
                }
            }
        }
    }

    // ── date (top left) ───────────────────────────────────────────────────
    Text {
        id: dateText
        text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
        color: view.corners
        font.pixelSize: view.px(22)
        font.family: view.activeFontRegular
        anchors.top: parent.top
        anchors.left: parent.left
        // the date's ink is exactly edgeGap from the top and the left edge
        anchors.topMargin: view.edgeGap - (dateText.baselineOffset + dateInk.tightBoundingRect.y)
        anchors.leftMargin: view.edgeGap - dateInk.tightBoundingRect.x
        opacity: view.uiReady ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }
    // where the date's ink is (for the power buttons above)
    TextMetrics {
        id: dateCaps
        font: dateText.font
        text: "H"
    }
    TextMetrics {
        id: dateInk
        font: dateText.font
        text: dateText.text
    }

    // ── clock state ───────────────────────────────────────────────────────
    Item {
        id: lockState
        anchors.fill: parent
        visible: !view.lock.loginVisible
        opacity: visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
        }

        // the stacked clock: hours on top, minutes below, two tones of the accent
        Item {
            id: bigClock
            anchors.centerIn: parent
            opacity: view.uiReady ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }

            readonly property string timeStr: {
                let h = clock.hours;
                if (!view.lock.use24h) {
                    h = h % 12;
                    if (h === 0)
                        h = 12;
                }
                const m = clock.minutes;
                return (h < 10 ? "0" + h : "" + h) + (m < 10 ? "0" + m : "" + m);
            }

            // Pixie's colour rules for the two tones
            readonly property var tones: {
                const b = view.accent;
                if (b.hsvSaturation < 0.15)
                    return [Qt.lighter(b, 1.3), Qt.darker(b, 1.4)];
                if (b.hsvValue < 0.5)
                    return [Qt.hsva(b.hsvHue, 0.7, 0.9, 1), Qt.hsva(b.hsvHue, 0.45, 0.85, 1)];
                if (b.hsvValue > 0.8 && b.hsvSaturation < 0.2)
                    return [Qt.hsva(b.hsvHue, 0.8, 0.7, 1), Qt.hsva(b.hsvHue, 0.5, 0.75, 1)];
                return [Qt.hsva(b.hsvHue, Math.min(1, b.hsvSaturation * 1.3), 0.95, 1), Qt.hsva(b.hsvHue, Math.min(1, b.hsvSaturation * 0.75), 0.92, 1)];
            }

            // Tabular digits ("tnum", the clock figures of the font): each one is
            // as wide as a column (130 px) and drawn centred in it, so the hours
            // stand exactly above the minutes.
            // Pixie overlaps the two rows by 130 px (made for its own font);
            // with another font (theme missing) keep the same distance between rows
            FontMetrics {
                id: clockMetrics
                font.family: view.activeFontRegular
                font.pixelSize: view.px(200)
                font.weight: Font.Medium
            }
            readonly property real rowSpacing: view.lock.themeFound ? -view.px(130) : Math.round(view.px(215) - clockMetrics.height)

            Row {
                anchors.centerIn: parent
                spacing: 0

                Repeater {
                    model: 2        // two columns: first and second digit

                    Column {
                        id: digitColumn
                        required property int index
                        spacing: bigClock.rowSpacing

                        Repeater {
                            model: 2    // hour digit above, minute digit below

                            Text {
                                required property int index
                                text: bigClock.timeStr.charAt(index * 2 + digitColumn.index)
                                // hours (index 0) and minutes: theme.conf hourColor / minuteColor, else
                                // Pixie's tone (the minutes as white as the hours)
                                color: index === 0 ? (view.lock.hourColor !== "" ? view.lock.hourColor : bigClock.tones[0])
                                                   : (view.lock.minuteColor !== "" ? view.lock.minuteColor : bigClock.tones[0])
                                font.pixelSize: view.px(200)
                                font.family: view.activeFontRegular
                                font.weight: Font.Medium
                                font.features: ({ "tnum": 1 })
                                width: view.px(130)
                                horizontalAlignment: Text.AlignHCenter
                                antialiasing: true
                            }
                        }
                    }
                }
            }
        }

        Text {
            text: "Press any key to unlock"
            color: view.lock.textColor
            font.pixelSize: view.px(16)
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: view.px(100)
            opacity: 0.5
        }

        MouseArea {
            anchors.fill: parent
            onClicked: view.lock.showLogin()
        }
    }

    // any key opens the card - and is used up by that, like on the login screen: it
    // does not go into the password (a space to wake the screen is not its first letter)
    Keys.onPressed: event => {
        if (view.lock.loginVisible)
            return;
        view.lock.showLogin();
        event.accepted = true;
    }

    // ── login state: the card ─────────────────────────────────────────────
    Item {
        id: loginState
        anchors.fill: parent
        visible: view.lock.loginVisible
        opacity: visible ? 1 : 0
        z: 10
        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
        }

        onVisibleChanged: {
            if (visible) {
                passwordField.forceActiveFocus();
            } else {
                passwordField.text = "";
                view.forceActiveFocus();
            }
        }

        SequentialAnimation {
            id: shakeAnimation
            loops: 2
            readonly property real cx: (loginState.width - loginCard.width) / 2
            PropertyAnimation {
                target: loginCard
                property: "x"
                from: shakeAnimation.cx
                to: shakeAnimation.cx - view.px(10)
                duration: 50
                easing.type: Easing.InOutQuad
            }
            PropertyAnimation {
                target: loginCard
                property: "x"
                from: shakeAnimation.cx - view.px(10)
                to: shakeAnimation.cx + view.px(10)
                duration: 50
                easing.type: Easing.InOutQuad
            }
            PropertyAnimation {
                target: loginCard
                property: "x"
                from: shakeAnimation.cx + view.px(10)
                to: shakeAnimation.cx
                duration: 50
                easing.type: Easing.InOutQuad
            }
            onStopped: view.lock.failed = false
        }

        Connections {
            target: view.lock
            function onShake() {
                passwordField.text = "";
                passwordField.forceActiveFocus();
                shakeAnimation.restart();
            }
        }

        Rectangle {
            id: loginCard
            width: view.px(380)
            // grows when "Caps Lock is on" shows
            height: view.px(480 + (capsLockIndicator.visible ? 40 : 0))
            x: (parent.width - width) / 2
            y: (parent.height - view.px(480)) / 2
            color: view.lock.failed ? view.lock.errorColor : view.lock.baseColor
            opacity: 0.7
            radius: view.px(32)

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: view.px(40)
                spacing: view.px(15)

                // avatar: the picture, or the first letter of the user name
                Item {
                    Layout.preferredWidth: view.px(120)
                    Layout.preferredHeight: view.px(120)
                    Layout.alignment: Qt.AlignHCenter

                    Rectangle {
                        anchors.fill: parent
                        color: view.lock.surfaceColor
                        radius: width / 2
                        visible: avatar.status !== Image.Ready

                        Text {
                            anchors.centerIn: parent
                            text: view.lock.user.charAt(0).toUpperCase()
                            color: view.accent
                            font.pixelSize: view.px(48)
                            font.family: view.activeFontBold
                            font.weight: Font.Bold
                        }
                    }

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        visible: avatar.status === Image.Ready

                        Image {
                            id: avatar
                            anchors.fill: parent
                            source: view.lock.avatar.length > 0 ? "file://" + view.lock.avatar + "?" + view.lock.avatarStamp : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: view.px(240)
                            sourceSize.height: view.px(240)
                            smooth: true
                            mipmap: true
                        }
                    }
                }

                // the name (real name from /etc/passwd, like SDDM)
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: userNameLabel.width + view.px(40)
                    Layout.preferredHeight: userNameLabel.height + view.px(20)
                    Layout.topMargin: view.px(10)

                    Text {
                        id: userNameLabel
                        anchors.centerIn: parent
                        text: view.lock.shownName
                        color: "white"
                        font.pixelSize: view.px(24)
                        font.weight: Font.Bold
                        font.family: view.activeFontRegular
                    }
                }

                // the session (on the login screen you can pick it; here it is the running one)
                Rectangle {
                    visible: view.lock.sessionCount > 1
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: view.px(180)
                    Layout.preferredHeight: view.px(36)
                    color: view.lock.surfaceColor
                    radius: view.px(18)
                    border.width: Math.max(1, view.px(1))
                    border.color: view.lock.surfaceVariantColor

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: view.px(8)
                        Text {
                            visible: view.iconsLoaded
                            text: "󰟀"
                            color: view.accent
                            font.pixelSize: view.px(16)
                            font.family: iconFont.name
                        }
                        Text {
                            text: view.lock.sessionName
                            color: "white"
                            font.pixelSize: view.px(13)
                            font.weight: Font.Medium
                        }
                    }
                }

                TextField {
                    id: passwordField
                    Layout.topMargin: view.px(30)
                    Layout.fillWidth: true
                    // always as tall as the font's line: the dots (which can come from a
                    // taller font) never make it grow
                    Layout.preferredHeight: Math.ceil(fieldMetrics.height) + topPadding + bottomPadding
                    echoMode: TextInput.Password
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    padding: view.px(4)            // Qt's default (Fusion) padding, scaled
                    font.family: view.fieldFont
                    font.pixelSize: view.px(18)
                    color: "white"
                    enabled: !view.lock.loggingIn
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText

                    background: Rectangle {
                        color: view.lock.surfaceColor
                        radius: view.px(16)
                        border.width: passwordField.activeFocus ? view.px(2) : 0
                        border.color: view.field
                        opacity: passwordField.enabled ? 1.0 : 0.5
                    }

                    FontMetrics {
                        id: fieldMetrics
                        font: passwordField.font
                    }

                    Text {
                        text: "Enter Password"
                        color: "gray"
                        font.family: view.fieldFont
                        font.pixelSize: view.px(16)
                        visible: !passwordField.text
                        anchors.centerIn: parent
                        opacity: 0.5
                    }

                    onAccepted: view.lock.submit(text)
                    Keys.onEscapePressed: view.lock.hideLogin()
                    // Caps Lock turns on when it is pressed but off only when it is let go
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_CapsLock)
                            view.lock.checkCapsLock();
                    }
                    Keys.onReleased: event => {
                        if (event.key === Qt.Key_CapsLock)
                            view.lock.checkCapsLock();
                    }
                }

                Text {
                    id: capsLockIndicator
                    text: "Caps Lock is on"
                    color: view.accent
                    font.pixelSize: view.px(14)
                    font.family: view.activeFontRegular
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignHCenter
                    // fades in and out; it leaves the card (which then shrinks) only once
                    // it has faded out
                    opacity: view.lock.capsLock ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }

                RoundButton {
                    id: loginButton
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: view.px(64)
                    Layout.preferredHeight: view.px(64)
                    focusPolicy: Qt.NoFocus
                    enabled: !view.lock.loggingIn

                    contentItem: Text {
                        text: view.lock.loggingIn ? "⋯" : "→"
                        color: view.lock.loggingIn ? "white" : view.lock.accentTextColor
                        font.pixelSize: view.px(32)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: view.lock.loggingIn ? view.lock.surfaceVariantColor : (loginButton.pressed ? Qt.darker(view.field, 1.1) : view.field)
                        radius: width / 2
                        opacity: view.lock.loggingIn ? 0.5 : 1.0
                    }

                    onClicked: view.lock.submit(passwordField.text)
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }
}
