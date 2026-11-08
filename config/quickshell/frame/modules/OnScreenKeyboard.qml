import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.components

// ═══════════════════════════════════════════════════════════════════════════
//  OnScreenKeyboard.qml - the on-screen keyboard (SUPER + \): an English (US)
//  keyboard floating over the windows, in the middle near the bottom of the
//  screen with the focused window.
//
//  A click on a key types it into the focused window, as if pressed on the
//  keyboard; held, it repeats (at the Settings app's Repeat delay / rate).
//  The keyboard never takes the focus itself and is not a window Hyprland
//  tiles: everything beside it stays clickable, so click the window you want
//  to type into, then the keys.
//  Shift, Ctrl and Alt hold for the next key (click again to let go), Caps
//  stays until clicked again. The key next to the arrows hides the keyboard,
//  like SUPER + \ again.
//
//  The keys go to Hyprland (hl.dsp.send_shortcut: the key with Shift / Ctrl /
//  Alt, to the window with the keyboard focus), so it needs hyprland.lua (Lua
//  Hyprland).
//
//  Started by hyprland.lua with an event on Hyprland's socket
//  ("custom>>frameshell-osk toggle"), or by hand:
//    qs -c frame ipc call keyboard toggle | open | close
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    id: root

    property bool open: false
    property string screenName: ""          // the screen it is on

    // the modifiers held for the next key
    property bool shift: false
    property bool caps: false
    property bool ctrl: false
    property bool alt: false

    // ── the keys: 15 units wide, five rows ───────────────────────────────
    //   k      the key (an xkb key name: Hyprland finds it on the keyboard layout)
    //   l / s  its label, and with Shift
    //   kind   "char" (types something), "key" (Esc, Enter, arrows ...), "shift", "caps",
    //          "ctrl", "alt", "hide"
    //   icon   drawn instead of a label (KeyIcon below)
    //   w      width in units (1 = a letter)
    readonly property var rows: {
        function chars(list) {
            return list.map(c => ({
                        k: c[0],
                        l: c[1],
                        s: c[2],
                        kind: "char",
                        letter: false,
                        w: 1
                    }));
        }
        function letters(str) {
            return str.split("").map(c => ({
                        k: c,
                        l: c,
                        s: c.toUpperCase(),
                        kind: "char",
                        letter: true,
                        w: 1
                    }));
        }
        function key(k, w, extra) {
            return Object.assign({
                k: k,
                l: "",
                s: "",
                kind: "key",
                letter: false,
                w: w
            }, extra || {});
        }
        return [chars([["grave", "`", "~"], ["1", "1", "!"], ["2", "2", "@"], ["3", "3", "#"], ["4", "4", "$"], ["5", "5", "%"], ["6", "6", "^"], ["7", "7", "&"], ["8", "8", "*"], ["9", "9", "("], ["0", "0", ")"], ["minus", "-", "_"], ["equal", "=", "+"]]).concat([key("BackSpace", 2, {
                    icon: "backspace"
                })]), [key("Tab", 1.5, {
                    icon: "tab"
                })].concat(letters("qwertyuiop"), chars([["bracketleft", "[", "{"], ["bracketright", "]", "}"], ["backslash", "\\", "|"]])).map((c, i) => i === 13 ? Object.assign({}, c, {
                        w: 1.5
                    }) : c), [key("", 1.75, {
                    kind: "caps",
                    icon: "caps"
                })].concat(letters("asdfghjkl"), chars([["semicolon", ";", ":"], ["apostrophe", "'", "\""]]), [key("Return", 2.25, {
                        icon: "enter"
                    })]), [key("", 2.5, {
                    kind: "shift",
                    icon: "shift"
                })].concat(letters("zxcvbnm"), chars([["comma", ",", "<"], ["period", ".", ">"], ["slash", "/", "?"]]), [key("Up", 1.25, {
                        icon: "up"
                    }), key("", 1.25, {
                        kind: "shift",
                        icon: "shift"
                    })]), [key("Escape", 1.25, {
                    l: "Esc",
                    s: "Esc"
                }), key("", 1.25, {
                    kind: "ctrl",
                    l: "Ctrl",
                    s: "Ctrl"
                }), key("", 1.25, {
                    kind: "alt",
                    l: "Alt",
                    s: "Alt"
                }), key("space", 6.25), key("", 1.25, {
                    kind: "hide",
                    icon: "hide"
                }), key("Left", 1.25, {
                    icon: "left"
                }), key("Down", 1.25, {
                    icon: "down"
                }), key("Right", 1.25, {
                    icon: "right"
                })]];
    }

    // every key with its place: {key, row, x (units)}
    readonly property var keys: {
        const out = [];
        for (let r = 0; r < rows.length; r++) {
            let x = 0;
            for (const k of rows[r]) {
                out.push({
                    key: k,
                    row: r,
                    x: x
                });
                x += k.w;
            }
        }
        return out;
    }

    function show() {
        const names = Quickshell.screens.map(s => s.name);
        const fm = Hyprland.focusedMonitor;
        screenName = fm && names.indexOf(fm.name) >= 0 ? fm.name : (names.length ? names[0] : "");
        open = true;
    }

    function hide() {
        open = false;
        held.stop();
        shift = false;
        ctrl = false;
        alt = false;
    }

    function toggle() {
        if (open)
            hide();
        else
            show();
    }

    // a letter in capitals (Caps or Shift, not both)
    readonly property bool upper: caps !== shift

    // the modifiers to send with a key: a letter gets Shift for a capital (Caps only without
    // Ctrl / Alt: Ctrl + C stays Ctrl + C), anything else with Shift held
    function modsFor(k) {
        const m = [];
        if (k.letter ? (ctrl || alt ? shift : upper) : shift)
            m.push("SHIFT");
        if (ctrl)
            m.push("CTRL");
        if (alt)
            m.push("ALT");
        return m.join(" ");
    }

    // the key to the window with the keyboard focus (through Hyprland)
    function send(mods, name) {
        if (Hyprland.usingLua)
            Hyprland.dispatch('hl.dsp.send_shortcut({ mods = "' + mods + '", key = "' + name + '" })');
    }

    // a key pressed: a modifier switches, any other key is sent (and lets go of Shift / Ctrl / Alt)
    function press(k) {
        if (k.kind === "shift") {
            shift = !shift;
        } else if (k.kind === "caps") {
            caps = !caps;
        } else if (k.kind === "ctrl") {
            ctrl = !ctrl;
        } else if (k.kind === "alt") {
            alt = !alt;
        } else if (k.kind === "hide") {
            hide();
        } else {
            const mods = modsFor(k);
            send(mods, k.k);
            shift = false;
            ctrl = false;
            alt = false;
            // held: it repeats, with the same modifiers (Esc does not)
            if (k.k !== "Escape" && Config.repeatRate > 0) {
                held.mods = mods;
                held.name = k.k;
                held.interval = Math.max(100, Math.round(Config.repeatDelay));
                held.restart();
            }
        }
    }

    // a held key repeating
    Timer {
        id: held
        property string mods: ""
        property string name: ""
        repeat: true
        onTriggered: {
            interval = Math.max(10, Math.round(1000 / Config.repeatRate));
            root.send(mods, name);
        }
    }

    IpcHandler {
        target: "keyboard"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.show();
        }

        function close(): void {
            root.hide();
        }
    }

    // SUPER + \ (hyprland.lua): "custom>>frameshell-osk toggle"
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "custom" && event.data === "frameshell-osk toggle")
                root.toggle();
        }
    }

    // a key's picture: 18 x 18, drawn with lines
    component KeyIcon: Item {
        id: ki

        property string name: ""
        property color tint: Config.text
        property bool filled: false
        readonly property var paths: ({
                "backspace": "M6.5 4 L16 4 L16 14 L6.5 14 L2 9 Z M8.8 6.8 L13.2 11.2 M13.2 6.8 L8.8 11.2",
                "tab": "M2.5 9 L13 9 M9 5 L13 9 L9 13 M15.5 4.5 L15.5 13.5",
                "enter": "M15 3.5 L15 9 Q15 11.5 12.5 11.5 L3.5 11.5 M7 8 L3.5 11.5 L7 15",
                "shift": "M9 2.5 L15.5 9 L12 9 L12 15 L6 15 L6 9 L2.5 9 Z",
                "caps": "M9 2 L15.5 8.5 L12 8.5 L12 12.5 L6 12.5 L6 8.5 L2.5 8.5 Z M6 15.5 L12 15.5",
                "up": "M9 14.5 L9 3.5 M4.5 8 L9 3.5 L13.5 8",
                "down": "M9 3.5 L9 14.5 M4.5 10 L9 14.5 L13.5 10",
                "left": "M14.5 9 L3.5 9 M8 4.5 L3.5 9 L8 13.5",
                "right": "M3.5 9 L14.5 9 M10 4.5 L14.5 9 L10 13.5",
                "hide": "M2 2.5 L16 2.5 L16 11 L2 11 Z M5 5.5 L5.01 5.5 M8 5.5 L8.01 5.5 M10 5.5 L10.01 5.5 M13 5.5 L13.01 5.5 M6 8.3 L12 8.3 M6.5 13.5 L9 16 L11.5 13.5"
            })

        implicitWidth: Theme.px(18)
        implicitHeight: Theme.px(18)

        Shape {
            width: 18
            height: 18
            scale: ki.width / 18
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: ki.tint
                strokeWidth: 1.6
                fillColor: ki.filled ? ki.tint : "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: ki.paths[ki.name] || ""
                }
            }
        }
    }

    // one window per screen, only the one on root.screenName shows
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property bool here: modelData.name === root.screenName
            // room for the shadow round the card: CardShadow reaches its blur + its offset down
            // (Theme.pop(34) + Theme.pop(8)) past the card
            readonly property real shadowPad: Theme.pop(34) + Theme.pop(8) + Theme.px(4)
            // the card's lower edge is this far above the bottom of the screen; the room for its
            // shadow below it comes out of that (all of it, unless it is less)
            readonly property real lift: Theme.insetBottom + Theme.px(48)
            readonly property real below: Math.min(shadowPad, lift)

            screen: modelData
            // Hyprland fades it in and out (hyprland.lua, "frame-osk-fade"): the whole window as
            // one - card, keys, shadow and the blur behind it together
            visible: here && root.open

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "frame-osk"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None     // the keys go to the focused window
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            // only the bottom edge: Hyprland centres it from left to right
            anchors.bottom: true
            margins.bottom: lift - below
            implicitWidth: card.width + 2 * shadowPad
            implicitHeight: shadowPad + card.height + below

            // only the card takes clicks (not its shadow)
            mask: Region {
                item: card
            }

            Rectangle {
                id: card

                readonly property real unit: Theme.px(46)          // one key and the gap after it
                readonly property real gap: Theme.px(6)
                readonly property real keyH: Theme.px(44)
                readonly property real pad: Theme.px(12)

                x: win.shadowPad
                y: win.shadowPad
                width: 2 * pad + 15 * unit - gap
                height: 2 * pad + 5 * keyH + 4 * gap
                radius: Theme.px(20)
                color: Config.surface               // see-through with the shell's blur
                border.width: Theme.border
                border.color: Config.outline

                // soft shadow (follows the card while it fades)
                Loader {
                    z: -1
                    anchors.fill: parent
                    active: Config.shadows && Config.shadowStrength > 0
                    source: "../components/CardShadow.qml"
                }

                Repeater {
                    model: root.keys

                    Rectangle {
                        id: keyItem
                        required property var modelData
                        readonly property var k: modelData.key
                        // a modifier that is on
                        readonly property bool latched: (k.kind === "shift" && root.shift) || (k.kind === "caps" && root.caps) || (k.kind === "ctrl" && root.ctrl) || (k.kind === "alt" && root.alt)
                        readonly property color ink: latched ? Config.frame : Config.text

                        x: card.pad + modelData.x * card.unit
                        y: card.pad + modelData.row * (card.keyH + card.gap)
                        width: k.w * card.unit - card.gap
                        height: card.keyH
                        radius: Theme.px(10)
                        color: latched ? Config.text : (keyArea.pressed ? Config.iconDim : (keyArea.containsMouse ? Config.buttonHover : Config.selected))

                        Txt {
                            visible: !keyItem.k.icon
                            anchors.centerIn: parent
                            text: keyItem.k.kind !== "char" ? keyItem.k.l : (keyItem.k.letter ? (root.upper ? keyItem.k.s : keyItem.k.l) : (root.shift ? keyItem.k.s : keyItem.k.l))
                            color: keyItem.ink
                            font.pixelSize: keyItem.k.kind === "char" ? Theme.px(17) : Theme.px(14)
                            font.weight: Font.Medium
                        }
                        KeyIcon {
                            visible: !!keyItem.k.icon
                            anchors.centerIn: parent
                            name: keyItem.k.icon || ""
                            tint: keyItem.ink
                            filled: keyItem.latched
                        }

                        MouseArea {
                            id: keyArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onPressed: root.press(keyItem.k)
                            onReleased: held.stop()
                            onCanceled: held.stop()
                        }
                    }
                }
            }
        }
    }
}
