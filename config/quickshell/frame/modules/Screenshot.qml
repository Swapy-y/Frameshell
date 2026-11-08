import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.components

// ═══════════════════════════════════════════════════════════════════════════
//  Screenshot.qml - the screenshot screen (Print) and the whole-screen shot
//  (Shift + Print).
//
//  Print: every screen is captured once (ScreencopyView) and shown frozen and
//  dimmed over everything, fading in. Drag over an area to select it; letting
//  go keeps it (nothing is captured yet). Drag inside it to move it, drag its
//  edges or corners to resize it (the pointer shows where), drag outside it
//  for a new one. Drag with the right button to resize it from the corner
//  nearest the pointer, like SUPER + right drag resizes a window. Middle-click
//  anywhere: the drawing tools (pencil, line, arrow, rectangle, text), the
//  colour, undo. The mouse wheel sets the line width (and the text size).
//  "Capture cursor" (the Settings app's Screenshot page, Store.screenshotCursor):
//  the pointer (the normal arrow) is in the picture; off, it is not. Enter (or Ctrl + C / Ctrl + S) takes the
//  selection - without one, the whole screen - with what you drew on it; Esc
//  (or SUPER + C) cancels. The arrow keys move the selection by a pixel, with Shift they
//  resize it. It fades out again either way.
//  While it is open no keyboard shortcut of Hyprland works, not even SUPER +
//  drag: hyprland.lua switches them off while this window ("frame-screenshot")
//  is open.
//
//  Shift + Print: the screen the pointer is on, at once, no screen to pick on.
//
//  The picture is taken from the frozen capture, at the screen's own
//  resolution, and handed to scripts/screenshot.sh ("saved"): it goes to
//  ~/Pictures/Screenshots, is copied to the clipboard and a notification
//  shows it.
//
//  Started by hyprland.lua with an event on Hyprland's socket
//  ("custom>>frameshell-screenshot area" / "... screen": at once), or by hand:
//    qs -c frame ipc call screenshot area      (scripts/screenshot.sh area)
//    qs -c frame ipc call screenshot screen
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    id: root

    property string mode: ""                // "" (closed), "area" (Print), "screen" (Shift + Print)
    property bool closing: false            // fading out
    property bool busy: false               // the picture is being taken: no more input
    property bool anyShown: false           // a screen has its capture (else: it failed)
    property string keyScreen: ""           // the screen with the keyboard (where the pointer was)
    property string selScreen: ""           // the screen with the selection ("" = none)
    property rect sel: Qt.rect(0, 0, 0, 0)  // the selection on it (layout pixels)

    property string tool: ""                // "" (select: move / resize), "pencil", "line", "arrow", "rect", "text"
    readonly property var colors: ["#ff3b30", "#ff9500", "#ffcc00", "#34c759", "#0a84ff", "#ffffff", "#000000"]
    property color drawColor: colors[0]
    property int thickness: 3               // line width (mouse wheel), 1 - 20
    readonly property real textSize: 8 + thickness * 4
    property var undoWins: []               // the screen of each mark, newest last (Ctrl + Z)
    property var wins: ({})                 // screen name -> its window

    readonly property string script: Quickshell.shellPath("scripts/screenshot.sh")

    function start(m) {
        if (mode !== "" || (m !== "area" && m !== "screen"))
            return;
        const names = Quickshell.screens.map(s => s.name);
        const fm = Hyprland.focusedMonitor;
        keyScreen = fm && names.indexOf(fm.name) >= 0 ? fm.name : (names.length ? names[0] : "");
        selScreen = "";
        sel = Qt.rect(0, 0, 0, 0);
        tool = "";
        undoWins = [];
        wins = ({});
        busy = false;
        closing = false;
        anyShown = false;
        mode = m;
        failsafe.restart();
    }

    function close() {
        if (mode === "" || closing)
            return;
        closing = true;
        closeTimer.interval = mode === "area" ? Theme.durShot + 30 : 0;
        closeTimer.restart();
    }

    // Enter: the selection (or the whole screen) of the screen it is on
    function finish() {
        if (mode === "" || busy || closing)
            return;
        const w = wins[selScreen !== "" ? selScreen : keyScreen];
        if (!w) {
            close();
            return;
        }
        if (!w.shown)
            return;                         // the capture is not there yet
        busy = true;
        w.capture(selScreen !== "" ? sel : null);
    }

    function saved(result) {
        const dir = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
        const path = dir + "/frameshell-screenshot-" + Date.now() + ".png";
        if (result && result.saveToFile(path))
            Quickshell.execDetached(["bash", script, "saved", path]);
        close();
    }

    function undo() {
        const list = undoWins.slice();
        const w = list.pop();
        undoWins = list;
        if (w)
            w.undoLast();
    }

    // the arrow keys: move the selection a pixel, with Shift resize it
    function nudge(dx, dy, resize) {
        const w = wins[selScreen];
        if (!w || busy)
            return;
        const s = sel;
        if (resize) {
            sel = Qt.rect(s.x, s.y, Math.max(1, Math.min(w.width - s.x, s.width + dx)), Math.max(1, Math.min(w.height - s.y, s.height + dy)));
            keySizing.restart();
        } else {
            sel = Qt.rect(Math.max(0, Math.min(w.width - s.width, s.x + dx)), Math.max(0, Math.min(w.height - s.height, s.y + dy)), s.width, s.height);
        }
    }

    // Shift + the arrow keys resized it: its size shows for a moment
    Timer {
        id: keySizing
        interval: 900
    }

    Timer {
        id: closeTimer
        onTriggered: {
            root.mode = "";
            root.closing = false;
            root.busy = false;
            root.wins = ({});
            root.undoWins = [];
        }
    }

    // the screen could not be captured: give up (and say so) instead of waiting for ever
    Timer {
        id: failsafe
        interval: 3000
        onTriggered: {
            if (root.mode !== "" && !root.anyShown) {
                root.mode = "";
                Quickshell.execDetached(["notify-send", "-a", "Screenshot", "Screenshot failed", "The screen could not be captured."]);
            }
        }
    }

    IpcHandler {
        target: "screenshot"

        function area(): void {
            root.start("area");
        }

        function screen(): void {
            root.start("screen");
        }
    }

    // Print / Shift + Print (hyprland.lua): "custom>>frameshell-screenshot area"
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "custom" && event.data.startsWith("frameshell-screenshot "))
                root.start(event.data.slice(22).trim());
        }
    }

    // ── one mark: a pencil stroke, a line, an arrow, a rectangle or a text ──
    component MarkItem: Item {
        id: m

        property var mark: null
        readonly property string type: mark ? mark.type : ""
        readonly property var pts: mark && mark.points ? mark.points : []

        // the line (for an arrow up into its head) and the arrow's head
        readonly property var parts: {
            const p = pts;
            if (p.length < 2)
                return {
                    line: [],
                    head: []
                };
            const a = p[0], b = p[p.length - 1];
            if (type === "rect")
                return {
                    line: [Qt.point(a.x, a.y), Qt.point(b.x, a.y), Qt.point(b.x, b.y), Qt.point(a.x, b.y), Qt.point(a.x, a.y)],
                    head: []
                };
            if (type !== "arrow")
                return {
                    line: p.map(q => Qt.point(q.x, q.y)),
                    head: []
                };
            const dx = b.x - a.x, dy = b.y - a.y;
            const len = Math.hypot(dx, dy);
            if (len < 0.5)
                return {
                    line: [],
                    head: []
                };
            const ux = dx / len, uy = dy / len;
            const L = Math.min(len, Math.max(12, mark.width * 4));
            const H = L * 0.55;
            const bx = b.x - ux * L, by = b.y - uy * L;
            return {
                line: [Qt.point(a.x, a.y), Qt.point(bx + ux * L * 0.4, by + uy * L * 0.4)],
                head: [Qt.point(b.x, b.y), Qt.point(bx - uy * H, by + ux * H), Qt.point(bx + uy * H, by - ux * H), Qt.point(b.x, b.y)]
            };
        }

        anchors.fill: parent

        Shape {
            anchors.fill: parent
            visible: m.type !== "" && m.type !== "text"
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: m.mark ? m.mark.color : "transparent"
                strokeWidth: m.mark ? m.mark.width : 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: m.type === "rect" ? ShapePath.MiterJoin : ShapePath.RoundJoin

                PathPolyline {
                    path: m.parts.line
                }
            }
            ShapePath {
                strokeColor: "transparent"
                strokeWidth: 0
                fillColor: m.type === "arrow" && m.mark ? m.mark.color : "transparent"

                PathPolyline {
                    path: m.parts.head
                }
            }
        }

        Text {
            visible: m.type === "text"
            x: m.mark && m.mark.x !== undefined ? m.mark.x : 0
            y: m.mark && m.mark.y !== undefined ? m.mark.y : 0
            text: m.mark && m.mark.text ? m.mark.text : ""
            color: m.mark ? m.mark.color : "transparent"
            font.family: Theme.font
            font.pixelSize: m.mark && m.mark.size ? m.mark.size : 16
            font.weight: Font.DemiBold
        }
    }

    // ── the tools' little pictures in the right-click menu ──
    component ToolIcon: Item {
        id: ti

        property string tool: ""
        property color tint: Config.text
        readonly property var paths: ({
                "": "M5 2.5 L5 15 L8.2 11.9 L10.5 16.5 L12.6 15.5 L10.3 11 L14.6 11 Z",
                "pencil": "M12.5 3.5 L14.5 5.5 L6 14 L3.5 14.5 L4 12 Z M11 5 L13 7",
                "line": "M3.5 14.5 L14.5 3.5",
                "arrow": "M3.5 14.5 L14 4 M8 4 L14 4 L14 10",
                "rect": "M3 4.5 L15 4.5 L15 13.5 L3 13.5 Z",
                "text": "M4 4 L14 4 M9 4 L9 15",
                "undo": "M5.5 3.5 L2.5 6.5 L5.5 9.5 M2.5 6.5 L11 6.5 Q15 6.5 15 10.5 Q15 14.5 11 14.5 L7 14.5"
            })

        implicitWidth: Theme.px(18)
        implicitHeight: Theme.px(18)

        Shape {
            width: 18
            height: 18
            scale: ti.width / 18
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: ti.tint
                strokeWidth: 1.6
                fillColor: ti.tool === "" ? ti.tint : "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: ti.paths[ti.tool] || ""
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: per

            required property var modelData
            readonly property string name: modelData.name

            LazyLoader {
                // the whole-screen shot only needs the screen with the pointer
                active: root.mode === "area" || (root.mode === "screen" && per.name === root.keyScreen)

                PanelWindow {
                    id: win

                    readonly property bool area: root.mode === "area"
                    readonly property bool hasSel: root.selScreen === per.name && root.sel.width > 0 && root.sel.height > 0
                    // screen pixels per layout pixel (the capture is at the screen's own resolution)
                    readonly property real ratio: shot.hasContent && shot.sourceSize.width > 0 && width > 0 ? shot.sourceSize.width / width : 1
                    property bool shown: false
                    property bool capturing: false      // the window is on the screen: capture it now
                    property var marks: []              // what was drawn on this screen
                    property var current: null          // ... and what is being drawn
                    property var textAt: null           // {x, y}: a text is being typed there

                    screen: per.modelData
                    // there at once (Quickshell's screen capture waits for a window to be drawn),
                    // but see-through until the capture is there: it never captures itself
                    color: "transparent"

                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.namespace: "frame-screenshot"
                    // the keyboard - and with it the pointer: Hyprland gives a window that takes the
                    // keyboard the pointer too, at once, so its pointer is the one captured (below)
                    WlrLayershell.keyboardFocus: per.name === root.keyScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                    exclusionMode: ExclusionMode.Ignore
                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }
                    Component.onCompleted: {
                        const w = root.wins;
                        w[per.name] = win;
                        root.wins = w;
                        if (backingWindowVisible)
                            startCapture.start();
                    }

                    // the capture is there: fade in (Print), or take the picture (Shift + Print)
                    function contentReady() {
                        if (!shot.hasContent || win.shown)
                            return;
                        root.anyShown = true;
                        if (win.area) {
                            Qt.callLater(() => {
                                win.shown = true;
                                keys.forceActiveFocus();
                            });
                        } else {
                            win.shown = true;
                            screenShot.start();
                        }
                    }

                    // The capture starts once this window is on the screen (see-through then): started
                    // while the window was still being made, Qt crashed on the second screenshot. A
                    // moment later, so its pointer (see the MouseArea's cursorShape) is on the screen.
                    onBackingWindowVisibleChanged: {
                        if (backingWindowVisible)
                            startCapture.start();
                    }
                    Timer {
                        id: startCapture
                        interval: 50
                        onTriggered: win.capturing = true
                    }

                    // Shift + Print: the whole screen, once it is drawn
                    Timer {
                        id: screenShot
                        interval: 60
                        onTriggered: root.finish()
                    }

                    // ── the picture: the given area (or the whole screen), with what was drawn on it ──
                    function capture(r) {
                        commitText();
                        menu.open = false;
                        const c = r && r.width >= 1 && r.height >= 1 ? r : Qt.rect(0, 0, width, height);
                        // only the area is kept: the capture moves so that the area is at the cropper's
                        // top-left (it stays where it is on the screen)
                        cropper.x = c.x;
                        cropper.y = c.y;
                        cropper.width = c.width;
                        cropper.height = c.height;
                        picture.x = -c.x;
                        picture.y = -c.y;
                        const ok = cropper.grabToImage(result => root.saved(result), Qt.size(Math.max(1, Math.round(c.width * ratio)), Math.max(1, Math.round(c.height * ratio))));
                        if (!ok)
                            root.close();
                    }

                    function undoLast() {
                        if (!marks.length)
                            return false;
                        marks = marks.slice(0, -1);
                        return true;
                    }

                    function addMark(mk) {
                        marks = marks.concat([mk]);
                        root.undoWins = root.undoWins.concat([win]);
                    }

                    function commitText() {
                        if (textAt && editor.text.trim() !== "")
                            addMark({
                                type: "text",
                                x: textAt.x,
                                y: textAt.y,
                                text: editor.text,
                                color: String(root.drawColor),      // a copy: a colour read from a property follows it
                                size: root.textSize
                            });
                        cancelText();
                    }

                    function cancelText() {
                        textAt = null;
                        editor.text = "";
                        keys.forceActiveFocus();
                    }

                    function clamp(v, lo, hi) {
                        return Math.max(lo, Math.min(hi, v));
                    }

                    function inside(x, y) {
                        const s = root.sel;
                        return hasSel && x > s.x && x < s.x + s.width && y > s.y && y < s.y + s.height;
                    }

                    // which edges of the selection are under the pointer: "l" / "r", then "t" / "b"
                    function edgesAt(x, y) {
                        if (!hasSel)
                            return "";
                        const m = Theme.px(8);
                        const s = root.sel;
                        const l = s.x, t = s.y, r = s.x + s.width, b = s.y + s.height;
                        if (x < l - m || x > r + m || y < t - m || y > b + m)
                            return "";
                        let e = "";
                        const dl = Math.abs(x - l), dr = Math.abs(x - r), dt = Math.abs(y - t), db = Math.abs(y - b);
                        if (Math.min(dl, dr) <= m)
                            e += dl <= dr ? "l" : "r";
                        if (Math.min(dt, db) <= m)
                            e += dt <= db ? "t" : "b";
                        return e;
                    }

                    function openMenu(x, y) {
                        menu.x = clamp(x, Theme.px(8), width - menu.width - Theme.px(8));
                        menu.y = clamp(y, Theme.px(8), height - menu.height - Theme.px(8));
                        menu.open = true;
                    }

                    function press(e) {
                        if (e.button === Qt.MiddleButton) {
                            commitText();
                            mouse.action = "none";
                            openMenu(e.x, e.y);
                            return;
                        }
                        if (menu.open) {
                            menu.open = false;          // a click beside the menu only closes it
                            mouse.action = "none";
                            return;
                        }
                        const x = Math.round(e.x), y = Math.round(e.y);
                        mouse.px = x;
                        mouse.py = y;
                        mouse.ps = root.sel;
                        if (e.button === Qt.RightButton) {
                            // like SUPER + right drag on a window: the corner nearest the pointer
                            // follows it, the opposite one stays
                            commitText();
                            if (!hasSel) {
                                mouse.action = "none";
                                return;
                            }
                            const s = root.sel;
                            mouse.action = "resize";
                            mouse.edges = (x < s.x + s.width / 2 ? "l" : "r") + (y < s.y + s.height / 2 ? "t" : "b");
                            return;
                        }
                        const ed = edgesAt(x, y);
                        if (ed !== "") {
                            commitText();
                            mouse.action = "resize";
                            mouse.edges = ed;
                        } else if (root.tool === "text") {
                            mouse.action = "none";
                            if (textAt) {
                                commitText();           // a click beside it ends the text
                            } else {
                                textAt = {
                                    x: x,
                                    y: Math.round(y - root.textSize * 0.6)
                                };
                                editor.forceActiveFocus();
                            }
                        } else if (root.tool !== "") {
                            mouse.action = "draw";
                            current = {
                                type: root.tool,
                                color: String(root.drawColor),      // a copy (see above)
                                width: root.thickness,
                                points: [Qt.point(x, y)]
                            };
                        } else if (inside(x, y)) {
                            mouse.action = "move";
                        } else {
                            mouse.action = "new";
                            root.selScreen = per.name;
                            root.sel = Qt.rect(x, y, 0, 0);
                        }
                    }

                    function drag(e) {
                        const x = clamp(Math.round(e.x), 0, width), y = clamp(Math.round(e.y), 0, height);
                        const px = mouse.px, py = mouse.py, ps = mouse.ps;
                        if (mouse.action === "new") {
                            root.sel = Qt.rect(Math.min(px, x), Math.min(py, y), Math.abs(x - px), Math.abs(y - py));
                        } else if (mouse.action === "move") {
                            root.sel = Qt.rect(clamp(ps.x + x - px, 0, width - ps.width), clamp(ps.y + y - py, 0, height - ps.height), ps.width, ps.height);
                        } else if (mouse.action === "resize") {
                            const ed = mouse.edges;
                            let l = ps.x, t = ps.y, r = ps.x + ps.width, b = ps.y + ps.height;
                            if (ed.indexOf("l") >= 0)
                                l = clamp(l + x - px, 0, width);
                            if (ed.indexOf("r") >= 0)
                                r = clamp(r + x - px, 0, width);
                            if (ed.indexOf("t") >= 0)
                                t = clamp(t + y - py, 0, height);
                            if (ed.indexOf("b") >= 0)
                                b = clamp(b + y - py, 0, height);
                            root.sel = Qt.rect(Math.min(l, r), Math.min(t, b), Math.abs(r - l), Math.abs(b - t));
                        } else if (mouse.action === "draw" && current) {
                            const c = current;
                            const last = c.points[c.points.length - 1];
                            if (c.type === "pencil") {
                                if (Math.hypot(x - last.x, y - last.y) >= 1)
                                    current = Object.assign({}, c, {
                                        points: c.points.concat([Qt.point(x, y)])
                                    });
                            } else {
                                current = Object.assign({}, c, {
                                    points: [c.points[0], Qt.point(x, y)]
                                });
                            }
                        }
                    }

                    function release(e) {
                        const a = mouse.action;
                        mouse.action = "";
                        mouse.edges = "";
                        // a click without dragging (or an area squeezed to nothing): no selection
                        if ((a === "new" || a === "resize") && (root.sel.width < 2 || root.sel.height < 2)) {
                            root.selScreen = "";
                            root.sel = Qt.rect(0, 0, 0, 0);
                        }
                        if (a === "draw" && current) {
                            const c = current;
                            current = null;
                            const p = c.points;
                            if (p.length > 1 && (c.type === "pencil" || Math.hypot(p[p.length - 1].x - p[0].x, p[p.length - 1].y - p[0].y) >= 2))
                                addMark(c);
                        }
                    }

                    // SUPER + C (the shortcut that closes a window) cancels it, from anywhere: also with
                    // the menu open or while typing a text (where Esc first closes / drops only those)
                    function superC(e) {
                        return e.key === Qt.Key_C && (e.modifiers & Qt.MetaModifier) !== 0;
                    }

                    function key(e) {
                        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
                        const shift = (e.modifiers & Qt.ShiftModifier) !== 0;
                        if (win.superC(e)) {
                            root.close();
                        } else if (e.key === Qt.Key_Escape) {
                            if (menu.open)
                                menu.open = false;
                            else
                                root.close();
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || (ctrl && (e.key === Qt.Key_C || e.key === Qt.Key_S))) {
                            root.finish();
                        } else if (ctrl && e.key === Qt.Key_Z) {
                            root.undo();
                        } else if (e.key === Qt.Key_Left) {
                            root.nudge(-1, 0, shift);
                        } else if (e.key === Qt.Key_Right) {
                            root.nudge(1, 0, shift);
                        } else if (e.key === Qt.Key_Up) {
                            root.nudge(0, -1, shift);
                        } else if (e.key === Qt.Key_Down) {
                            root.nudge(0, 1, shift);
                        } else {
                            return;
                        }
                        e.accepted = true;
                    }

                    Item {
                        id: keys
                        focus: true
                        Keys.onPressed: e => win.key(e)
                    }

                    Item {
                        id: fader
                        anchors.fill: parent
                        // Shift + Print: never seen (the picture is taken from it all the same)
                        opacity: win.area && win.shown && !root.closing ? 1 : 0

                        Behavior on opacity {
                            Anim {
                                duration: Theme.durShot
                            }
                        }

                        // what is kept: normally the whole screen, the area while the picture is taken
                        Item {
                            id: cropper
                            width: win.width
                            height: win.height
                            clip: true

                            Item {
                                id: picture
                                width: win.width
                                height: win.height

                                ScreencopyView {
                                    id: shot
                                    anchors.fill: parent
                                    captureSource: win.capturing ? per.modelData : null
                                    live: false
                                    // the pointer in the picture (Settings: Screenshot)
                                    paintCursor: Store.screenshotCursor
                                    onHasContentChanged: win.contentReady()
                                }

                                Repeater {
                                    model: win.marks

                                    MarkItem {
                                        required property var modelData
                                        mark: modelData
                                    }
                                }

                                MarkItem {
                                    mark: win.current
                                }

                                TextInput {
                                    id: editor
                                    visible: win.textAt !== null
                                    x: win.textAt ? win.textAt.x : 0
                                    y: win.textAt ? win.textAt.y : 0
                                    color: root.drawColor
                                    selectionColor: Config.textSelection
                                    font.family: Theme.font
                                    font.pixelSize: root.textSize
                                    font.weight: Font.DemiBold
                                    Keys.onPressed: e => {
                                        if (win.superC(e)) {
                                            root.close();
                                            e.accepted = true;
                                        }
                                    }
                                    Keys.onReturnPressed: e => {
                                        win.commitText();
                                        e.accepted = true;
                                    }
                                    Keys.onEnterPressed: e => {
                                        win.commitText();
                                        e.accepted = true;
                                    }
                                    Keys.onEscapePressed: e => {
                                        win.cancelText();
                                        e.accepted = true;
                                    }
                                }
                            }
                        }

                        // ── dimmed around the selection (all of it without one): Config.shotDim ──
                        readonly property color dim: Config.shotDim

                        Rectangle {
                            visible: !win.hasSel
                            anchors.fill: parent
                            color: fader.dim
                        }
                        Rectangle {
                            visible: win.hasSel
                            width: win.width
                            height: root.sel.y
                            color: fader.dim
                        }
                        Rectangle {
                            visible: win.hasSel
                            y: root.sel.y + root.sel.height
                            width: win.width
                            height: win.height - y
                            color: fader.dim
                        }
                        Rectangle {
                            visible: win.hasSel
                            y: root.sel.y
                            width: root.sel.x
                            height: root.sel.height
                            color: fader.dim
                        }
                        Rectangle {
                            visible: win.hasSel
                            x: root.sel.x + root.sel.width
                            y: root.sel.y
                            width: win.width - x
                            height: root.sel.height
                            color: fader.dim
                        }

                        // a line round it, just outside it, with round corners (the picture stays square;
                        // no handles: its edges and corners are grabbed as they are)
                        Rectangle {
                            visible: win.hasSel
                            x: root.sel.x - border.width
                            y: root.sel.y - border.width
                            width: root.sel.width + 2 * border.width
                            height: root.sel.height + 2 * border.width
                            radius: Theme.px(6)
                            color: "transparent"
                            border.width: 2
                            border.color: Config.shotOutline
                        }

                        // its size in screen pixels, in its middle - only while it is being sized (drawn,
                        // its edges / corners dragged, the right button, Shift + the arrow keys)
                        Rectangle {
                            readonly property bool sizing: win.hasSel && (mouse.action === "new" || mouse.action === "resize" || keySizing.running)

                            visible: opacity > 0
                            opacity: sizing ? 1 : 0
                            x: Math.round(root.sel.x + (root.sel.width - width) / 2)
                            y: Math.round(root.sel.y + (root.sel.height - height) / 2)
                            width: sizeText.implicitWidth + Theme.px(14)
                            height: sizeText.implicitHeight + Theme.px(6)
                            radius: height / 2
                            color: Config.frame

                            Behavior on opacity {
                                Anim {
                                    duration: Theme.durFast
                                }
                            }

                            Txt {
                                id: sizeText
                                anchors.centerIn: parent
                                text: Math.round(root.sel.width * win.ratio) + " × " + Math.round(root.sel.height * win.ratio)
                                font.pixelSize: Theme.fsSmall
                                font.weight: Font.DemiBold
                                color: Config.text
                            }
                        }

                        MouseArea {
                            id: mouse

                            property string action: ""      // "new", "move", "resize", "draw", "none"
                            property string edges: ""
                            property real px: 0
                            property real py: 0
                            property rect ps: Qt.rect(0, 0, 0, 0)
                            property real hx: -1
                            property real hy: -1

                            // takes clicks only once the capture is shown (always enabled, so its pointer
                            // shape is the one on the screen from the start)
                            readonly property bool live: win.area && win.shown && !root.busy && !root.closing

                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            hoverEnabled: true
                            cursorShape: {
                                // Until the screen is captured, the pointer that should be in the picture:
                                // the normal arrow ("Capture cursor"), or none. Hyprland copies its last
                                // picture of the screen for a capture - with the pointer already in it when
                                // it draws the pointer itself - so leaving the pointer out of the capture
                                // (paintCursor) alone is not enough.
                                if (!win.area || !win.shown)
                                    return Store.screenshotCursor ? Qt.ArrowCursor : Qt.BlankCursor;
                                if (action === "move")
                                    return Qt.ClosedHandCursor;
                                if (action === "new" || action === "draw")
                                    return Qt.CrossCursor;
                                const e = action === "resize" ? edges : win.edgesAt(hx, hy);
                                if (e === "l" || e === "r")
                                    return Qt.SizeHorCursor;
                                if (e === "t" || e === "b")
                                    return Qt.SizeVerCursor;
                                if (e === "lt" || e === "rb")
                                    return Qt.SizeFDiagCursor;
                                if (e === "rt" || e === "lb")
                                    return Qt.SizeBDiagCursor;
                                if (root.tool === "text")
                                    return Qt.IBeamCursor;
                                if (root.tool === "" && win.inside(hx, hy))
                                    return Qt.OpenHandCursor;
                                return Qt.CrossCursor;
                            }

                            onPressed: e => {
                                if (live)
                                    win.press(e);
                                else
                                    action = "none";
                            }
                            onPositionChanged: e => {
                                hx = e.x;
                                hy = e.y;
                                if (live)
                                    win.drag(e);
                            }
                            onReleased: e => {
                                if (live)
                                    win.release(e);
                                else
                                    action = "";
                            }
                            onWheel: w => {
                                const step = w.angleDelta.y > 0 ? 1 : (w.angleDelta.y < 0 ? -1 : 0);
                                if (step === 0 || !live)
                                    return;
                                root.thickness = Math.max(1, Math.min(20, root.thickness + step));
                                sizeTip.x = win.clamp(w.x + Theme.px(16), 0, win.width - sizeTip.width);
                                sizeTip.y = win.clamp(w.y + Theme.px(16), 0, win.height - sizeTip.height);
                                sizeTip.show = true;
                                sizeTipTimer.restart();
                            }
                        }

                        // the line width, for a moment after the wheel turned it
                        Rectangle {
                            id: sizeTip
                            property bool show: false
                            visible: opacity > 0
                            opacity: show ? 1 : 0
                            width: tipRow.implicitWidth + Theme.px(16)
                            height: Theme.px(30)
                            radius: Theme.px(8)
                            color: Config.frame
                            border.width: 1
                            border.color: Config.outline

                            Behavior on opacity {
                                Anim {
                                    duration: Theme.durFast
                                }
                            }

                            Row {
                                id: tipRow
                                anchors.centerIn: parent
                                spacing: Theme.px(8)

                                Item {
                                    width: Theme.px(20)
                                    height: Theme.px(20)

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: root.thickness
                                        height: root.thickness
                                        radius: width / 2
                                        color: root.drawColor
                                    }
                                }
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.thickness + " px"
                                    font.pixelSize: Theme.fsSmall
                                }
                            }

                            Timer {
                                id: sizeTipTimer
                                interval: 900
                                onTriggered: sizeTip.show = false
                            }
                        }

                        // ── middle-click: the tools, the colour, undo ──
                        Rectangle {
                            id: menu

                            property bool open: false
                            readonly property real pad: Theme.px(6)
                            readonly property real rowH: Theme.px(34)
                            readonly property var tools: [
                                {
                                    tool: "",
                                    label: "Select"
                                },
                                {
                                    tool: "pencil",
                                    label: "Pencil"
                                },
                                {
                                    tool: "line",
                                    label: "Line"
                                },
                                {
                                    tool: "arrow",
                                    label: "Arrow"
                                },
                                {
                                    tool: "rect",
                                    label: "Rectangle"
                                },
                                {
                                    tool: "text",
                                    label: "Text"
                                }
                            ]

                            visible: opacity > 0
                            opacity: open ? 1 : 0
                            width: Theme.px(196)
                            height: col.implicitHeight + 2 * pad
                            radius: Theme.px(14)
                            color: Config.frame
                            border.width: Math.max(1, Theme.border)
                            border.color: Config.outline

                            Behavior on opacity {
                                Anim {
                                    duration: Theme.durFast
                                }
                            }

                            // clicks on the menu stay on the menu (not while it fades out: then it is closed)
                            MouseArea {
                                anchors.fill: parent
                                enabled: menu.open
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            }

                            Column {
                                id: col
                                x: menu.pad
                                y: menu.pad
                                width: menu.width - 2 * menu.pad

                                Repeater {
                                    model: menu.tools

                                    Item {
                                        id: toolRow
                                        required property var modelData
                                        readonly property bool active: root.tool === modelData.tool

                                        width: col.width
                                        height: menu.rowH

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.px(9)
                                            color: toolRow.active ? Config.selected : (toolArea.containsMouse ? Config.hover : "transparent")
                                        }
                                        ToolIcon {
                                            x: Theme.px(10)
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Theme.px(18)
                                            height: Theme.px(18)
                                            tool: toolRow.modelData.tool
                                            tint: toolRow.active ? Config.text : Config.textDim
                                        }
                                        Txt {
                                            x: Theme.px(38)
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: toolRow.modelData.label
                                            font.pixelSize: Theme.px(14)
                                            font.weight: Font.Medium
                                            color: toolRow.active ? Config.text : Config.textDim
                                        }
                                        MouseArea {
                                            id: toolArea
                                            anchors.fill: parent
                                            enabled: menu.open
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.tool = toolRow.modelData.tool;
                                                menu.open = false;
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: col.width
                                    height: 1
                                    color: Config.divider
                                }

                                // the colour
                                Item {
                                    width: col.width
                                    height: menu.rowH

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Theme.px(6)

                                        Repeater {
                                            model: root.colors

                                            Item {
                                                id: swatch
                                                required property var modelData
                                                readonly property bool active: Qt.colorEqual(root.drawColor, modelData)

                                                width: Theme.px(20)
                                                height: Theme.px(20)

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: width / 2
                                                    color: "transparent"
                                                    border.width: swatch.active ? Math.max(1, Theme.px(2)) : 0
                                                    border.color: Config.text
                                                }
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: parent.width - Theme.px(6)
                                                    height: width
                                                    radius: width / 2
                                                    color: swatch.modelData
                                                    border.width: 1
                                                    border.color: Config.outline
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    enabled: menu.open
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.drawColor = swatch.modelData
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: col.width
                                    height: 1
                                    color: Config.divider
                                }

                                // undo
                                Item {
                                    id: undoRow
                                    readonly property bool can: root.undoWins.length > 0

                                    width: col.width
                                    height: menu.rowH
                                    opacity: can ? 1 : 0.4

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.px(9)
                                        color: undoRow.can && undoArea.containsMouse ? Config.hover : "transparent"
                                    }
                                    ToolIcon {
                                        x: Theme.px(10)
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Theme.px(18)
                                        height: Theme.px(18)
                                        tool: "undo"
                                        tint: Config.textDim
                                    }
                                    Txt {
                                        x: Theme.px(38)
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Undo"
                                        font.pixelSize: Theme.px(14)
                                        font.weight: Font.Medium
                                        color: Config.textDim
                                    }
                                    Txt {
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.px(10)
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Ctrl+Z"
                                        font.pixelSize: Theme.fsSmall
                                        color: Config.textFaint
                                    }
                                    MouseArea {
                                        id: undoArea
                                        anchors.fill: parent
                                        enabled: menu.open && undoRow.can
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.undo()
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
