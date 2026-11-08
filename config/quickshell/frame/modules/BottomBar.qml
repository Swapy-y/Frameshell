import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.components
import "../components/shapes.js" as Shapes

// ═══════════════════════════════════════════════════════════════════════════
//  BottomBar.qml - content of the bar at the bottom:
//    power button (left) · pinned apps | running apps (centre) · date (right)
//
//  The dark bar itself is part of the frame drawn by Overlay.qml.
//  The apps row adapts to the number of open apps: icons are centred and
//  squeeze together when there are very many.
//  Click an app to focus it, middle-click to close it. Pinned apps (the Settings
//  app's Dock page, Store.dockPinned) stay when they are closed: a click opens them.
//
//  Auto hide (the Settings app): Overlay.qml moves the frame's bottom edge
//  (`frameBottom`) and the bar rides on it, fading in as it comes up (`reveal`).
//
//  Notch mode (the Settings app, Store.dockNotch): only the apps stay, in a notch
//  at the bottom centre (drawn by Overlay.qml, as wide as `notchWidth`); the power
//  button and the date become blocks in the bottom corners (PowerCorner.qml,
//  DateCorner.qml). `notch` goes from 0 (bar) to 1 (notch) while it changes.
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    property real frameBottom: Theme.bar     // where the dock's top edge is (the bar's / notch's top)
    property real reveal: 1                  // 0 = hidden (auto hide), 1 = there
    property real notch: 0                   // 0 = bar, 1 = notch (notch mode)
    property real shownWidth: width          // how wide the dock is drawn round the middle (the notch while it grows)

    x: 0
    y: parent.height - frameBottom
    width: parent.width
    height: Theme.bar
    opacity: Math.max(0, Math.min(1, (reveal - 0.3) / 0.7))
    visible: opacity > 0.01

    // the round power button and the date's pill: no outline; light grey while
    // their panel is open, a little bigger under the pointer
    readonly property real buttonH: Theme.px(32)
    readonly property real sideGap: Theme.px(8)

    // ── notch mode ────────────────────────────────────────────────────────
    // The notch is as wide as the apps need (with a little air at its ends), at
    // least as wide as one app (with the same air), and never wider than the screen
    // less room for the corner blocks. It keeps the screen's odd/even-ness, so it
    // sits on whole pixels. It follows the apps as they grow in and shrink away
    // (their own animation), so it needs none of its own.
    readonly property real notchPad: Theme.px(16)
    readonly property real notchMin: appsArea.basePitch + 2 * notchPad
    readonly property real notchMax: Math.max(notchMin, width - 2 * Theme.px(190))
    readonly property real notchWidth: Shapes.sameParity(Shapes.clamp(appsArea.width + 2 * notchPad, notchMin, notchMax), width)

    // ── power button ──────────────────────────────────────────────────────
    // The island's round button without its ring. (Notch mode: PowerCorner.qml.)
    Item {
        id: powerButton
        x: root.sideGap
        width: root.buttonH
        height: Theme.bar
        z: 5
        opacity: 1 - root.notch
        visible: root.notch < 1

        RingButton {
            y: Math.round((parent.height - height) / 2)
            width: root.buttonH
            // the Frameshell logo (2 px smaller than the power sign: it fills its square) -
            // or, switched off in the Settings app (Appearance), the power sign
            icon: Store.powerLogo ? "power-logo" : "power"
            iconSize: Store.powerLogo ? Theme.px(16) : Theme.px(18)
            iconColor: Config.text
            outline: false
            // no fill, also while the power menu is open (see-through, so the bar shows -
            // with the shell's blur too)
            offColor: "transparent"
            hoverColor: offColor
            interactive: false
            hot: powerArea.containsMouse
            down: powerArea.pressed
        }

        // the clickable area reaches the left edge of the screen (the button stays where it is),
        // so you can throw the pointer into the corner and click
        MouseArea {
            id: powerArea
            x: -powerButton.x
            width: parent.width + powerButton.x + Theme.px(6)
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Ui.togglePower()
        }
    }

    // ── apps ──────────────────────────────────────────────────────────────
    // The pinned apps (the Settings app's Dock page), a line, then the other
    // windows. A pinned app's icon stands for its first window (grey while you are
    // on it); its other windows are after the line, like any app's. A pinned app
    // that is not open is a bit darker.
    //
    // Both are lists that change one app at a time (not made again): the icons
    // that stay keep their place and slide over, a new one grows into its place and
    // one that goes shrinks away there - the first and the last window after the
    // line together with the line, the same way (Theme.durDockIn with a little
    // spring, Theme.durDockOut). The pinned apps are kept by their .desktop id, so
    // the apps being read again changes nothing in the dock.
    ListModel {
        id: pinsModel           // rows: { key: .desktop id, leaving, animate }
    }
    ListModel {
        id: othersModel         // rows: { key: number, leaving, animate }
    }
    property var othersWin: ({})        // key -> its window
    property int othersNext: 1

    // keep `model` in step with `wanted`: a row whose app is gone is marked
    // `leaving` (its cell shrinks away, then drops it); new ones go in their place,
    // moved ones to theirs; one that was going away grows back
    function syncRows(model, wanted, matches, makeRow, animate) {
        for (let i = 0; i < model.count; i++) {
            const row = model.get(i);
            if (!row.leaving && !wanted.some(w => matches(row, w)))
                model.setProperty(i, "leaving", true);
        }
        let at = 0;
        for (let i = 0; i < wanted.length; i++) {
            let found = -1;
            for (let k = 0; k < model.count; k++) {
                if (matches(model.get(k), wanted[i])) {
                    found = k;
                    break;
                }
            }
            if (found < 0) {
                const row = makeRow(wanted[i]);
                row.leaving = false;
                row.animate = animate;
                model.insert(at, row);
                at++;
                continue;
            }
            if (model.get(found).leaving)
                model.setProperty(found, "leaving", false);
            let between = false;
            for (let k = at; k < found; k++) {
                if (!model.get(k).leaving) {
                    between = true;
                    break;
                }
            }
            if (found < at) {
                model.move(found, at - 1, 1);       // one that was going away, back in its place
            } else if (between) {
                model.move(found, at, 1);           // moved (the arrows in the Settings app)
                at++;
            } else {
                at = found + 1;
            }
        }
    }

    function syncPins(animate) {
        syncRows(pinsModel, Apps.pinnedIds, (row, id) => row.key === id, id => ({
                    key: id
                }), animate);
    }

    function syncOthers(animate) {
        syncRows(othersModel, Apps.unpinned, (row, w) => root.othersWin[row.key] === w, w => {
            const key = root.othersNext++;
            root.othersWin[key] = w;
            return {
                key: key
            };
        }, animate);
    }

    // (the row's cell is gone with it: nothing may run in the cell after this)
    function dropRow(model, key) {
        for (let k = 0; k < model.count; k++) {
            if (model.get(k).key === key) {
                model.remove(k);
                break;
            }
        }
    }

    function dropOther(key) {
        delete othersWin[key];
        dropRow(othersModel, key);
    }

    Connections {
        target: Apps
        function onPinnedIdsChanged() {
            root.syncPins(root.settled);
        }
        function onUnpinnedChanged() {
            root.syncOthers(root.settled);
        }
    }
    // what is there when the shell starts (the apps and windows come in a moment
    // later) is just there; after that they grow in
    property bool settled: false
    Timer {
        interval: 1500
        running: true
        onTriggered: root.settled = true
    }
    Component.onCompleted: {
        syncPins(false);
        syncOthers(false);
        lineP = appsArea.split ? 1 : 0;
    }

    // the line: 0 - 1, opening and shutting like an app's icon growing in / shrinking away
    property real lineP: 0
    NumberAnimation {
        id: lineAnim
        target: root
        property: "lineP"
        easing.type: Easing.BezierSpline
    }
    function lineTo(on) {
        lineAnim.stop();
        if (!settled) {
            lineP = on ? 1 : 0;
            return;
        }
        lineAnim.to = on ? 1 : 0;
        lineAnim.duration = on ? Theme.durDockIn : Theme.durDockOut;
        lineAnim.easing.bezierCurve = on ? Theme.curveSpring : Theme.curveStandard;
        lineAnim.start();
    }

    // what shows of the apps: the notch's width while it grows out of the middle
    // of the edge (auto hide in notch mode, like a panel); the bar: all of it
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, root.shownWidth)
        height: parent.height
        clip: true

        Row {
            id: appsArea
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height

            // keep clear of the power button and the date (notch mode: inside the notch)
            readonly property real maxWidth: Store.dockNotch ? root.notchMax - 2 * root.notchPad : root.width - 2 * Theme.px(190)
            readonly property var pins: Apps.pinnedIds
            readonly property int count: pins.length + Apps.unpinned.length

            // icon size (Config.dockIconSize, scaled with the screen), the square
            // behind it (as tall as the bar allows) and the distance between apps
            readonly property real iconSize: Theme.px(Config.dockIconSize)
            readonly property real squareH: Math.min(iconSize + Theme.px(6), Theme.bar - Theme.px(6))
            readonly property real basePitch: iconSize + Theme.px(14)

            // the line: only while there are pinned apps and others; its room opens and shuts
            readonly property bool split: pins.length > 0 && Apps.unpinned.length > 0
            readonly property real lineRoom: Theme.px(12)
            onSplitChanged: root.lineTo(split)

            readonly property real pitch: count > 0 ? Math.min(basePitch, (maxWidth - (split ? lineRoom : 0)) / count) : basePitch

            Repeater {
                model: pinsModel

                DockCell {
                    required property string key
                    required property bool leaving
                    required property bool animate
                    pinned: true
                    entry: Apps.entryById(key)
                    going: leaving
                    animateIn: animate
                    onGone: root.dropRow(pinsModel, key)
                    pitch: appsArea.pitch
                    squareH: appsArea.squareH
                    iconSize: appsArea.iconSize
                }
            }

            // the line between them: thin, rounded at its top and bottom
            Item {
                width: root.lineP * appsArea.lineRoom
                height: parent.height

                Rectangle {
                    x: Math.round((parent.width - width) / 2)
                    y: Math.round((parent.height - height) / 2)
                    width: Theme.px(2)
                    height: Math.round(appsArea.squareH * 0.6)
                    radius: width / 2
                    color: Config.dockLine
                    antialiasing: true
                    opacity: root.lineP
                    visible: opacity > 0.01
                }
            }

            Repeater {
                model: othersModel

                DockCell {
                    required property int key
                    required property bool leaving
                    required property bool animate
                    window: root.othersWin[key]
                    going: leaving
                    animateIn: animate
                    pitch: appsArea.pitch
                    squareH: appsArea.squareH
                    iconSize: appsArea.iconSize
                    onGone: root.dropOther(key)
                }
            }
        }
    }

    // One app in the dock: a pinned app (`entry`, with its first window) or another
    // window (`window`). Click: go to it (a pinned app without a window: open it);
    // middle-click: close it.
    component DockCell: Item {
        id: cell

        property bool pinned: false         // a pinned app (`entry`), else a window after the line
        property var entry: null
        property var window: null
        property real pitch: 0
        property real squareH: 0
        property real iconSize: 0

        // a window after the line: `animateIn` grows it into its place, `going`
        // shrinks it away there; then `gone` (the dock takes it out)
        property bool animateIn: false
        property bool going: false
        signal gone

        // the room it takes (0 - 1); its icon fades and grows with it
        property real grow: animateIn ? 0 : 1
        // growing in: quick, with a little spring; shrinking away: quicker
        NumberAnimation {
            id: growAnim
            target: cell
            property: "grow"
            easing.type: Easing.BezierSpline
        }
        function growTo(v) {
            growAnim.stop();
            growAnim.to = v;
            growAnim.duration = v > 0 ? Theme.durDockIn : Theme.durDockOut;
            growAnim.easing.bezierCurve = v > 0 ? Theme.curveSpring : Theme.curveStandard;
            growAnim.start();
        }
        Timer {
            id: goneTimer
            interval: Theme.durDockOut + 50
            onTriggered: cell.gone()
        }
        onGoingChanged: {
            growTo(going ? 0 : 1);
            if (going) {
                inf = inf;                  // keeps its icon while its window goes away
                goneTimer.restart();
            } else {
                inf = Qt.binding(() => cell.info());
                goneTimer.stop();
            }
        }

        // the window it stands for (null: a pinned app that is not open)
        readonly property var win: pinned ? (entry ? Apps.pinnedWindowOf(entry.id) : null) : window
        function info() {
            return pinned ? Apps.entryInfo(entry) : Apps.info(window);
        }
        property var inf: info()
        readonly property bool current: win !== null && win === Apps.focused
        readonly property bool minimized: win !== null && Apps.isMinimized(win)

        // a pinned app that was just opened: until its window is there (it is not
        // darker meanwhile, and a second click does not open it twice)
        property bool starting: false
        onWinChanged: {
            if (win)
                starting = false;
        }
        Timer {
            id: startingTimer
            interval: 8000
            onTriggered: cell.starting = false
        }

        // a pinned app that is not open: a bit darker (as the others under the pointer)
        property real dark: pinned && win === null && !starting && !cellArea.containsMouse ? 1 : 0
        Behavior on dark {
            Anim {
                duration: Theme.durSmall
            }
        }

        width: pitch * grow
        height: Theme.bar

        Component.onCompleted: {
            if (animateIn)
                growTo(1);
        }

        // (squared: a white icon at a fifth still shows on the dark bar, the grey line
        // doesn't - so they come and go together)
        Item {
            anchors.fill: parent
            opacity: cell.grow * cell.grow
            scale: 0.6 + 0.4 * cell.grow

            // the "square" of the concept
            Rectangle {
                id: square
                anchors.centerIn: parent
                width: Math.min(cell.squareH + Theme.px(2), cell.pitch - Theme.px(4))
                height: cell.squareH
                radius: Theme.px(8)
                color: Config.plainSquares ? (cell.current ? "#ffffff" : "#c9c9c9") : (cell.current ? Config.selected : (cellArea.containsMouse ? Config.hover : "transparent"))

                // dips when pressed
                scale: cellArea.pressed ? 0.92 : 1

                // a minimized window (SUPER+H) is shown faded; click it to bring it back
                opacity: cell.minimized && !cellArea.containsMouse ? 0.4 : 1
                Behavior on opacity {
                    Anim {
                        duration: Theme.durSmall
                    }
                }

                Behavior on color {
                    CAnim {}
                }
                Behavior on scale {
                    Anim {
                        duration: Theme.durFast
                        curve: Theme.curveSpring
                    }
                }

                // darker, not see-through (the bar's blur stays behind it, not in it)
                layer.enabled: cell.dark > 0.001
                layer.smooth: true
                layer.effect: MultiEffect {
                    brightness: -0.3 * cell.dark
                }

                AppIcon {
                    anchors.centerIn: parent
                    // shrinks with the square when very many apps are open
                    size: Math.min(cell.iconSize, square.width - Theme.px(4))
                    source: cell.inf.icon
                    label: cell.inf.name
                    visible: !Config.plainSquares
                    fallbackRadius: Theme.px(7)
                    asynchronous: false
                }
            }
        }

        MouseArea {
            id: cellArea
            anchors.fill: parent
            enabled: !cell.going
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) {
                    if (cell.win)
                        Apps.close(cell.win);
                } else if (cell.win) {
                    Apps.activate(cell.win);
                } else if (cell.pinned && cell.entry && !cell.starting) {
                    // a pinned app that is not open: open it (once: a second click
                    // while it is starting does not open it twice)
                    cell.starting = true;
                    startingTimer.restart();
                    Apps.launch(cell.entry);
                }
            }
        }
    }

    // ── date ──────────────────────────────────────────────────────────────
    // The date in a pill without an outline. (Notch mode: DateCorner.qml.)
    Item {
        id: dateButton
        x: parent.width - root.sideGap - width
        width: dateText.implicitWidth + 2 * Theme.px(12)
        height: Theme.bar
        z: 5
        opacity: 1 - root.notch
        visible: root.notch < 1

        Rectangle {
            id: pill
            y: Math.round((parent.height - height) / 2)
            width: parent.width
            height: root.buttonH
            radius: height / 2
            // no fill, also while the calendar is open; dips when pressed
            color: "transparent"
            antialiasing: true
            scale: dateArea.pressed ? 0.94 : 1

            Behavior on color {
                CAnim {}
            }
            Behavior on scale {
                Anim {
                    duration: Theme.durFast
                    curve: Theme.curveSpring
                }
            }

            Txt {
                id: dateText
                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2)
                text: Clock.dateNumeric
                font.pixelSize: Theme.px(17)
                font.weight: Font.DemiBold            // Clarity City SemiBold, like the island's clock
            }
        }

        // the clickable area reaches the right edge of the screen (the pill stays where it is)
        MouseArea {
            id: dateArea
            x: -Theme.px(6)
            width: parent.width + Theme.px(6) + root.sideGap
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Ui.toggleCalendar()
        }
    }
}
