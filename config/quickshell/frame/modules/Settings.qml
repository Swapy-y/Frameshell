import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.services
import qs.components
import "../components/search.js" as Search

// ═══════════════════════════════════════════════════════════════════════════
//  Settings.qml - the Settings app: a normal window of the shell that tiles
//  like any app (it shows in the dock and the app switcher as "Settings", with
//  assets/icons/frame-settings.svg).
//
//  Open it from the launcher (SUPER + R, "Settings": frame-settings.desktop)
//  or with  qs -c frame ipc call ui settings.
//
//  Left: a search field and the pages. Right: the page - a card with its icon,
//  name and what it is about, and a card with its settings. A setting is a
//  switch for a property of Store (services/Store.qml): it is saved at once
//  and the shell follows right away (with owner "config": a property of Config,
//  kept in a file of ~/.local/state/frameshell). A setting with kind "slider" is
//  a slider for a property of Config (whole numbers from min to max, in the style
//  of the volume and brightness sliders), saved at once too. Some pages have one more
//  card (`extra`):
//    "wallpapers"  the pictures of the wallpaper folder - a click makes one the
//                  wallpaper, the bin on one you added removes it, the last tile
//                  adds pictures (a click, or pictures dropped on it)
//                  (services/Wallpapers.qml)
//    "history"     the last 50 notifications, newest first (services/Notifs.qml)
//    "themes"      the colour themes as cards, like the theme switcher's - a click
//                  makes one the theme in use (services/Themes.qml)
//    "icons"       a switch for the bottom bar's power button (the Frameshell logo or
//                  the power sign: Store.powerLogo), under it the icon packs of the apps
//                  in the shell as cards - a click makes one the pack in use
//                  (services/IconPacks.qml, Store.iconPack)
//    "keybinds"    every shortcut Hyprland has now (hyprctl binds -j), by what it does
//                  (the descriptions in hyprland.lua), in four cards
//    "system"      your picture and your name - a click changes them
//                  (services/Profile.qml) - and under it About: the system, the
//                  shell and the hardware (scripts/about.sh)
//    "pinned"      the dock's pinned apps: move them, unpin them, add more from the
//                  apps you have installed (services/Apps.qml, Store.dockPinned)
//    "wifi"        the networks nearby (services/Net.qml, net/WifiBackend.qml): connect,
//                  a password, disconnect, forget - only while Wi-Fi is on
//    "bluetooth"   the devices (services/Net.qml, net/BtBackend.qml): connect, pair,
//                  disconnect, forget - only while Bluetooth is on
//    "devices"     cards for the sound output and input (services/AudioDevices.qml),
//                  the keyboard, the mouse and a touchpad
//                  (Config.repeatDelay ..., kept in input.json, handed to Hyprland by
//                  modules/HyprSync.qml), each closed until you click its heading
//
//  To add a setting: a property in Store.qml, then an entry in `pages` below.
// ═══════════════════════════════════════════════════════════════════════════
Scope {
    id: root

    // when a notification came in: the time today, else the day and the time
    function when(ms) {
        const d = new Date(ms);
        const now = Clock.date;
        const day = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
        const days = Math.round((day(now) - day(d)) / 86400000);
        const t = Clock.timeOf(d);
        if (days <= 0)
            return t;
        if (days === 1)
            return "Yesterday, " + t;
        return Qt.formatDateTime(d, d.getFullYear() === now.getFullYear() ? "MMM d" : "MMM d, yyyy") + ", " + t;
    }

    readonly property var pages: [
        {
            key: "island",
            name: "Island",
            icon: "set-island",
            description: "The notch at the top of the screen and what it shows when you hover it.",
            settings: [
                {
                    key: "islandAutoHide",
                    name: "Auto hide",
                    description: "Only show the island when the pointer touches the top of the screen."
                }
            ]
        },
        {
            key: "dock",
            name: "Dock",
            icon: "set-dock",
            description: "The bar at the bottom: the power button, your pinned and open apps and the date.",
            keywords: "pinned apps pin unpin favourites favorites launcher",
            extra: "pinned",
            settings: [
                {
                    key: "dockAutoHide",
                    name: "Auto hide",
                    description: "Only show the dock when the pointer touches the bottom of the screen."
                },
                {
                    key: "dockNotch",
                    name: "Notch mode",
                    description: "The dock becomes a notch at the bottom, like the island. The power button and the date come out of the bottom corners when the pointer touches them."
                }
            ]
        },
        {
            key: "wallpaper",
            name: "Wallpaper",
            icon: "set-wallpaper",
            description: "The picture on the desktop, the lock screen and the login screen.",
            keywords: "background picture image add drop remove delete",
            settings: [],
            extra: "wallpapers"
        },
        {
            key: "theme",
            name: "Theme",
            icon: "set-theme",
            description: "The colours of the shell - and of GTK and Qt apps, kitty, Firefox and the window borders with it.",
            keywords: "colour color dark default noir mocha catppuccin",
            settings: [],
            extra: "themes"
        },
        {
            key: "notifications",
            name: "Notifications",
            icon: "bell-fill",
            description: "The cards in the top-right corner and the last 50 that came in.",
            keywords: "history do not disturb bell clear",
            settings: [
                {
                    key: "notificationsOn",
                    name: "Notifications",
                    description: "Show a card when a notification comes in. Off: Do not disturb - they only go to the history. The same as the bell in the island."
                }
            ],
            extra: "history"
        },
        {
            key: "appearance",
            name: "Appearance",
            icon: "set-appearance",
            description: "The borders round the windows and round the frame, the gap round the windows, the power button and the app icons.",
            keywords: "border width thickness outline ring frame window look gap gaps space spacing margin padding icon icons pack theme yamis adwaita papirus app apps power button logo frameshell",
            settings: [
                {
                    key: "windowBorder",
                    kind: "slider",
                    min: 0,
                    max: 4,
                    unit: "px",
                    name: "Window border",
                    description: "The ring round every window - light on the focused one, dark on the others."
                },
                {
                    key: "frameBorder",
                    kind: "slider",
                    min: 0,
                    max: 4,
                    unit: "px",
                    name: "Frame border",
                    description: "The outline of the frame, the island, the panels and the pop-ups."
                },
                {
                    key: "windowGap",
                    kind: "slider",
                    min: 5,
                    max: 20,
                    unit: "px",
                    get: () => Config.windowGap,
                    set: v => Config.setWindowGap(v),
                    name: "Window gap",
                    description: "The space round every window - to the frame and between two windows."
                }
            ],
            extra: "icons"
        },
        {
            key: "blur",
            name: "Blur",
            icon: "set-blur",
            description: "The blur behind see-through windows and behind the shell.",
            keywords: "blur transparent transparency opacity see-through glass frosted size passes brightness contrast",
            settings: [
                {
                    key: "windowBlur",
                    owner: "config",
                    name: "Apply blur to windows",
                    description: "Blurs what is behind see-through windows, like kitty. It does not make a window see-through - the app does that itself."
                },
                {
                    key: "shellBlur",
                    owner: "config",
                    name: "Apply blur to shell",
                    description: "The frame, the island, the panels and the pop-ups become see-through, with a blur behind them. Their text and icons stay solid."
                },
                {
                    key: "shellOpacity",
                    kind: "slider",
                    min: 0.5,
                    max: 1,
                    step: 0.05,
                    percent: true,
                    needs: ["shellBlur"],
                    name: "Shell opacity",
                    description: "How solid the shell is with its blur: lower is more see-through."
                },
                {
                    key: "blurSize",
                    kind: "slider",
                    min: 1,
                    max: 20,
                    needs: ["windowBlur", "shellBlur"],
                    name: "Size",
                    description: "How far the blur reaches."
                },
                {
                    key: "blurPasses",
                    kind: "slider",
                    min: 1,
                    max: 4,
                    needs: ["windowBlur", "shellBlur"],
                    name: "Passes",
                    description: "How many times it is blurred: more is smoother and stronger (and a little more work for the GPU)."
                },
                {
                    key: "blurBrightness",
                    kind: "slider",
                    min: 0,
                    max: 2,
                    step: 0.05,
                    decimals: 2,
                    needs: ["windowBlur", "shellBlur"],
                    name: "Brightness",
                    description: "How bright what is behind looks (1 = unchanged)."
                },
                {
                    key: "blurContrast",
                    kind: "slider",
                    min: 0,
                    max: 2,
                    step: 0.05,
                    decimals: 2,
                    needs: ["windowBlur", "shellBlur"],
                    name: "Contrast",
                    description: "How much contrast what is behind keeps (1 = unchanged)."
                }
            ]
        },
        {
            key: "wifi",
            name: "Wi-Fi",
            icon: "wifi",
            description: "Wireless networks: switch Wi-Fi on or off and join one.",
            keywords: "wifi wi-fi wlan wireless network networks internet connect disconnect password hotspot forget",
            settings: [],
            extra: "wifi"
        },
        {
            key: "bluetooth",
            name: "Bluetooth",
            icon: "bluetooth",
            description: "Your Bluetooth devices, and new ones nearby - put one in pairing mode to see it.",
            keywords: "bluetooth bt pair pairing connect disconnect forget headphones headset earbuds speaker mouse keyboard gamepad controller phone wireless",
            settings: [],
            extra: "bluetooth"
        },
        {
            key: "devices",
            name: "Devices",
            icon: "set-devices",
            description: "Sound, the keyboard, the mouse and the touchpad.",
            keywords: "audio sound output input speaker speakers headphones headset microphone mic volume mute keyboard repeat delay rate num lock numlock mouse pointer speed sensitivity acceleration scroll natural focus follows cursor warp click touchpad trackpad tap typing",
            settings: [],
            extra: "devices"
        },
        {
            key: "screenshot",
            name: "Screenshot",
            icon: "set-screenshot",
            description: "Print freezes the screen to pick an area, Shift + Print takes the whole screen.",
            keywords: "screenshot screen shot capture print snip snipping cursor pointer mouse picture",
            settings: [
                {
                    key: "screenshotCursor",
                    name: "Capture cursor",
                    description: "The pointer is in the picture, where it was when you pressed Print."
                }
            ]
        },
        {
            key: "keybinds",
            name: "Keybinds",
            icon: "set-keybinds",
            description: "Every keyboard shortcut, as Hyprland has them now (hyprland.lua).",
            keywords: "keybind keybinds keybinding keybindings binding bindings shortcut shortcuts hotkey hotkeys key keys keyboard super combination",
            settings: [],
            extra: "keybinds"
        },
        {
            key: "system",
            name: "System",
            icon: "set-system",
            description: "You, this computer and what runs on it.",
            keywords: "profile picture photo avatar face name user account about os operating system version distribution distro linux kernel computer device hardware processor cpu memory ram graphics gpu disk frameshell shell hyprland quickshell",
            settings: [],
            extra: "system"
        }
    ]

    // does a page match what was typed into the search field (its name, what it
    // is about, or one of its settings)
    function matches(pg, query) {
        const q = query.trim().toLowerCase();
        if (q === "")
            return true;
        const words = [pg.name, pg.description, pg.keywords || ""].concat(pg.settings.map(s => s.name + " " + (s.description || "")));
        return words.join(" ").toLowerCase().indexOf(q) >= 0;
    }

    // ── pieces of the pages ───────────────────────────────────────────────

    // The rows of a card of settings: one row each, a thin line between them (`lineFirst`:
    // above the first one too - under a card's heading). A setting is a switch for a
    // property of Store (or of Config: owner "config"), or with kind "slider" a slider for
    // one of Config - or, with `get` / `set` functions, for anything else (the volume of
    // the sound device in use). "needs": it only counts while one of these settings is on;
    // "when": while this function says so (else greyed out).
    component SettingRows: Column {
        id: rows

        property var settings: []
        property bool lineFirst: false

        Repeater {
            model: rows.settings

            Item {
                id: setting
                required property var modelData
                required property int index
                readonly property real inset: Theme.px(16)

                readonly property bool isSlider: modelData.kind === "slider"
                readonly property var owner: isSlider || modelData.owner === "config" ? Config : Store
                readonly property real min: modelData.min !== undefined ? modelData.min : 0
                readonly property real max: modelData.max !== undefined ? modelData.max : 1
                readonly property real step: modelData.step || 1
                readonly property int steps: Math.max(1, Math.round((max - min) / step))
                readonly property real number: isSlider ? (modelData.get ? modelData.get() : Config[modelData.key]) : 0
                readonly property bool on: !isSlider && !!(modelData.get ? modelData.get() : owner[modelData.key])
                readonly property bool usable: (!modelData.needs || modelData.needs.some(k => Config[k])) && (!modelData.when || modelData.when())

                function apply(v) {
                    if (modelData.set)
                        modelData.set(v);
                    else
                        owner[modelData.key] = v;
                }

                width: rows.width
                opacity: usable ? 1 : 0.45

                Behavior on opacity {
                    Anim {
                        duration: Theme.durFast
                    }
                }
                height: isSlider ? slider.y + slider.height + Theme.px(16) : Math.max(Theme.px(64), texts.height + 2 * Theme.px(14))

                Rectangle {
                    visible: setting.index > 0 || rows.lineFirst
                    x: setting.inset
                    width: parent.width - 2 * setting.inset
                    height: 1
                    color: Config.selected
                }

                Column {
                    id: texts
                    x: setting.inset
                    y: setting.isSlider ? Theme.px(14) : Math.round((parent.height - height) / 2)
                    width: Math.max(0, (setting.isSlider ? valueLabel.x : switcher.x) - x - setting.inset)
                    spacing: Theme.px(3)

                    Txt {
                        id: nameLabel
                        width: parent.width
                        text: setting.modelData.name
                        font.pixelSize: Theme.px(15)
                        font.weight: Font.Medium
                    }
                    Txt {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: setting.modelData.description
                        font.pixelSize: Theme.px(12)
                        font.weight: Font.Medium
                        color: Config.textDim
                    }
                }

                Toggle {
                    id: switcher
                    visible: !setting.isSlider
                    enabled: setting.usable
                    x: parent.width - width - setting.inset
                    y: Math.round((parent.height - height) / 2)
                    width: Theme.px(44)
                    height: Theme.px(26)
                    // the rows are Config.hover - in Noir the toggle's own #060606:
                    // off, the theme's dim grey instead
                    offColor: Config.iconDim
                    checked: setting.on
                    onToggled: on => setting.apply(on)
                }

                // a slider: its value on the right of its name, like the volume's "64%"
                Txt {
                    id: valueLabel
                    visible: setting.isSlider
                    x: parent.width - width - setting.inset
                    y: texts.y + Math.round((nameLabel.height - height) / 2)
                    // as a percentage, or with its decimals and unit
                    text: setting.modelData.percent ? Math.round(setting.number * 100) + " %" : setting.number.toFixed(setting.modelData.decimals || 0) + (setting.modelData.unit ? " " + setting.modelData.unit : "")
                    font.pixelSize: Theme.px(13)
                    font.weight: Font.Medium
                    color: Config.textDim
                }

                // the same slider as the volume and the brightness, in steps of `step`
                FSlider {
                    id: slider
                    visible: setting.isSlider
                    interactive: setting.usable
                    x: setting.inset
                    y: texts.y + texts.height + Theme.px(12)
                    width: parent.width - 2 * setting.inset
                    steps: setting.steps
                    value: setting.max > setting.min ? (setting.number - setting.min) / (setting.max - setting.min) : 0
                    onMoved: v => setting.apply(Number((setting.min + Math.round(v * setting.steps) * setting.step).toFixed(4)))
                }
            }
        }
    }

    // A card with a heading - an icon, a name and what it is about; on the right of
    // it what `side` holds (a switch) and an arrow - and its content under it, shown
    // when you click the heading (closed at first; the arrow turns, the card grows) -
    // or, `collapsible: false`, while `expanded` says so (no arrow: Wi-Fi, Bluetooth).
    // `volumeIcon`: the heading's icon is the speaker with its waves, as in the volume
    // slider (`level`, `muted`).
    // one key of a shortcut (the Keybinds page): its name on a small rounded key
    component KeyCap: Rectangle {
        property string label: ""

        width: Math.max(height, capText.implicitWidth + Theme.px(14))
        height: Theme.px(26)
        radius: Theme.px(7)
        color: Config.selected
        antialiasing: true

        Txt {
            id: capText
            anchors.centerIn: parent
            text: parent.label
            font.pixelSize: Theme.px(12)
            font.weight: Font.DemiBold
        }
    }

    component DeviceCard: Rectangle {
        id: dcard

        property string title: ""
        property string icon: ""
        property string description: ""
        property bool volumeIcon: false
        property real level: 1
        property bool muted: false
        property bool expanded: false
        // false: no arrow and the heading is no button - `expanded` is set from outside
        // (Wi-Fi, Bluetooth: open while their switch is on)
        property bool collapsible: true
        property alias side: sideRow.data
        default property alias content: body.data
        readonly property real inset: Theme.px(16)

        height: head.height + bodyClip.height
        radius: Theme.px(16)
        color: Config.hover

        Item {
            id: head
            width: parent.width
            height: Math.max(Theme.px(64), headText.height + 2 * Theme.px(14))

            // the whole heading opens and closes it (the switch beside the arrow does its own thing)
            MouseArea {
                id: headArea
                anchors.fill: parent
                visible: dcard.collapsible
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: dcard.expanded = !dcard.expanded
            }

            Rectangle {
                id: chip
                x: dcard.inset
                y: Math.round((parent.height - height) / 2)
                width: Theme.px(32)
                height: width
                radius: width / 2
                color: Config.selected
                antialiasing: true

                Icon {
                    visible: !dcard.volumeIcon
                    x: Math.round((parent.width - width) / 2)
                    y: Math.round((parent.height - height) / 2)
                    size: Theme.px(16)
                    name: dcard.icon
                }
                VolumeIcon {
                    visible: dcard.volumeIcon
                    x: Math.round((parent.width - width) / 2)
                    y: Math.round((parent.height - height) / 2)
                    size: Theme.px(16)
                    level: dcard.level
                    muted: dcard.muted
                }
            }

            Column {
                id: headText
                x: chip.x + chip.width + Theme.px(12)
                y: Math.round((parent.height - height) / 2)
                width: Math.max(0, (sideRow.width > 0 ? sideRow.x : arrow.visible ? arrow.x : parent.width - dcard.inset) - Theme.px(12) - x)
                spacing: Theme.px(3)

                Txt {
                    width: parent.width
                    text: dcard.title
                    font.pixelSize: Theme.px(15)
                    font.weight: Font.Medium
                }
                Txt {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    visible: text.length > 0
                    text: dcard.description
                    font.pixelSize: Theme.px(12)
                    font.weight: Font.Medium
                    color: Config.textDim
                }
            }

            Row {
                id: sideRow
                x: arrow.visible ? arrow.x - width - Theme.px(14) : parent.width - width - dcard.inset
                y: Math.round((parent.height - height) / 2)
                spacing: Theme.px(8)
            }

            // the dropdown arrow: down while closed, up while open
            Icon {
                id: arrow
                visible: dcard.collapsible
                x: parent.width - width - dcard.inset - Theme.px(2)
                y: Math.round((parent.height - height) / 2)
                size: Theme.px(14)
                name: "chev-right"
                color: Config.textDim
                rotation: dcard.expanded ? -90 : 90

                Behavior on rotation {
                    Anim {
                        duration: Theme.durOpen
                        curve: Theme.curveDecel
                    }
                }
            }
        }

        // the content: revealed from the top while the card grows
        Item {
            id: bodyClip
            y: head.height
            width: parent.width
            height: dcard.expanded ? body.height : 0
            clip: true
            visible: height > 0

            Behavior on height {
                PanelAnim {
                    opening: dcard.expanded
                }
            }

            Column {
                id: body
                width: parent.width
                opacity: dcard.expanded ? 1 : 0

                Behavior on opacity {
                    Anim {
                        duration: Theme.durSmall
                    }
                }
            }
        }
    }

    // The sound devices of one kind, the one in use marked (a click makes another one
    // the one in use): rounded boxes like the history's.
    component NodeList: Column {
        id: list

        property var nodes: []
        property var current: null
        property string empty: ""
        signal picked(var node)

        x: Theme.px(16)
        width: parent ? parent.width - 2 * x : 0
        spacing: Theme.px(8)
        topPadding: Theme.px(4)
        bottomPadding: Theme.px(16)

        Repeater {
            model: list.nodes

            Rectangle {
                id: nodeRow
                required property var modelData
                readonly property bool chosen: AudioDevices.isCurrent(modelData, list.current)

                width: list.width
                height: Theme.px(48)
                radius: Theme.px(12)
                color: nodeArea.containsMouse && !chosen ? Config.selected : Config.frame

                Behavior on color {
                    CAnim {}
                }

                // a round mark: filled for the one in use
                Rectangle {
                    id: ring
                    x: Theme.px(14)
                    y: Math.round((parent.height - height) / 2)
                    width: Theme.px(18)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: Theme.px(2)
                    border.color: nodeRow.chosen ? Config.text : Config.iconDim
                    antialiasing: true

                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.px(8)
                        height: width
                        radius: width / 2
                        color: Config.text
                        visible: nodeRow.chosen
                        antialiasing: true
                    }
                }

                Txt {
                    x: ring.x + ring.width + Theme.px(12)
                    y: Math.round((parent.height - height) / 2)
                    width: Math.max(0, parent.width - x - Theme.px(14))
                    text: AudioDevices.label(nodeRow.modelData)
                    font.pixelSize: Theme.px(14)
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: nodeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: nodeRow.chosen ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: list.picked(nodeRow.modelData)
                }
            }
        }

        // none
        Rectangle {
            width: list.width
            height: Theme.px(48)
            radius: Theme.px(12)
            color: Config.frame
            visible: list.nodes.length === 0

            Txt {
                anchors.centerIn: parent
                text: list.empty
                font.pixelSize: Theme.px(13)
                font.weight: Font.Medium
                color: Config.textDim
            }
        }
    }

    LazyLoader {
        active: Ui.settingsOpen

        FloatingWindow {
            id: win

            title: "Settings"
            implicitWidth: Theme.px(780)
            implicitHeight: Theme.px(460)
            color: Config.frame

            // closed from outside (its close key, a middle-click in the dock): it is gone,
            // the next "open" makes a new one
            onVisibleChanged: {
                if (!visible)
                    Ui.settingsOpen = false;
            }

            property string current: root.pages[0].key
            property string query: ""
            readonly property var shown: root.pages.filter(pg => root.matches(pg, query))
            readonly property var page: {
                for (const pg of root.pages) {
                    if (pg.key === current)
                        return pg;
                }
                return null;
            }

            // the search hides the page you are on: the first one it found
            onShownChanged: {
                if (shown.length > 0 && !shown.some(pg => pg.key === current))
                    current = shown[0].key;
            }

            // another page starts at its top
            onCurrentChanged: flick.contentY = 0

            Item {
                id: ui
                anchors.fill: parent

                readonly property real pad: Theme.px(14)
                readonly property real sideW: Theme.px(220)
                readonly property real cardRadius: Theme.px(16)

                // The thumbnails of the Wallpaper and Theme pages are as big as in a window that
                // fills half the screen beside another one (tiled); a wider window (maximized,
                // fullscreen) fits more of them in a row, not bigger ones. halfCard: the width
                // of a page's card in such a window - half the screen less the frame's sides
                // (Theme.inset), the gaps round and between the windows (Config.windowGap) and
                // the window border; less the sidebar and the margins.
                readonly property real windowGap: Math.max(0, Config.windowGap)
                readonly property real halfCard: {
                    const s = win.screen || Quickshell.screens[0];
                    const halfWindow = ((s ? s.width : 1920) - 2 * Theme.inset - 3 * windowGap) / 2 - 2 * Math.max(0, Config.windowBorder);
                    return Math.max(Theme.px(200), Math.floor(halfWindow) - 3 * pad - sideW);
                }
                // the thumbnails' card: its margin, the gap between them, their width (as in a
                // half-screen window: as many of at least 150 px as fit, filling the row)
                readonly property real thumbPad: Theme.px(16)
                readonly property real thumbGap: Theme.px(14)
                readonly property int halfCols: Math.max(2, Math.floor((halfCard - 2 * thumbPad + thumbGap) / (Theme.px(150) + thumbGap)))
                readonly property real thumbW: Math.max(1, Math.floor((halfCard - 2 * thumbPad - (halfCols - 1) * thumbGap) / halfCols))
                // The page's width in a wide window (maximized, fullscreen): as many thumbnails
                // as fit in 960 px (at 1080p), and the cards exactly as wide as a row of them
                // with its margins - the same 16 px on the left, the right and below.
                readonly property int wideCols: Math.max(halfCols, Math.floor((Theme.px(960) - 2 * thumbPad + thumbGap) / (thumbW + thumbGap)))
                readonly property real pageMax: wideCols * thumbW + (wideCols - 1) * thumbGap + 2 * thumbPad

                // a click on empty space takes the cursor out of the search field
                MouseArea {
                    anchors.fill: parent
                    onClicked: ui.forceActiveFocus()
                }

                // ── sidebar ──────────────────────────────────────────────
                Item {
                    id: side
                    x: ui.pad
                    y: ui.pad
                    width: ui.sideW
                    height: parent.height - 2 * ui.pad

                    // search field
                    Rectangle {
                        id: search
                        width: parent.width
                        height: Theme.px(36)
                        radius: Theme.px(10)
                        color: field.activeFocus ? Config.selected : Config.hover

                        Behavior on color {
                            CAnim {}
                        }

                        // the whole field puts the cursor in it (the text itself handles its own clicks)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: field.forceActiveFocus()
                        }

                        Icon {
                            x: Theme.px(12)
                            y: Math.round((parent.height - height) / 2)
                            size: Theme.px(14)
                            name: "search"
                            color: Config.textDim
                        }

                        Txt {
                            x: field.x
                            y: Math.round((parent.height - height) / 2)
                            visible: field.text.length === 0
                            text: "Search"
                            font.pixelSize: Theme.px(14)
                            font.weight: Font.Medium
                            color: Config.textDim
                        }

                        TextInput {
                            id: field
                            x: Theme.px(34)
                            y: Math.round((parent.height - height) / 2)
                            width: parent.width - x - Theme.px(10)
                            clip: true
                            font.family: Theme.font
                            font.pixelSize: Theme.px(14)
                            font.weight: Font.Medium
                            color: Config.text
                            selectionColor: Config.textSelection
                            selectedTextColor: Config.text
                            selectByMouse: true
                            onTextChanged: win.query = text
                            Keys.onEscapePressed: {
                                text = "";
                                ui.forceActiveFocus();
                            }
                        }
                    }

                    // the pages (they scroll when the window is too low for all of them)
                    Flickable {
                        id: sideFlick
                        y: search.height + Theme.px(12)
                        width: parent.width
                        height: Math.max(0, parent.height - y)
                        contentHeight: pagesCol.height
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        interactive: false          // scrolled by WheelScroll (below)

                    Column {
                        id: pagesCol
                        width: sideFlick.width
                        spacing: Theme.px(4)

                        Repeater {
                            model: win.shown

                            Item {
                                id: row
                                required property var modelData
                                readonly property bool selected: win.current === modelData.key
                                readonly property bool hot: rowArea.containsMouse

                                width: parent.width
                                height: Theme.px(44)

                                // the page you are on: a grey highlight and a white circle
                                // (like the power menu under the pointer)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.px(10)
                                    color: row.selected ? Config.selected : Config.hover
                                    opacity: row.selected || row.hot ? 1 : 0

                                    Behavior on color {
                                        CAnim {}
                                    }
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.durFast
                                        }
                                    }
                                }

                                Rectangle {
                                    id: chip
                                    x: Theme.px(7)
                                    y: Math.round((parent.height - height) / 2)
                                    width: Theme.px(30)
                                    height: width
                                    radius: width / 2
                                    color: row.selected ? Config.text : Config.selected
                                    antialiasing: true

                                    Behavior on color {
                                        CAnim {}
                                    }

                                    Icon {
                                        x: Math.round((parent.width - width) / 2)
                                        y: Math.round((parent.height - height) / 2)
                                        size: Theme.px(16)
                                        name: row.modelData.icon
                                        color: row.selected ? Config.frame : Config.text
                                    }
                                }

                                Txt {
                                    x: chip.x + chip.width + Theme.px(11)
                                    y: Math.round((parent.height - height) / 2)
                                    text: row.modelData.name
                                    font.pixelSize: Theme.px(15)
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: rowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.current = row.modelData.key
                                }
                            }
                        }
                    }
                    }

                    Item {
                        x: sideFlick.x
                        y: sideFlick.y
                        width: sideFlick.width
                        height: sideFlick.height

                        WheelScroll {
                            flickable: sideFlick
                        }
                    }

                    Txt {
                        x: Theme.px(10)
                        y: search.height + Theme.px(22)
                        visible: win.shown.length === 0
                        text: "No results"
                        font.pixelSize: Theme.px(14)
                        font.weight: Font.Medium
                        color: Config.textDim
                    }
                }

                // ── the page ─────────────────────────────────────────────
                Flickable {
                    id: flick
                    x: side.x + side.width + ui.pad
                    y: ui.pad
                    width: Math.max(0, parent.width - x - ui.pad)
                    height: parent.height - 2 * ui.pad
                    contentHeight: pageCol.height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    interactive: false          // scrolled by WheelScroll (below), like the clipboard
                    visible: win.page !== null

                    // in a wide window (maximized, fullscreen) the cards stop growing at
                    // ui.pageMax (882 px at 1080p) and stay in the middle
                    Column {
                        id: pageCol
                        width: Math.min(flick.width, ui.pageMax)
                        x: Math.round((flick.width - width) / 2)
                        spacing: Theme.px(12)

                        // its icon, name and what it is about
                        Rectangle {
                            width: parent.width
                            height: header.height + 2 * Theme.px(24)
                            radius: ui.cardRadius
                            color: Config.hover

                            Column {
                                id: header
                                y: Theme.px(24)
                                width: parent.width

                                Rectangle {
                                    x: Math.round((parent.width - width) / 2)
                                    width: Theme.px(56)
                                    height: width
                                    radius: width / 2
                                    color: Config.outline
                                    antialiasing: true

                                    Icon {
                                        x: Math.round((parent.width - width) / 2)
                                        y: Math.round((parent.height - height) / 2)
                                        size: Theme.px(28)
                                        name: win.page ? win.page.icon : ""
                                    }
                                }

                                Item {
                                    width: 1
                                    height: Theme.px(14)
                                }

                                Txt {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: win.page ? win.page.name : ""
                                    font.pixelSize: Theme.px(20)
                                    font.weight: Font.DemiBold
                                }

                                Item {
                                    width: 1
                                    height: Theme.px(6)
                                }

                                Txt {
                                    x: Theme.px(28)
                                    width: Math.max(0, parent.width - 2 * x)
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    text: win.page ? win.page.description : ""
                                    font.pixelSize: Theme.px(13)
                                    font.weight: Font.Medium
                                    color: Config.textDim
                                }
                            }
                        }

                        // its settings: one row each, a thin line between them
                        Rectangle {
                            width: parent.width
                            height: settingsCol.height
                            radius: ui.cardRadius
                            color: Config.hover
                            visible: win.page !== null && win.page.settings.length > 0

                            SettingRows {
                                id: settingsCol
                                width: parent.width
                                settings: win.page ? win.page.settings : []
                            }
                        }

                        // the page's own card
                        Loader {
                            width: parent.width
                            active: win.page !== null && win.page.extra === "wallpapers"
                            visible: active
                            sourceComponent: wallpapersCard
                        }
                        Loader {
                            width: parent.width
                            active: win.page !== null && win.page.extra === "history"
                            visible: active
                            sourceComponent: historyCard
                        }
                        Loader {
                            width: parent.width
                            active: win.page !== null && win.page.extra === "themes"
                            visible: active
                            sourceComponent: themesCard
                        }
                        Loader {
                            width: parent.width
                            active: win.page !== null && win.page.extra === "icons"
                            visible: active
                            sourceComponent: iconsCard
                        }
                        Loader {
                            width: parent.width
                            active: win.page !== null && win.page.extra === "keybinds"
                            visible: active
                            sourceComponent: keybindsCard
                        }
                        Loader {
                            width: parent.width
                            active: win.page !== null && win.page.extra === "system"
                            visible: active
                            sourceComponent: profileCard
                        }
                        Loader {
                            width: parent.width
                            active: win.page !== null && win.page.extra === "system"
                            visible: active
                            sourceComponent: aboutCard
                        }
                        Loader {
                            width: parent.width
                            active: win.page !== null && win.page.extra === "pinned"
                            visible: active
                            sourceComponent: pinnedCard
                        }
                        Loader {
                            width: parent.width
                            active: win.page !== null && win.page.extra === "devices"
                            visible: active
                            sourceComponent: devicesCard
                        }
                        Loader {
                            width: parent.width
                            active: win.page !== null && win.page.extra === "wifi"
                            visible: active
                            sourceComponent: wifiCard
                        }
                        Loader {
                            width: parent.width
                            active: win.page !== null && win.page.extra === "bluetooth"
                            visible: active
                            sourceComponent: btCard
                        }
                    }
                }

                // the wheel over the page: Qt's scrolling, Config.scrollStep px a notch
                Item {
                    x: flick.x
                    y: flick.y
                    width: flick.width
                    height: flick.height

                    WheelScroll {
                        flickable: flick
                    }
                }

                // a thin bar in the right margin showing where you are on a long page
                Rectangle {
                    readonly property bool overflows: flick.visible && flick.contentHeight > flick.height + 1
                    x: flick.x + flick.width + Math.round((ui.pad - width) / 2)
                    y: flick.y + Math.max(0, flick.visibleArea.yPosition) * flick.height
                    width: Theme.px(3)
                    height: Math.min(flick.visibleArea.heightRatio, 1 - Math.max(0, flick.visibleArea.yPosition)) * flick.height
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

                // ── Wallpaper: the pictures ──────────────────────────────
                // One tile per picture of the wallpaper folder, in the order of the
                // switcher (SUPER + CTRL + Left / Right). The wallpaper has a ring round it; a
                // click on another makes it the wallpaper. Under the pointer, a picture
                // you added shows a bin in its corner: a click on it removes the picture
                // (to the trash; the ones that come with frameshell stay). The last tile
                // adds pictures: a click opens a file dialog, or drop pictures on it.
                Component {
                    id: wallpapersCard

                    Rectangle {
                        id: wcard
                        readonly property real pad: ui.thumbPad
                        readonly property real gap: ui.thumbGap
                        // the thumbnails' size: as in a half-screen window (ui.thumbW; a narrower
                        // card: as they fit); wider: more in a row
                        readonly property real refW: Math.min(width, ui.halfCard)
                        readonly property int refCols: Math.max(2, Math.floor((refW - 2 * pad + gap) / (Theme.px(150) + gap)))
                        readonly property real cellW: Math.max(1, Math.floor((refW - 2 * pad - (refCols - 1) * gap) / refCols))
                        readonly property int cols: Math.max(refCols, Math.floor((width - 2 * pad + gap) / (cellW + gap)))
                        readonly property real cellH: Math.max(1, Math.round(cellW * 9 / 16))
                        readonly property real tileRadius: Theme.px(12)
                        // the pictures are only read once the card has its width (at the size they are shown)
                        readonly property bool sized: cellW > Theme.px(40)

                        height: grid.height + 2 * pad
                        radius: ui.cardRadius
                        color: Config.hover

                        // The tiles, kept in step with the folder one picture at a time (a
                        // picture added or removed: only its tile comes or goes, the others
                        // stay - and keep their pictures loaded).
                        ListModel {
                            id: tiles
                        }

                        function sync() {
                            const want = Wallpapers.files;
                            let changed = false;
                            for (let i = tiles.count - 1; i >= 0; i--) {
                                if (want.indexOf(tiles.get(i).path) < 0) {
                                    if (!changed)
                                        wcard.startReflow();
                                    changed = true;
                                    tiles.remove(i);
                                }
                            }
                            for (let i = 0; i < want.length; i++) {
                                if (i < tiles.count && tiles.get(i).path === want[i])
                                    continue;
                                if (!changed && tiles.count > 0)
                                    wcard.startReflow();
                                changed = true;
                                let at = -1;
                                for (let k = i + 1; k < tiles.count; k++) {
                                    if (tiles.get(k).path === want[i]) {
                                        at = k;
                                        break;
                                    }
                                }
                                if (at >= 0)
                                    tiles.move(at, i, 1);
                                else
                                    tiles.insert(i, {
                                        path: want[i]
                                    });
                            }
                        }
                        Component.onCompleted: sync()
                        Connections {
                            target: Wallpapers

                            function onFilesChanged() {
                                wcard.sync();
                            }
                        }

                        // A picture added: its tile fades in, the ones after it (and the
                        // "Add" tile) glide over to make room; one removed: they glide back.
                        // Only then - not when the window changes size, nor when the page opens.
                        property bool reflow: false
                        function startReflow() {
                            reflow = true;
                            reflowEnd.restart();
                        }
                        Timer {
                            id: reflowEnd
                            interval: Theme.durOpen + 50
                            onTriggered: wcard.reflow = false
                        }
                        property Transition fadeIn: Transition {
                            Anim {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Theme.durSmall
                            }
                        }
                        property Transition glide: Transition {
                            Anim {
                                properties: "x,y"
                                duration: Theme.durOpen
                                curve: Theme.curveDecel
                            }
                        }

                        Grid {
                            id: grid
                            // the rows in the middle should they not fill the card (a window between
                            // half-screen and maximized); the pictures go from the left
                            x: Math.max(wcard.pad, Math.round((wcard.width - wcard.cols * wcard.cellW - (wcard.cols - 1) * wcard.gap) / 2))
                            y: wcard.pad
                            columns: wcard.cols
                            spacing: wcard.gap
                            add: wcard.reflow ? wcard.fadeIn : null
                            move: wcard.reflow ? wcard.glide : null

                            Repeater {
                                model: tiles

                                Item {
                                    id: tile
                                    required property string path
                                    readonly property bool isCurrent: Wallpapers.current === path
                                    // removed with the bin: it fades out first, then goes
                                    property bool leaving: false

                                    width: wcard.cellW
                                    height: wcard.cellH
                                    scale: tileArea.pressed ? 0.96 : 1
                                    opacity: leaving ? 0 : 1

                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.durSmall
                                        }
                                    }

                                    // the fade over: the picture goes to the trash (and its tile
                                    // with it); should it still be here a while later, it was
                                    // not removed after all: it comes back
                                    Timer {
                                        id: removeLater
                                        interval: Theme.durSmall
                                        onTriggered: {
                                            Wallpapers.remove(tile.path);
                                            stayed.restart();
                                        }
                                    }
                                    Timer {
                                        id: stayed
                                        interval: 2000
                                        onTriggered: tile.leaving = false
                                    }

                                    Behavior on scale {
                                        Anim {
                                            duration: Theme.durFast
                                            curve: Theme.curveSpring
                                        }
                                    }

                                    // the wallpaper: a ring round it, a little away from the picture
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -Theme.px(4)
                                        radius: wcard.tileRadius + Theme.px(4)
                                        color: "transparent"
                                        border.width: Theme.px(2)
                                        border.color: Config.text
                                        antialiasing: true
                                        opacity: tile.isCurrent ? 1 : 0

                                        Behavior on opacity {
                                            Anim {
                                                duration: Theme.durSmall
                                            }
                                        }
                                    }

                                    ClippingRectangle {
                                        anchors.fill: parent
                                        radius: wcard.tileRadius
                                        color: Config.selected          // until the picture has loaded

                                        Image {
                                            id: tileImage
                                            anchors.fill: parent
                                            source: wcard.sized ? "file://" + tile.path : ""
                                            sourceSize.width: Math.ceil(tile.width * 2)
                                            sourceSize.height: Math.ceil(tile.height * 2)
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            smooth: true
                                            mipmap: true
                                            opacity: status === Image.Ready ? 1 : 0

                                            Behavior on opacity {
                                                Anim {
                                                    duration: Theme.durSmall
                                                }
                                            }

                                            // a picture that is still being copied into the folder
                                            // can't be read yet: try again a few times
                                            property int tries: 0
                                            onStatusChanged: {
                                                if (status === Image.Error && tries < 5)
                                                    retry.restart();
                                            }
                                            Timer {
                                                id: retry
                                                interval: 1500
                                                onTriggered: {
                                                    tileImage.tries++;
                                                    tileImage.source = "";
                                                    tileImage.source = Qt.binding(() => wcard.sized ? "file://" + tile.path : "");
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: tileArea
                                        anchors.fill: parent
                                        enabled: !tile.leaving
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Wallpapers.set(tile.path)
                                    }

                                    // a picture you added: a red bin on a dark circle in its
                                    // corner while the pointer is on it - a click removes it
                                    Rectangle {
                                        id: bin
                                        readonly property bool shown: !tile.leaving && Wallpapers.removable(tile.path) && (tileArea.containsMouse || binArea.containsMouse)

                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: Theme.px(7)
                                        width: Theme.px(26)
                                        height: width
                                        radius: width / 2
                                        color: Config.frame
                                        antialiasing: true
                                        visible: opacity > 0
                                        opacity: shown ? 1 : 0
                                        scale: binArea.pressed ? 0.9 : 1

                                        // fades in and out with the pointer
                                        Behavior on opacity {
                                            Anim {
                                                duration: Theme.durSmall
                                            }
                                        }
                                        Behavior on scale {
                                            Anim {
                                                duration: Theme.durFast
                                                curve: Theme.curveSpring
                                            }
                                        }

                                        // in the exact middle: about 15 px, with the same whole number
                                        // of pixels between it and the circle's edge on every side
                                        Icon {
                                            readonly property int room: Math.floor((bin.width - Theme.px(15)) / 2)
                                            x: room
                                            y: room
                                            name: "bin"
                                            size: bin.width - 2 * room
                                            color: Config.warning
                                        }

                                        MouseArea {
                                            id: binArea
                                            anchors.fill: parent
                                            enabled: bin.shown
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                tile.leaving = true;
                                                removeLater.restart();
                                            }
                                        }
                                    }
                                }
                            }

                            // add pictures: a file dialog, or pictures dropped on it; they are
                            // copied into the folder
                            Item {
                                id: addTile
                                width: wcard.cellW
                                height: wcard.cellH
                                scale: addArea.pressed ? 0.96 : 1

                                Behavior on scale {
                                    Anim {
                                        duration: Theme.durFast
                                        curve: Theme.curveSpring
                                    }
                                }

                                // with pictures dragged over it: a brighter outline, a light fill
                                Rectangle {
                                    anchors.fill: parent
                                    radius: wcard.tileRadius
                                    color: dropArea.containsDrag ? Config.selected : "transparent"
                                    border.width: Theme.px(1.5)
                                    border.color: dropArea.containsDrag ? Config.text : Config.iconDim
                                    antialiasing: true

                                    Behavior on color {
                                        CAnim {}
                                    }
                                    Behavior on border.color {
                                        CAnim {}
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.px(8)

                                    // a plus
                                    Item {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Theme.px(20)
                                        height: width

                                        Rectangle {
                                            y: Math.round((parent.height - height) / 2)
                                            width: parent.width
                                            height: Theme.px(2.5)
                                            radius: height / 2
                                            color: Config.text
                                        }
                                        Rectangle {
                                            x: Math.round((parent.width - width) / 2)
                                            width: Theme.px(2.5)
                                            height: parent.height
                                            radius: width / 2
                                            color: Config.text
                                        }
                                    }

                                    Txt {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: dropArea.containsDrag ? "Drop to add" : (Wallpapers.adding ? "Adding…" : "Add")
                                        font.pixelSize: Theme.px(13)
                                        font.weight: Font.Medium
                                        color: dropArea.containsDrag ? Config.text : Config.textDim
                                    }
                                }

                                MouseArea {
                                    id: addArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Wallpapers.add()
                                }

                                // pictures dragged from the file manager (or anything else that
                                // drags files): copied in like the ones picked in the dialog
                                DropArea {
                                    id: dropArea
                                    anchors.fill: parent
                                    keys: ["text/uri-list"]
                                    onEntered: drag => drag.accept(Qt.CopyAction)
                                    onDropped: drop => {
                                        if (Wallpapers.addDropped(drop.urls) > 0)
                                            drop.accept(Qt.CopyAction);
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Theme: the colour themes ─────────────────────────────
                // One card per theme, like the theme switcher's (SUPER + CTRL + Up / Down): its
                // main colour, its five colours as dots, its name; in the order of the
                // switcher. The theme in use has a ring round it, like the wallpaper; a
                // click on another switches to it. Under the pointer a card grows a little.
                Component {
                    id: themesCard

                    Rectangle {
                        id: tcard
                        readonly property real pad: ui.thumbPad
                        readonly property real gap: ui.thumbGap
                        // like the wallpapers': as big as in a half-screen window
                        readonly property real refW: Math.min(width, ui.halfCard)
                        readonly property int refCols: Math.max(2, Math.floor((refW - 2 * pad + gap) / (Theme.px(150) + gap)))
                        readonly property real cellW: Math.max(1, Math.floor((refW - 2 * pad - (refCols - 1) * gap) / refCols))
                        readonly property int cols: Math.max(refCols, Math.floor((width - 2 * pad + gap) / (cellW + gap)))
                        readonly property real cellH: Math.max(1, Math.round(cellW * 9 / 16))
                        readonly property real tileRadius: Theme.px(12)

                        height: themeGrid.height + 2 * pad
                        radius: ui.cardRadius
                        color: Config.hover

                        Grid {
                            id: themeGrid
                            // like the wallpapers: from the left (a place left empty on the right)
                            x: Math.max(tcard.pad, Math.round((tcard.width - tcard.cols * tcard.cellW - (tcard.cols - 1) * tcard.gap) / 2))
                            y: tcard.pad
                            columns: tcard.cols
                            spacing: tcard.gap

                            Repeater {
                                model: Themes.list

                                Item {
                                    id: themeTile
                                    required property var modelData
                                    readonly property bool isCurrent: Config.theme.name === modelData.name

                                    width: tcard.cellW
                                    height: tcard.cellH
                                    scale: themeArea.pressed ? 0.96 : 1

                                    Behavior on scale {
                                        Anim {
                                            duration: Theme.durFast
                                            curve: Theme.curveSpring
                                        }
                                    }

                                    // the theme in use: a ring round it, a little away from the card
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -Theme.px(4)
                                        radius: tcard.tileRadius + Theme.px(4)
                                        color: "transparent"
                                        border.width: Theme.px(2)
                                        border.color: Config.text
                                        antialiasing: true
                                        opacity: themeTile.isCurrent ? 1 : 0

                                        Behavior on opacity {
                                            Anim {
                                                duration: Theme.durSmall
                                            }
                                        }
                                    }

                                    // the card in the theme's own colours, a thin edge so a dark one
                                    // still shows on the dark card behind it
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: tcard.tileRadius
                                        color: Config.themeColor(themeTile.modelData, "frame")
                                        border.width: 1
                                        border.color: Config.iconDim
                                        antialiasing: true

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: Theme.px(10)

                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: Theme.px(6)

                                                Repeater {
                                                    model: Themes.dots(themeTile.modelData)

                                                    Rectangle {
                                                        required property color modelData
                                                        width: Theme.px(12)
                                                        height: width
                                                        radius: width / 2
                                                        color: modelData
                                                        antialiasing: true
                                                    }
                                                }
                                            }

                                            Txt {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: themeTile.modelData.name
                                                color: Config.themeColor(themeTile.modelData, "text")
                                                font.pixelSize: Theme.px(14)
                                                font.weight: Font.Medium
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: themeArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Themes.set(themeTile.modelData.name)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── App icons (Appearance) ───────────────────────────────
                // The icon packs as cards like the themes': a few of your apps in it (the
                // dock's pinned apps first), its name and what it is; the one in use has a
                // ring, a click makes one the pack in use (services/IconPacks.qml). One that
                // is not installed is greyed out. Only the shell's icons change.
                Component {
                    id: iconsCard

                    Column {
                        spacing: Theme.px(12)

                        // over it: the bottom bar's power button - the Frameshell logo (on) or the
                        // power sign (Store.powerLogo)
                        Rectangle {
                            width: parent.width
                            height: powerLogoRow.height
                            radius: ui.cardRadius
                            color: Config.hover

                            SettingRows {
                                id: powerLogoRow
                                width: parent.width
                                settings: [
                                    {
                                        key: "powerLogo",
                                        name: "Use Frameshell logo as power button",
                                        description: "The power button at the left of the bottom bar shows the Frameshell logo, else the power sign."
                                    }
                                ]
                            }
                        }

                        DeviceCard {
                            id: icard
                            width: parent.width
                            readonly property real pad: ui.thumbPad
                            readonly property real gap: ui.thumbGap
                            // as big as the themes' cards
                            readonly property real refW: Math.min(width, ui.halfCard)
                            readonly property int refCols: Math.max(2, Math.floor((refW - 2 * pad + gap) / (Theme.px(150) + gap)))
                            readonly property real cellW: Math.max(1, Math.floor((refW - 2 * pad - (refCols - 1) * gap) / refCols))
                            readonly property int cols: Math.max(refCols, Math.floor((width - 2 * pad + gap) / (cellW + gap)))
                            readonly property real cellH: Math.max(1, Math.round(cellW * 9 / 16))
                            readonly property real tileRadius: Theme.px(12)
                            readonly property var samples: IconPacks.samples(4)
                            readonly property real iconGap: Theme.px(6)
                            readonly property real iconSize: Math.max(Theme.px(16), Math.min(Theme.px(28), Math.floor((cellW - 2 * Theme.px(16) - 3 * iconGap) / 4)))

                            // a pack installed since the shell started shows up
                            Component.onCompleted: IconPacks.rescan()

                            collapsible: false
                            expanded: true
                            title: "App icons"
                            icon: "apps"
                            description: "The icons of the apps in the dock, the launcher, the app switcher and the notifications."

                            Item {
                                width: icard.width
                                height: packGrid.height + icard.pad + Theme.px(4)

                                Grid {
                                    id: packGrid
                                    // like the themes: from the left (a place left empty on the right)
                                    x: Math.max(icard.pad, Math.round((icard.width - icard.cols * icard.cellW - (icard.cols - 1) * icard.gap) / 2))
                                    y: Theme.px(4)
                                    columns: icard.cols
                                    spacing: icard.gap

                                    Repeater {
                                        model: IconPacks.packs

                                        Item {
                                            id: packTile
                                            required property var modelData
                                            readonly property bool usable: IconPacks.available(modelData.name)
                                            readonly property bool isCurrent: IconPacks.current === modelData.name

                                            width: icard.cellW
                                            height: icard.cellH
                                            opacity: usable ? 1 : 0.45
                                            scale: packArea.pressed ? 0.96 : 1

                                            Behavior on scale {
                                                Anim {
                                                    duration: Theme.durFast
                                                    curve: Theme.curveSpring
                                                }
                                            }

                                            // the pack in use: a ring round it, a little away from the card
                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.margins: -Theme.px(4)
                                                radius: icard.tileRadius + Theme.px(4)
                                                color: "transparent"
                                                border.width: Theme.px(2)
                                                border.color: Config.text
                                                antialiasing: true
                                                opacity: packTile.isCurrent ? 1 : 0

                                                Behavior on opacity {
                                                    Anim {
                                                        duration: Theme.durSmall
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: icard.tileRadius
                                                color: Config.frame
                                                antialiasing: true

                                                Column {
                                                    anchors.centerIn: parent
                                                    width: parent.width - 2 * Theme.px(12)
                                                    spacing: Theme.px(4)

                                                    Row {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        spacing: icard.iconGap

                                                        Repeater {
                                                            model: icard.samples

                                                            AppIcon {
                                                                required property string modelData
                                                                size: icard.iconSize
                                                                source: packTile.usable ? IconPacks.pathIn(modelData, packTile.modelData.name) : ""
                                                                label: modelData.slice(modelData.lastIndexOf(".") + 1)
                                                            }
                                                        }
                                                    }

                                                    Item {
                                                        width: 1
                                                        height: Theme.px(6)
                                                    }

                                                    Txt {
                                                        width: parent.width
                                                        horizontalAlignment: Text.AlignHCenter
                                                        elide: Text.ElideRight
                                                        text: packTile.modelData.title || packTile.modelData.name
                                                        font.pixelSize: Theme.px(14)
                                                        font.weight: Font.Medium
                                                    }
                                                    Txt {
                                                        width: parent.width
                                                        horizontalAlignment: Text.AlignHCenter
                                                        elide: Text.ElideRight
                                                        text: packTile.usable ? packTile.modelData.about : "Not installed"
                                                        font.pixelSize: Theme.px(11)
                                                        font.weight: Font.Medium
                                                        color: Config.textDim
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: packArea
                                                anchors.fill: parent
                                                enabled: packTile.usable
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Store.iconPack = packTile.modelData.name === IconPacks.qtTheme ? "" : packTile.modelData.name
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Keybinds ─────────────────────────────────────────────
                // Every shortcut Hyprland has now (hyprctl binds -j: also ones you added or
                // changed in hyprland.lua), as the description it has there says - one row
                // per action: the same action on more keys in one row ("or"), the workspaces'
                // number keys in one row ("1 - 5"). In four cards: windows, workspaces and
                // screens, apps and the shell, sound and music. Shortcuts without a
                // description (the shell's own, such as letting go of SUPER for the app
                // switcher) and those of a submap (the screenshot screen's) are left out.
                // Read when the page opens.
                Component {
                    id: keybindsCard

                    Column {
                        id: kcol
                        property var sections: []
                        property bool failed: false
                        readonly property real inset: Theme.px(16)

                        spacing: Theme.px(12)

                        // Hyprland's modifier bits: SHIFT 1, CTRL 4, ALT 8, SUPER 64
                        function modsOf(mask) {
                            const out = [];
                            if (mask & 64)
                                out.push("Super");
                            if (mask & 4)
                                out.push("Ctrl");
                            if (mask & 8)
                                out.push("Alt");
                            if (mask & 1)
                                out.push("Shift");
                            return out;
                        }
                        // a key's name as it is printed on the key
                        function keyName(k) {
                            const names = {
                                "period": ".",
                                "comma": ",",
                                "backslash": "\\",
                                "slash": "/",
                                "minus": "-",
                                "equal": "=",
                                "semicolon": ";",
                                "apostrophe": "'",
                                "grave": "`",
                                "bracketleft": "[",
                                "bracketright": "]",
                                "space": "Space",
                                "escape": "Esc",
                                "return": "Enter",
                                "tab": "Tab",
                                "backspace": "Backspace",
                                "delete": "Delete",
                                "insert": "Insert",
                                "home": "Home",
                                "end": "End",
                                "left": "\u2190",
                                "right": "\u2192",
                                "up": "\u2191",
                                "down": "\u2193",
                                "next": "Page Down",
                                "page_down": "Page Down",
                                "prior": "Page Up",
                                "page_up": "Page Up",
                                "print": "Print",
                                "super_l": "Super",
                                "super_r": "Super",
                                "mouse:272": "Left click",
                                "mouse:273": "Right click",
                                "mouse:274": "Middle click",
                                "mouse_up": "Scroll up",
                                "mouse_down": "Scroll down",
                                "xf86audioraisevolume": "Volume Up",
                                "xf86audiolowervolume": "Volume Down",
                                "xf86audiomute": "Mute",
                                "xf86audiomicmute": "Mic Mute",
                                "xf86audionext": "Next",
                                "xf86audioprev": "Previous",
                                "xf86audioplay": "Play",
                                "xf86audiopause": "Pause",
                                "xf86monbrightnessup": "Brightness Up",
                                "xf86monbrightnessdown": "Brightness Down"
                            };
                            const key = String(k || "");
                            const known = names[key.toLowerCase()];
                            if (known !== undefined)
                                return known;
                            if (key.length === 1)
                                return key.toUpperCase();
                            // XF86SomethingElse -> "Something Else"
                            if (/^XF86/i.test(key))
                                return key.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2");
                            return key.charAt(0).toUpperCase() + key.slice(1);
                        }
                        // which card a shortcut goes in, by what it does
                        function sectionOf(text) {
                            if (/to workspace \d|prev workspace|next workspace|workspace \d|output/i.test(text))
                                return 1;
                            if (/window/i.test(text))
                                return 0;
                            if (/volume|mute|track|play|pause/i.test(text))
                                return 3;
                            return 2;
                        }
                        // "1, 2, 3, 4, 5" -> "1 - 5" (else as they are)
                        function numbers(list) {
                            const n = list.map(x => parseInt(x)).sort((a, b) => a - b);
                            let run = n.length > 1;
                            for (let i = 1; i < n.length; i++) {
                                if (n[i] !== n[i - 1] + 1)
                                    run = false;
                            }
                            return run ? n[0] + "\u2013" + n[n.length - 1] : n.join(", ");
                        }

                        function read(text) {
                            let binds = [];
                            try {
                                binds = JSON.parse(text);
                            } catch (e) {
                                failed = true;
                                return;
                            }
                            const rows = [];             // { text, combos: [[caps]], section }
                            const byText = {};
                            const numbered = {};         // "Switch to workspace #|64" -> row with numbers
                            for (let i = 0; i < binds.length; i++) {
                                const b = binds[i];
                                const text = String(b.description || "").trim();
                                if (!b.has_description || text.length === 0 || (b.submap || "") !== "")
                                    continue;
                                const mods = modsOf(b.modmask || 0);
                                const key = String(b.key || "");
                                // "Switch to workspace 3" on SUPER + 3: one row for all the numbers
                                const m = text.match(/^(.*\D)(\d+)$/);
                                if (m && key === m[2]) {
                                    const id = m[1] + "#|" + (b.modmask || 0);
                                    if (!numbered[id]) {
                                        numbered[id] = {
                                            head: m[1],
                                            mods: mods,
                                            list: [],
                                            row: {
                                                text: "",
                                                combos: [],
                                                section: sectionOf(text)
                                            }
                                        };
                                        rows.push(numbered[id].row);
                                    }
                                    if (numbered[id].list.indexOf(m[2]) < 0)
                                        numbered[id].list.push(m[2]);
                                    continue;
                                }
                                const caps = mods.concat([keyName(key)]);
                                let row = byText[text];
                                if (!row) {
                                    row = byText[text] = {
                                        text: text,
                                        combos: [],
                                        section: sectionOf(text)
                                    };
                                    rows.push(row);
                                }
                                if (!row.combos.some(c => c.join("+") === caps.join("+")))
                                    row.combos.push(caps);
                            }
                            for (const id in numbered) {
                                const g = numbered[id];
                                const nums = numbers(g.list);
                                g.row.text = g.head + nums;
                                g.row.combos = [g.mods.concat([nums])];
                            }
                            const titles = ["Windows", "Workspaces and screens", "Apps and the shell", "Sound and music"];
                            const out = [];
                            for (let s = 0; s < titles.length; s++) {
                                const list = rows.filter(r => r.section === s);
                                if (list.length > 0)
                                    out.push({
                                        title: titles[s],
                                        rows: list
                                    });
                            }
                            sections = out;
                            failed = out.length === 0;
                        }

                        Process {
                            command: ["hyprctl", "binds", "-j"]
                            running: true
                            stdout: StdioCollector {
                                onStreamFinished: kcol.read(text)
                            }
                            onExited: code => {
                                if (code !== 0 && kcol.sections.length === 0)
                                    kcol.failed = true;
                            }
                        }

                        // Hyprland could not be asked (not running, or no hyprctl)
                        Rectangle {
                            visible: kcol.failed
                            width: kcol.width
                            height: failText.height + 2 * kcol.inset
                            radius: ui.cardRadius
                            color: Config.hover

                            Txt {
                                id: failText
                                x: kcol.inset
                                y: kcol.inset
                                width: parent.width - 2 * kcol.inset
                                wrapMode: Text.WordWrap
                                text: "Hyprland's shortcuts could not be read (hyprctl binds). They are in ~/.config/hypr/hyprland.lua."
                                font.pixelSize: Theme.px(13)
                                font.weight: Font.Medium
                                color: Config.textDim
                            }
                        }

                        Repeater {
                            model: kcol.sections

                            Rectangle {
                                id: section
                                required property var modelData

                                width: kcol.width
                                height: sectionCol.height + Theme.px(6)
                                radius: ui.cardRadius
                                color: Config.hover

                                Column {
                                    id: sectionCol
                                    width: parent.width

                                    // the card's name
                                    Item {
                                        width: parent.width
                                        height: Theme.px(44)

                                        Txt {
                                            x: kcol.inset
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: section.modelData.title
                                            font.pixelSize: Theme.px(14)
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    Repeater {
                                        model: section.modelData.rows

                                        Item {
                                            id: bindRow
                                            required property var modelData
                                            // the keys on the right, at most half the row; more ways
                                            // than fit in one line: one below the other
                                            readonly property real keysMax: Math.round(width * 0.55)
                                            readonly property bool stacked: oneLine.implicitWidth > keysMax

                                            width: parent.width
                                            height: Math.max(bindText.implicitHeight, keys.height) + 2 * Theme.px(10)

                                            Rectangle {
                                                x: kcol.inset
                                                width: parent.width - 2 * kcol.inset
                                                height: 1
                                                color: Config.selected
                                            }

                                            Txt {
                                                id: bindText
                                                x: kcol.inset
                                                width: Math.max(0, keys.x - Theme.px(16) - x)
                                                anchors.verticalCenter: parent.verticalCenter
                                                wrapMode: Text.WordWrap
                                                text: bindRow.modelData.text
                                                font.pixelSize: Theme.px(13)
                                                font.weight: Font.Medium
                                            }

                                            Column {
                                                id: keys
                                                x: parent.width - kcol.inset - width
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: bindRow.stacked ? bindRow.keysMax : oneLine.implicitWidth
                                                height: bindRow.stacked ? stackCol.implicitHeight : oneLine.implicitHeight

                                                // all ways in one line: "Super X  or  Super Alt X"
                                                Row {
                                                    id: oneLine
                                                    visible: !bindRow.stacked
                                                    spacing: Theme.px(8)

                                                    Repeater {
                                                        model: bindRow.modelData.combos

                                                        Row {
                                                            id: combo
                                                            required property var modelData
                                                            required property int index
                                                            spacing: Theme.px(4)

                                                            Txt {
                                                                visible: combo.index > 0
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                rightPadding: Theme.px(4)
                                                                text: "or"
                                                                font.pixelSize: Theme.px(12)
                                                                font.weight: Font.Medium
                                                                color: Config.textDim
                                                            }
                                                            Repeater {
                                                                model: combo.modelData

                                                                KeyCap {
                                                                    required property string modelData
                                                                    label: modelData
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                // too wide: one way under the other, on the right
                                                Column {
                                                    id: stackCol
                                                    visible: bindRow.stacked
                                                    width: bindRow.keysMax
                                                    spacing: Theme.px(6)

                                                    Repeater {
                                                        model: bindRow.modelData.combos

                                                        Item {
                                                            id: stackItem
                                                            required property var modelData
                                                            width: bindRow.keysMax
                                                            height: stackRow.implicitHeight

                                                            Row {
                                                                id: stackRow
                                                                anchors.right: parent.right
                                                                spacing: Theme.px(4)

                                                                Repeater {
                                                                    model: stackItem.modelData

                                                                    KeyCap {
                                                                        required property string modelData
                                                                        label: modelData
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
                            }
                        }
                    }
                }

                // ── Profile (System) ─────────────────────────────────────
                // Your picture and your name, as the lock and login screen show them
                // (services/Profile.qml). Change picture opens a file dialog: the picture is
                // cut square in the middle, 512 px, and saved to ~/.face and the login
                // screen's copy. With a picture set, a red bin on a dark circle sits in its
                // corner while the pointer is on it (like a wallpaper you added): a click
                // takes the picture away - it fades out, the first letter of your name is
                // back. Change name turns the name into a field: Save (or Enter) asks for
                // your password (pkexec), Cancel (or Esc) leaves it.
                Component {
                    id: profileCard

                    Rectangle {
                        id: pcard
                        readonly property real inset: Theme.px(16)
                        readonly property real faceSize: Theme.px(72)
                        property bool editing: false
                        // the bin was clicked: the picture fades out, then it is taken away
                        property bool removing: false

                        Component.onCompleted: Profile.refresh()

                        Timer {
                            id: removeLater
                            interval: Theme.durSmall + 30
                            onTriggered: Profile.resetPicture()
                        }
                        // looked for again after the picture was taken away (or not)
                        Connections {
                            target: Profile

                            function onRefreshed() {
                                pcard.removing = false;
                            }
                        }

                        function startEdit() {
                            Profile.message = "";
                            nameInput.text = Profile.realName;
                            editing = true;
                            nameInput.forceActiveFocus();
                            nameInput.selectAll();
                        }
                        function save() {
                            if (Profile.busy)
                                return;
                            Profile.setName(nameInput.text);
                            editing = false;
                        }

                        height: Math.max(face.height, info.height) + 2 * inset + (note.visible ? note.height + Theme.px(10) : 0)
                        radius: Theme.px(16)
                        color: Config.hover

                        // the picture, or the first letter of the name (they fade into each other)
                        Item {
                            id: face
                            readonly property bool showsPicture: faceImg.status === Image.Ready && !pcard.removing

                            x: pcard.inset
                            y: pcard.inset
                            width: pcard.faceSize
                            height: width

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Config.selected
                                visible: opacity > 0
                                opacity: face.showsPicture ? 0 : 1
                                antialiasing: true

                                Behavior on opacity {
                                    Anim {
                                        duration: Theme.durSmall
                                    }
                                }

                                Txt {
                                    anchors.centerIn: parent
                                    text: Profile.shownName.charAt(0).toUpperCase()
                                    font.pixelSize: Math.round(parent.width * 0.42)
                                    font.weight: Font.DemiBold
                                }
                            }

                            ClippingRectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                visible: opacity > 0
                                opacity: face.showsPicture ? 1 : 0

                                Behavior on opacity {
                                    Anim {
                                        duration: Theme.durSmall
                                    }
                                }

                                Image {
                                    id: faceImg
                                    anchors.fill: parent
                                    source: Profile.pictureUrl
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: Math.ceil(pcard.faceSize * 2)
                                    sourceSize.height: Math.ceil(pcard.faceSize * 2)
                                    asynchronous: true
                                    smooth: true
                                    mipmap: true
                                }
                            }

                            // only to know the pointer is on it (a click does nothing: Change picture)
                            MouseArea {
                                id: faceArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            // a picture is set: a red bin on a dark circle in its corner while the
                            // pointer is on it, like a wallpaper you added - a click takes it away
                            Rectangle {
                                id: faceBin
                                readonly property bool shown: face.showsPicture && !Profile.busy && (faceArea.containsMouse || faceBinArea.containsMouse)

                                anchors.top: parent.top
                                anchors.right: parent.right
                                width: Theme.px(26)
                                height: width
                                radius: width / 2
                                color: Config.frame
                                antialiasing: true
                                visible: opacity > 0
                                opacity: shown ? 1 : 0
                                scale: faceBinArea.pressed ? 0.9 : 1

                                // fades in and out with the pointer
                                Behavior on opacity {
                                    Anim {
                                        duration: Theme.durSmall
                                    }
                                }
                                Behavior on scale {
                                    Anim {
                                        duration: Theme.durFast
                                        curve: Theme.curveSpring
                                    }
                                }

                                // in the exact middle: about 15 px, with the same whole number of
                                // pixels between it and the circle's edge on every side
                                Icon {
                                    readonly property int room: Math.floor((faceBin.width - Theme.px(15)) / 2)
                                    x: room
                                    y: room
                                    name: "bin"
                                    size: faceBin.width - 2 * room
                                    color: Config.warning
                                }

                                MouseArea {
                                    id: faceBinArea
                                    anchors.fill: parent
                                    enabled: faceBin.shown
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Profile.message = "";
                                        pcard.removing = true;
                                        removeLater.restart();
                                    }
                                }
                            }
                        }

                        // the name and the user name - or, while you change it, the field
                        Column {
                            id: info
                            x: face.x + face.width + Theme.px(16)
                            y: face.y + Math.round((face.height - height) / 2)
                            width: Math.max(0, buttons.x - Theme.px(16) - x)
                            spacing: Theme.px(4)

                            Txt {
                                visible: !pcard.editing
                                width: parent.width
                                elide: Text.ElideRight
                                text: Profile.shownName
                                font.pixelSize: Theme.px(18)
                                font.weight: Font.DemiBold
                            }

                            Rectangle {
                                visible: pcard.editing
                                width: parent.width
                                height: Theme.px(36)
                                radius: Theme.px(10)
                                color: Config.frame
                                border.width: Theme.border
                                border.color: nameInput.activeFocus ? Config.fieldFocus : Config.frame

                                TextInput {
                                    id: nameInput
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.px(12)
                                    anchors.rightMargin: Theme.px(12)
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Config.text
                                    selectionColor: Config.textSelection
                                    selectedTextColor: Config.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.px(14)
                                    renderType: Text.QtRendering
                                    clip: true
                                    maximumLength: 64
                                    Keys.onReturnPressed: pcard.save()
                                    Keys.onEnterPressed: pcard.save()
                                    Keys.onEscapePressed: pcard.editing = false
                                }

                                Txt {
                                    anchors.fill: nameInput
                                    verticalAlignment: Text.AlignVCenter
                                    visible: nameInput.text.length === 0
                                    text: "Your name"
                                    font.pixelSize: Theme.px(14)
                                    color: Config.textFaint
                                }

                                // the text cursor over the field
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    cursorShape: Qt.IBeamCursor
                                }
                            }

                            Txt {
                                width: parent.width
                                elide: Text.ElideRight
                                text: Profile.busy ? Profile.busyText : (pcard.editing ? "The name on the lock and login screen." : Profile.user)
                                font.pixelSize: Theme.px(13)
                                font.weight: Font.Medium
                                color: Config.textDim
                            }
                        }

                        // Change picture / Change name - Save / Cancel while the name is a field
                        Row {
                            id: buttons
                            x: pcard.width - width - pcard.inset
                            y: face.y + Math.round((face.height - height) / 2)
                            spacing: Theme.px(8)

                            Repeater {
                                model: pcard.editing ? [
                                    {
                                        label: "Cancel",
                                        key: "cancel"
                                    },
                                    {
                                        label: "Save",
                                        key: "save"
                                    }
                                ] : [
                                    {
                                        label: "Change picture",
                                        key: "picture"
                                    },
                                    {
                                        label: "Change name",
                                        key: "name"
                                    }
                                ]

                                Rectangle {
                                    id: pbtn
                                    required property var modelData
                                    // Save is white, like the Wi-Fi password's Join
                                    readonly property bool strong: modelData.key === "save"

                                    width: pbtnLabel.implicitWidth + Theme.px(24)
                                    height: Theme.px(32)
                                    radius: Theme.px(10)
                                    opacity: Profile.busy ? 0.45 : 1
                                    color: strong ? Config.text : (pbtnArea.containsMouse ? Config.buttonHover : Config.selected)
                                    scale: pbtnArea.pressed ? 0.95 : 1

                                    Behavior on color {
                                        CAnim {}
                                    }

                                    Txt {
                                        id: pbtnLabel
                                        anchors.centerIn: parent
                                        text: pbtn.modelData.label
                                        font.pixelSize: Theme.px(13)
                                        font.weight: Font.Medium
                                        color: pbtn.strong ? Config.frame : Config.text
                                    }

                                    MouseArea {
                                        id: pbtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !Profile.busy
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const k = pbtn.modelData.key;
                                            if (k === "picture")
                                                Profile.pickPicture();
                                            else if (k === "name")
                                                pcard.startEdit();
                                            else if (k === "save")
                                                pcard.save();
                                            else
                                                pcard.editing = false;
                                        }
                                    }
                                }
                            }
                        }

                        // how the last change went, when worth saying
                        Txt {
                            id: note
                            visible: Profile.message.length > 0
                            x: pcard.inset
                            y: Math.max(face.y + face.height, info.y + info.height) + Theme.px(10)
                            width: pcard.width - 2 * pcard.inset
                            wrapMode: Text.WordWrap
                            text: Profile.message
                            font.pixelSize: Theme.px(12)
                            font.weight: Font.Medium
                            color: Config.warning
                        }

                        // A picture you picked, cut square in the middle: drawn out of sight
                        // at 512 x 512 and saved from there (a PNG for ~/.face, a JPEG for the
                        // login screen), then handed to Profile.savePicture()
                        Item {
                            id: cropper
                            property string file: ""
                            x: -100000
                            width: 512
                            height: 512

                            Image {
                                id: cropImg
                                anchors.fill: parent
                                source: cropper.file.length > 0 ? "file://" + cropper.file : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 1024
                                sourceSize.height: 1024
                                autoTransform: true         // photos taken on their side
                                asynchronous: true
                                cache: false
                                smooth: true
                                mipmap: true
                                onStatusChanged: {
                                    if (cropper.file.length === 0)
                                        return;
                                    if (status === Image.Ready) {
                                        cropper.save();
                                    } else if (status === Image.Error) {
                                        cropper.file = "";
                                        Profile.message = "Could not read that picture.";
                                    }
                                }
                            }

                            function save() {
                                const dir = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
                                const png = dir + "/frameshell-face.png";
                                const jpg = dir + "/frameshell-face.jpg";
                                const ok = cropImg.grabToImage(result => {
                                    cropper.file = "";
                                    if (result.saveToFile(png) && result.saveToFile(jpg))
                                        Profile.savePicture(png, jpg);
                                    else
                                        Profile.message = "Could not save the picture.";
                                }, Qt.size(512, 512));
                                if (!ok) {
                                    cropper.file = "";
                                    Profile.message = "Could not save the picture.";
                                }
                            }

                            Connections {
                                target: Profile

                                function onPicked(path) {
                                    Profile.message = "";
                                    cropper.file = path;
                                }
                            }
                        }
                    }
                }

                // ── About (System) ───────────────────────────────────────
                // The logo of the system (if its icon is there), then one row each: the
                // operating system, the shell, Hyprland, Quickshell, the kernel, the device's
                // name, the processor, the memory, the graphics and the disk - read when the
                // page opens (scripts/about.sh). A row it found nothing for is left out.
                Component {
                    id: aboutCard

                    DeviceCard {
                        id: acard
                        property var info: ({})
                        property var gpus: []

                        collapsible: false
                        expanded: true
                        title: "About"
                        icon: "info"
                        description: "The system, the shell and the hardware."

                        function read(text) {
                            const info = {};
                            const gpus = [];
                            const lines = (text || "").split("\n");
                            for (let i = 0; i < lines.length; i++) {
                                const parts = lines[i].split("\t");
                                if (parts.length < 2)
                                    continue;
                                if (parts[0] === "gpu")
                                    gpus.push(gpuName(parts[1], parts.length > 2 ? parts[2] : ""));
                                else if (parts[0] === "gpuVendor")
                                    gpus.push(gpuName(vendorOf(parts[1]), ""));
                                else
                                    info[parts[0]] = parts.slice(1).join(" ").trim();
                            }
                            acard.info = info;
                            acard.gpus = gpus;
                        }
                        // the maker without "Corporation" & co. ("NVIDIA", "AMD", "Intel")
                        function shortVendor(v) {
                            if (/nvidia/i.test(v))
                                return "NVIDIA";
                            if (/advanced micro|\bamd\b|\bati\b/i.test(v))
                                return "AMD";
                            if (/intel/i.test(v))
                                return "Intel";
                            return v.replace(/,?\s+(corporation|corp\.?|inc\.?|ltd\.?|co\.?)\b.*$/i, "").trim();
                        }
                        // a PCI vendor id ("0x10de") without lspci
                        function vendorOf(id) {
                            const ids = {
                                "0x10de": "NVIDIA",
                                "0x1002": "AMD",
                                "0x8086": "Intel"
                            };
                            return ids[(id || "").toLowerCase()] || "Unknown";
                        }
                        // "NVIDIA Corporation", "AD104 [GeForce RTX 4070]" -> "NVIDIA GeForce RTX 4070"
                        function gpuName(vendor, device) {
                            const maker = shortVendor(vendor || "");
                            const m = (device || "").match(/\[([^\]]+)\][^\[]*$/);
                            const model = m ? m[1] : (device || "").replace(/\s*\(rev [^)]*\)\s*$/, "");
                            return model.length > 0 ? maker + " " + model : maker + " graphics";
                        }
                        function size(bytes) {
                            const gib = bytes / 1073741824;
                            return gib >= 1024 ? (gib / 1024).toFixed(1) + " TiB" : gib.toFixed(1) + " GiB";
                        }
                        readonly property var rows: {
                            const i = acard.info;
                            const out = [];
                            const add = (label, value) => {
                                if (value && String(value).length > 0)
                                    out.push({
                                        label: label,
                                        value: String(value)
                                    });
                            };
                            add("Operating system", i.os);
                            add("Shell", "Frameshell");
                            // "Hyprland 0.56.2 built from branch ..." -> "Hyprland 0.56.2"
                            const hypr = (i.hyprland || "").match(/Hyprland\s+v?([0-9][^\s,]*)/i);
                            add("Compositor", hypr ? "Hyprland " + hypr[1] : "");
                            // "quickshell 0.3.2, revision ..." -> "0.3.2"
                            const qs = (i.quickshell || "").match(/([0-9]+\.[0-9]+(\.[0-9]+)?)/);
                            add("Quickshell", qs ? qs[1] : "");
                            add("Kernel", i.kernel ? i.kernel + (i.arch ? " (" + i.arch + ")" : "") : "");
                            add("Device name", i.host);
                            if (i.cpu) {
                                const cpu = i.cpu.replace(/\((R|TM)\)/gi, "").replace(/\s+/g, " ").trim();
                                add("Processor", cpu + (i.threads && parseInt(i.threads) > 1 ? " \u00d7 " + i.threads : ""));
                            }
                            if (i.memory && parseInt(i.memory) > 0)
                                add("Memory", size(parseInt(i.memory) * 1024));
                            add("Graphics", acard.gpus.join("\n"));
                            if (i.disk) {
                                const d = i.disk.split(" ");
                                if (d.length >= 2 && parseFloat(d[0]) > 0)
                                    add("Disk", size(parseFloat(d[0])) + ", " + size(parseFloat(d[1])) + " free");
                            }
                            return out;
                        }
                        readonly property string logo: info.logo ? IconPacks.path(info.logo) : ""

                        Process {
                            command: ["bash", Quickshell.shellPath("scripts/about.sh")]
                            running: true
                            stdout: StdioCollector {
                                onStreamFinished: acard.read(text)
                            }
                        }

                        // the system's logo
                        Item {
                            visible: acard.logo.length > 0 && logoImg.status === Image.Ready
                            width: acard.width
                            height: visible ? Theme.px(72) + Theme.px(16) : 0

                            Image {
                                id: logoImg
                                x: Math.round((parent.width - width) / 2)
                                width: Theme.px(72)
                                height: width
                                source: acard.logo
                                sourceSize.width: width * 2
                                sourceSize.height: height * 2
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                mipmap: true
                            }
                        }

                        Repeater {
                            model: acard.rows

                            Item {
                                id: aboutRow
                                required property var modelData
                                required property int index
                                readonly property real inset: Theme.px(16)

                                width: acard.width
                                height: Math.max(rowLabel.height, rowValue.height) + 2 * Theme.px(12)

                                Rectangle {
                                    x: aboutRow.inset
                                    width: parent.width - 2 * aboutRow.inset
                                    height: 1
                                    color: Config.selected
                                }

                                Txt {
                                    id: rowLabel
                                    x: aboutRow.inset
                                    y: Theme.px(12)
                                    width: Math.round(parent.width * 0.32)
                                    text: aboutRow.modelData.label
                                    font.pixelSize: Theme.px(13)
                                    font.weight: Font.Medium
                                    color: Config.textDim
                                }
                                Txt {
                                    id: rowValue
                                    x: rowLabel.x + rowLabel.width + Theme.px(12)
                                    y: Theme.px(12)
                                    width: parent.width - x - aboutRow.inset
                                    horizontalAlignment: Text.AlignRight
                                    wrapMode: Text.Wrap
                                    text: aboutRow.modelData.value
                                    font.pixelSize: Theme.px(13)
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        Item {
                            width: 1
                            height: Theme.px(4)
                        }
                    }
                }

                // ── Wi-Fi ────────────────────────────────────────────────
                // One card like the Devices page's sections: the Wi-Fi icon, what you are
                // connected to (or why there is no Wi-Fi) and the switch; while it is on the
                // card opens with the networks (searched for while this page is open): a
                // cable that is plugged in on top, the one you are on, saved ones, then the
                // others by signal. A click connects (a locked one asks for its password
                // under it: Join or Enter, Esc closes the field) or disconnects the one you
                // are on; Forget on a saved one.
                Component {
                    id: wifiCard

                    DeviceCard {
                        id: wfcard
                        readonly property var w: Net.wifi
                        readonly property bool ready: w !== null && w.running && w.device !== null
                        readonly property bool on: ready && w.enabled && w.hardwareEnabled

                        // look for networks while this page is open
                        Component.onCompleted: Net.scanWifiSettings = true
                        Component.onDestruction: Net.scanWifiSettings = false

                        collapsible: false
                        expanded: on
                        title: "Wi-Fi"
                        icon: "wifi"
                        description: {
                            if (w === null)
                                return "Not available: this Quickshell was built without its network module.";
                            if (!w.running)
                                return "Not available: NetworkManager is not running.";
                            if (w.device === null)
                                return "No Wi-Fi adapter found.";
                            if (!w.hardwareEnabled)
                                return "Off by a switch on the computer (or airplane mode).";
                            if (!w.enabled)
                                return "Off.";
                            return w.current ? "Connected to " + w.current.name + "." : "On - not connected.";
                        }
                        side: Toggle {
                            visible: wfcard.ready
                            enabled: wfcard.ready && wfcard.w.hardwareEnabled
                            width: Theme.px(44)
                            height: Theme.px(26)
                            offColor: Config.iconDim
                            checked: wfcard.on
                            onToggled: on => wfcard.w.setEnabled(on)
                        }

                        Column {
                            id: wfList
                            x: wfcard.inset
                            width: parent.width - 2 * x
                            spacing: Theme.px(8)
                            topPadding: Theme.px(4)
                            bottomPadding: Theme.px(16)

                            // a cable
                            Rectangle {
                                width: wfList.width
                                height: Theme.px(52)
                                radius: Theme.px(12)
                                color: Config.frame
                                visible: wfcard.ready && wfcard.w.wiredConnected

                                Icon {
                                    id: cableIcon
                                    x: Theme.px(14)
                                    y: Math.round((parent.height - height) / 2)
                                    size: Theme.px(20)
                                    name: "ethernet"
                                }
                                Column {
                                    x: cableIcon.x + cableIcon.width + Theme.px(12)
                                    y: Math.round((parent.height - height) / 2)
                                    spacing: Theme.px(2)

                                    Txt {
                                        text: "Cable"
                                        font.pixelSize: Theme.px(14)
                                        font.weight: Font.Medium
                                    }
                                    Txt {
                                        text: "Connected"
                                        font.pixelSize: Theme.px(12)
                                        font.weight: Font.Medium
                                        color: Config.textDim
                                    }
                                }
                            }

                            Repeater {
                                model: wfcard.ready ? wfcard.w.networks : []

                                Column {
                                    id: netItem
                                    required property var modelData
                                    readonly property var net: modelData
                                    readonly property var w: wfcard.w
                                    readonly property bool asking: w.askNet === net
                                    readonly property bool failed: w.errorNet === net && w.errorText.length > 0
                                    readonly property bool locked: w.secured(net) && !net.known

                                    width: wfList.width
                                    spacing: Theme.px(6)

                                    // the password field takes the keyboard when it opens (empty)
                                    onAskingChanged: {
                                        if (asking) {
                                            pass.text = "";
                                            Qt.callLater(() => pass.forceActiveFocus());
                                        } else if (pass.activeFocus) {
                                            ui.forceActiveFocus();
                                        }
                                    }
                                    Component.onCompleted: {
                                        if (asking)
                                            Qt.callLater(() => pass.forceActiveFocus());
                                    }

                                    Rectangle {
                                        id: netRow
                                        width: parent.width
                                        height: Theme.px(52)
                                        radius: Theme.px(12)
                                        color: netArea.containsMouse ? Config.selected : Config.frame

                                        Behavior on color {
                                            CAnim {}
                                        }

                                        MouseArea {
                                            id: netArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: netItem.w.activate(netItem.net)
                                        }

                                        WifiIcon {
                                            id: netIcon
                                            x: Theme.px(14)
                                            y: Math.round((parent.height - height) / 2)
                                            size: Theme.px(20)
                                            level: netItem.w.level(netItem.net.signalStrength)
                                        }

                                        Column {
                                            x: netIcon.x + netIcon.width + Theme.px(12)
                                            y: Math.round((parent.height - height) / 2)
                                            width: Math.max(0, (netForget.visible ? netForget.x : netLock.visible ? netLock.x : parent.width) - x - Theme.px(12))
                                            spacing: Theme.px(2)

                                            Txt {
                                                width: parent.width
                                                text: netItem.net.name
                                                font.pixelSize: Theme.px(14)
                                                font.weight: Font.Medium
                                                elide: Text.ElideRight
                                            }
                                            Txt {
                                                width: parent.width
                                                text: netItem.net.stateChanging ? (netItem.net.connected ? "Disconnecting…" : "Connecting…") : netItem.net.connected ? (netArea.containsMouse ? "Connected - click to disconnect" : "Connected") : netItem.net.known ? "Saved" : netItem.locked ? "Needs a password" : "Open"
                                                font.pixelSize: Theme.px(12)
                                                font.weight: Font.Medium
                                                color: Config.textDim
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // a locked network you have not joined yet
                                        Icon {
                                            id: netLock
                                            visible: netItem.locked && !netForget.visible
                                            x: parent.width - width - Theme.px(16)
                                            y: Math.round((parent.height - height) / 2)
                                            size: Theme.px(14)
                                            name: "lock"
                                            color: Config.textDim
                                        }

                                        // forget a saved one (joining it again asks for its password)
                                        Rectangle {
                                            id: netForget
                                            visible: netItem.net.known && !netItem.net.connected && !netItem.net.stateChanging
                                            x: parent.width - width - Theme.px(10)
                                            y: Math.round((parent.height - height) / 2)
                                            width: netForgetLabel.implicitWidth + Theme.px(24)
                                            height: Theme.px(30)
                                            radius: Theme.px(11)
                                            color: netForgetArea.containsMouse ? Config.buttonHover : Config.selected

                                            Behavior on color {
                                                CAnim {}
                                            }

                                            Txt {
                                                id: netForgetLabel
                                                anchors.centerIn: parent
                                                text: "Forget"
                                                font.pixelSize: Theme.px(13)
                                                font.weight: Font.Medium
                                            }

                                            MouseArea {
                                                id: netForgetArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: netItem.w.forget(netItem.net)
                                            }
                                        }
                                    }

                                    // the password: Join (or Enter) connects, Esc closes the field
                                    Item {
                                        width: parent.width
                                        height: Theme.px(36)
                                        visible: netItem.asking

                                        Rectangle {
                                            id: passField
                                            width: parent.width - joinBtn.width - Theme.px(8)
                                            height: parent.height
                                            radius: Theme.px(10)
                                            color: Config.frame
                                            border.width: Theme.border
                                            border.color: pass.activeFocus ? Config.fieldFocus : Config.frame

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
                                                font.pixelSize: Theme.px(14)
                                                renderType: Text.QtRendering
                                                clip: true
                                                Keys.onReturnPressed: netItem.w.submit(netItem.net, text)
                                                Keys.onEnterPressed: netItem.w.submit(netItem.net, text)
                                                Keys.onEscapePressed: netItem.w.cancelAsk()
                                            }

                                            Txt {
                                                anchors.fill: pass
                                                verticalAlignment: Text.AlignVCenter
                                                visible: pass.text.length === 0
                                                text: "Password"
                                                font.pixelSize: Theme.px(14)
                                                color: Config.textFaint
                                            }
                                        }

                                        // like the island's Join: white once there is a password
                                        Rectangle {
                                            id: joinBtn
                                            x: parent.width - width
                                            width: joinLabel.implicitWidth + Theme.px(28)
                                            height: parent.height
                                            radius: Theme.px(10)
                                            color: pass.text.length > 0 ? Config.text : Config.buttonDisabled
                                            scale: joinArea.pressed ? 0.95 : 1

                                            Behavior on color {
                                                CAnim {}
                                            }

                                            Txt {
                                                id: joinLabel
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
                                        visible: netItem.failed
                                        x: Theme.px(10)
                                        width: parent.width - x
                                        wrapMode: Text.WordWrap
                                        text: netItem.failed ? netItem.w.errorText : ""
                                        font.pixelSize: Theme.px(12)
                                        font.weight: Font.Medium
                                        color: Config.warning
                                    }
                                }
                            }

                            // nothing yet
                            Rectangle {
                                width: wfList.width
                                height: Theme.px(48)
                                radius: Theme.px(12)
                                color: Config.frame
                                visible: wfcard.ready && wfcard.w.networks.length === 0

                                Txt {
                                    anchors.centerIn: parent
                                    text: "Looking for networks…"
                                    font.pixelSize: Theme.px(13)
                                    font.weight: Font.Medium
                                    color: Config.textDim
                                }
                            }
                        }
                    }
                }

                // ── Bluetooth ────────────────────────────────────────────
                // The same for Bluetooth: what is connected and the switch; while it is on
                // the card opens with the devices - connected ones first, then paired ones,
                // then new ones nearby (searched for while this page is open; only ones with
                // a name). A click connects, disconnects or pairs; Forget on a paired one.
                Component {
                    id: btCard

                    DeviceCard {
                        id: bcard
                        readonly property var bt: Net.bt
                        readonly property bool ready: bt !== null && bt.available
                        readonly property bool on: ready && bt.enabled

                        // look for devices while this page is open
                        Component.onCompleted: Net.scanBtSettings = true
                        Component.onDestruction: Net.scanBtSettings = false

                        collapsible: false
                        expanded: on
                        title: "Bluetooth"
                        icon: "bluetooth"
                        description: {
                            if (bt === null)
                                return "Not available: this Quickshell was built without Bluetooth.";
                            if (!bt.available)
                                return "No Bluetooth adapter found.";
                            if (!bt.enabled)
                                return bt.blocked ? "Off (blocked - turning it on unblocks it)." : "Off.";
                            const c = bt.connectedDevices;
                            return c.length > 0 ? "Connected to " + c.map(d => bt.label(d)).join(", ") + "." : "On - nothing connected.";
                        }
                        side: Toggle {
                            visible: bcard.ready
                            enabled: bcard.ready && !bcard.bt.busy
                            width: Theme.px(44)
                            height: Theme.px(26)
                            offColor: Config.iconDim
                            checked: bcard.on
                            onToggled: on => bcard.bt.setEnabled(on)
                        }

                        Column {
                            id: btList
                            x: bcard.inset
                            width: parent.width - 2 * x
                            spacing: Theme.px(8)
                            topPadding: Theme.px(4)
                            bottomPadding: Theme.px(16)

                            Repeater {
                                model: bcard.ready ? bcard.bt.devices : []

                                Rectangle {
                                    id: btRow
                                    required property var modelData
                                    readonly property bool known: bcard.bt.known(modelData)
                                    readonly property bool busy: bcard.bt.busyDevice(modelData)
                                    readonly property bool failed: bcard.bt.errorDev === modelData
                                    readonly property real rowH: Theme.px(52)

                                    width: btList.width
                                    height: rowH + (failed ? btError.height + Theme.px(10) : 0)
                                    radius: Theme.px(12)
                                    color: btArea.containsMouse ? Config.selected : Config.frame

                                    Behavior on color {
                                        CAnim {}
                                    }

                                    MouseArea {
                                        id: btArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: bcard.bt.activate(btRow.modelData)
                                    }

                                    Icon {
                                        id: btIcon
                                        x: Theme.px(14)
                                        y: Math.round((btRow.rowH - height) / 2)
                                        size: Theme.px(20)
                                        name: bcard.bt.glyph(btRow.modelData)
                                        color: btRow.modelData.connected ? Config.text : Config.textDim
                                    }

                                    Column {
                                        id: btTexts
                                        x: btIcon.x + btIcon.width + Theme.px(12)
                                        y: Math.round((btRow.rowH - height) / 2)
                                        width: Math.max(0, (forget.visible ? forget.x : parent.width) - x - Theme.px(12))
                                        spacing: Theme.px(2)

                                        Txt {
                                            width: parent.width
                                            text: bcard.bt.label(btRow.modelData)
                                            font.pixelSize: Theme.px(14)
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }
                                        Txt {
                                            width: parent.width
                                            text: bcard.bt.stateText(btRow.modelData) || (btRow.modelData.connected ? (btArea.containsMouse ? "Connected - click to disconnect" : "Connected") : btRow.known ? "Paired" : "New - click to pair")
                                            font.pixelSize: Theme.px(12)
                                            font.weight: Font.Medium
                                            color: Config.textDim
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // forget a paired device (pairing it again needs it in pairing mode)
                                    Rectangle {
                                        id: forget
                                        visible: btRow.known && !btRow.busy
                                        x: parent.width - width - Theme.px(10)
                                        y: Math.round((btRow.rowH - height) / 2)
                                        width: forgetLabel.implicitWidth + Theme.px(24)
                                        height: Theme.px(30)
                                        radius: Theme.px(11)
                                        color: forgetArea.containsMouse ? Config.buttonHover : Config.selected

                                        Behavior on color {
                                            CAnim {}
                                        }

                                        Txt {
                                            id: forgetLabel
                                            anchors.centerIn: parent
                                            text: "Forget"
                                            font.pixelSize: Theme.px(13)
                                            font.weight: Font.Medium
                                        }

                                        MouseArea {
                                            id: forgetArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: bcard.bt.forget(btRow.modelData)
                                        }
                                    }

                                    // why the last click did not work
                                    Txt {
                                        id: btError
                                        visible: btRow.failed
                                        x: btTexts.x
                                        y: btRow.rowH - Theme.px(4)
                                        width: Math.max(0, parent.width - x - Theme.px(14))
                                        wrapMode: Text.WordWrap
                                        text: bcard.bt.errorText
                                        font.pixelSize: Theme.px(12)
                                        font.weight: Font.Medium
                                        color: Config.warning
                                    }
                                }
                            }

                            // nothing yet
                            Rectangle {
                                width: btList.width
                                height: Theme.px(48)
                                radius: Theme.px(12)
                                color: Config.frame
                                visible: bcard.ready && bcard.bt.devices.length === 0

                                Txt {
                                    anchors.centerIn: parent
                                    text: "Looking for devices…"
                                    font.pixelSize: Theme.px(13)
                                    font.weight: Font.Medium
                                    color: Config.textDim
                                }
                            }
                        }
                    }
                }

                // ── Devices: sound, the keyboard, the mouse, a touchpad ──
                // One card each, closed until you click its heading. Sound: the volume and
                // mute of the device in use, then the devices (a click makes another one
                // the one in use). The keyboard: how a held key repeats, Num Lock. The
                // mouse (with the focus: Focus on cursor, Cursor follows focus), and a
                // touchpad (only when there is one). (Bluetooth has its own page.)
                Component {
                    id: devicesCard

                    Column {
                        id: dev
                        spacing: Theme.px(12)

                        // is there a touchpad? (its card only then)
                        property bool hasTouchpad: false
                        Process {
                            running: true
                            command: ["sh", "-c", "grep -qi touchpad /proc/bus/input/devices"]
                            onExited: (code, status) => dev.hasTouchpad = code === 0
                        }

                        // ── sound ──
                        DeviceCard {
                            width: dev.width
                            title: "Output"
                            volumeIcon: true
                            level: AudioDevices.volume(AudioDevices.output)
                            muted: AudioDevices.output === null || AudioDevices.muted(AudioDevices.output)
                            description: "Where the sound plays. Apps play through the one you pick."

                            SettingRows {
                                width: parent.width
                                lineFirst: true
                                settings: [
                                    {
                                        kind: "slider",
                                        min: 0,
                                        max: 1,
                                        step: 0.01,
                                        percent: true,
                                        name: "Volume",
                                        description: "Of the one in use.",
                                        get: () => AudioDevices.volume(AudioDevices.output),
                                        set: v => AudioDevices.setVolume(AudioDevices.output, v),
                                        when: () => AudioDevices.output !== null
                                    },
                                    {
                                        name: "Mute",
                                        description: "No sound from it until you turn this off again.",
                                        get: () => AudioDevices.muted(AudioDevices.output),
                                        set: on => AudioDevices.setMuted(AudioDevices.output, on),
                                        when: () => AudioDevices.output !== null
                                    }
                                ]
                            }

                            NodeList {
                                nodes: AudioDevices.outputs
                                current: AudioDevices.output
                                empty: "No sound output found"
                                onPicked: node => AudioDevices.pickOutput(node)
                            }
                        }

                        DeviceCard {
                            width: dev.width
                            title: "Input"
                            icon: "mic"
                            description: "The microphone apps record from."

                            SettingRows {
                                width: parent.width
                                lineFirst: true
                                settings: [
                                    {
                                        kind: "slider",
                                        min: 0,
                                        max: 1,
                                        step: 0.01,
                                        percent: true,
                                        name: "Volume",
                                        description: "How loud it records.",
                                        get: () => AudioDevices.volume(AudioDevices.input),
                                        set: v => AudioDevices.setVolume(AudioDevices.input, v),
                                        when: () => AudioDevices.input !== null
                                    },
                                    {
                                        name: "Mute",
                                        description: "Nothing is recorded until you turn this off again.",
                                        get: () => AudioDevices.muted(AudioDevices.input),
                                        set: on => AudioDevices.setMuted(AudioDevices.input, on),
                                        when: () => AudioDevices.input !== null
                                    }
                                ]
                            }

                            NodeList {
                                nodes: AudioDevices.inputs
                                current: AudioDevices.input
                                empty: "No microphone found"
                                onPicked: node => AudioDevices.pickInput(node)
                            }
                        }

                        // ── the keyboard ──
                        DeviceCard {
                            width: dev.width
                            title: "Keyboard"
                            icon: "bt-keyboard"
                            description: "How a held key repeats, and Num Lock."

                            SettingRows {
                                width: parent.width
                                lineFirst: true
                                settings: [
                                    {
                                        key: "repeatDelay",
                                        kind: "slider",
                                        min: 150,
                                        max: 1000,
                                        step: 25,
                                        unit: "ms",
                                        name: "Repeat delay",
                                        description: "How long you hold a key before it starts to repeat."
                                    },
                                    {
                                        key: "repeatRate",
                                        kind: "slider",
                                        min: 10,
                                        max: 60,
                                        step: 1,
                                        unit: "a second",
                                        name: "Repeat rate",
                                        description: "How fast a held key repeats."
                                    },
                                    {
                                        key: "numlock",
                                        owner: "config",
                                        name: "Num Lock",
                                        description: "On when you log in."
                                    }
                                ]
                            }
                        }

                        // ── the mouse ──
                        DeviceCard {
                            width: dev.width
                            title: "Mouse"
                            icon: "bt-mouse"
                            description: "How the pointer moves, the wheel scrolls and the focus follows the pointer."

                            SettingRows {
                                width: parent.width
                                lineFirst: true
                                settings: [
                                    {
                                        key: "mouseSpeed",
                                        kind: "slider",
                                        min: -1,
                                        max: 1,
                                        step: 0.05,
                                        decimals: 2,
                                        name: "Speed",
                                        description: "How far the pointer goes. 0: the mouse's own speed."
                                    },
                                    {
                                        key: "mouseAccel",
                                        owner: "config",
                                        name: "Acceleration",
                                        description: "The pointer goes further the faster you move the mouse."
                                    },
                                    {
                                        key: "mouseScrollSpeed",
                                        kind: "slider",
                                        min: 0.1,
                                        max: 2,
                                        step: 0.1,
                                        decimals: 1,
                                        unit: "×",
                                        name: "Scroll speed",
                                        description: "How far one notch of the wheel scrolls."
                                    },
                                    {
                                        key: "mouseNaturalScroll",
                                        owner: "config",
                                        name: "Natural scrolling",
                                        description: "The page moves the way you turn the wheel, like on a phone."
                                    },
                                    {
                                        key: "focusFollowsMouse",
                                        owner: "config",
                                        name: "Focus on cursor",
                                        description: "The window under the pointer gets the focus as you move over it - no click needed."
                                    },
                                    {
                                        key: "cursorFollowsFocus",
                                        owner: "config",
                                        name: "Cursor follows focus",
                                        description: "When you focus a window with the keys (SUPER + arrow keys), the pointer jumps to it."
                                    }
                                ]
                            }
                        }

                        // ── a touchpad ──
                        DeviceCard {
                            width: dev.width
                            visible: dev.hasTouchpad
                            title: "Touchpad"
                            icon: "bt-laptop"
                            description: "Tapping and scrolling."

                            SettingRows {
                                width: parent.width
                                lineFirst: true
                                settings: [
                                    {
                                        key: "touchpadTap",
                                        owner: "config",
                                        name: "Tap to click",
                                        description: "A tap is a click: one finger left, two right, three middle."
                                    },
                                    {
                                        key: "touchpadNaturalScroll",
                                        owner: "config",
                                        name: "Natural scrolling",
                                        description: "The page moves with your fingers, like on a phone."
                                    },
                                    {
                                        key: "touchpadTyping",
                                        owner: "config",
                                        name: "Off while typing",
                                        description: "Your palm can't move the pointer while you type."
                                    },
                                    {
                                        key: "touchpadScrollSpeed",
                                        kind: "slider",
                                        min: 0.1,
                                        max: 2,
                                        step: 0.1,
                                        decimals: 1,
                                        unit: "×",
                                        name: "Scroll speed",
                                        description: "How far a two-finger swipe scrolls."
                                    }
                                ]
                            }
                        }
                    }
                }

                // ── Dock: the pinned apps ────────────────────────────────
                // Its name and an Add button, then a rounded box per pinned app in the
                // dock's order (top = left): its icon and name, buttons to move it and
                // Unpin. Add opens the apps you have installed under them, with a
                // search field: a click pins one (Enter: the first).
                Component {
                    id: pinnedCard

                    Rectangle {
                        id: pcard
                        property bool adding: false
                        property string query: ""
                        property bool showAll: false
                        readonly property int shortCount: 8

                        // the installed apps that are not pinned, by name (the launcher's search)
                        readonly property var apps: {
                            const list = DesktopEntries.applications.values;
                            const pinned = Apps.pinnedIds;
                            const out = [];
                            for (let i = 0; i < list.length; i++) {
                                const e = list[i];
                                if (e.noDisplay || pinned.indexOf(e.id) >= 0)
                                    continue;
                                out.push({
                                    id: e.id,
                                    name: e.name,
                                    generic: e.genericName,
                                    keywords: e.keywords ? e.keywords.join(";") : "",
                                    comment: e.comment,
                                    exec: e.execString,
                                    entry: e
                                });
                            }
                            return out;
                        }
                        readonly property var results: Search.rank(apps, query, null)

                        onAddingChanged: {
                            showAll = false;
                            pickField.text = "";
                            if (adding)
                                pickField.forceActiveFocus();
                            else if (pickField.activeFocus)
                                ui.forceActiveFocus();
                        }

                        height: pinCol.height
                        radius: ui.cardRadius
                        color: Config.hover

                        Column {
                            id: pinCol
                            width: parent.width

                            readonly property real inset: Theme.px(16)

                            Item {
                                width: parent.width
                                height: Math.max(Theme.px(64), pinHead.height + 2 * Theme.px(14))

                                Column {
                                    id: pinHead
                                    x: pinCol.inset
                                    y: Math.round((parent.height - height) / 2)
                                    width: Math.max(0, addBtn.x - x - pinCol.inset)
                                    spacing: Theme.px(3)

                                    Txt {
                                        width: parent.width
                                        text: "Pinned apps"
                                        font.pixelSize: Theme.px(15)
                                        font.weight: Font.Medium
                                    }
                                    Txt {
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        text: "Always in the dock, before your open apps - a line between them. A click opens the app, or goes to its window when it is open."
                                        font.pixelSize: Theme.px(12)
                                        font.weight: Font.Medium
                                        color: Config.textDim
                                    }
                                }

                                // like the shell's other buttons (Done, Cancel)
                                Rectangle {
                                    id: addBtn
                                    x: parent.width - width - pinCol.inset
                                    y: Math.round((parent.height - height) / 2)
                                    width: addLabel.implicitWidth + Theme.px(28)
                                    height: Theme.px(32)
                                    radius: Theme.px(11)
                                    color: addArea.containsMouse ? Config.buttonHover : Config.selected
                                    scale: addArea.pressed ? 0.97 : 1

                                    Behavior on color {
                                        CAnim {}
                                    }
                                    Behavior on scale {
                                        Anim {
                                            duration: Theme.durFast
                                        }
                                    }

                                    Txt {
                                        id: addLabel
                                        anchors.centerIn: parent
                                        text: pcard.adding ? "Done" : "Add"
                                        font.pixelSize: Theme.px(14)
                                        font.weight: Font.Medium
                                    }

                                    MouseArea {
                                        id: addArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: pcard.adding = !pcard.adding
                                    }
                                }
                            }

                            // the pinned apps, left to right in the dock
                            Column {
                                id: pins
                                x: pinCol.inset
                                width: Math.max(0, parent.width - 2 * pinCol.inset)
                                spacing: Theme.px(8)

                                Repeater {
                                    model: Apps.pinned

                                    Rectangle {
                                        id: pinRow
                                        required property var modelData
                                        required property int index
                                        readonly property var inf: Apps.entryInfo(modelData)
                                        readonly property real pad: Theme.px(12)

                                        width: pins.width
                                        height: Theme.px(52)
                                        radius: Theme.px(12)
                                        color: Config.frame

                                        AppIcon {
                                            id: pinIcon
                                            x: pinRow.pad
                                            y: Math.round((parent.height - height) / 2)
                                            size: Theme.px(28)
                                            source: pinRow.inf.icon
                                            label: pinRow.inf.name
                                        }

                                        Txt {
                                            x: pinIcon.x + pinIcon.width + Theme.px(12)
                                            y: Math.round((parent.height - height) / 2)
                                            width: Math.max(0, pinButtons.x - x - Theme.px(10))
                                            text: pinRow.inf.name
                                            font.pixelSize: Theme.px(15)
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }

                                        Row {
                                            id: pinButtons
                                            x: parent.width - width - Theme.px(10)
                                            y: Math.round((parent.height - height) / 2)
                                            spacing: Theme.px(6)

                                            // up = one place to the left in the dock, down = to the right
                                            Repeater {
                                                model: [-1, 1]

                                                Rectangle {
                                                    id: moveBtn
                                                    required property int modelData
                                                    readonly property bool usable: modelData < 0 ? pinRow.index > 0 : pinRow.index < Apps.pinned.length - 1
                                                    width: Theme.px(32)
                                                    height: width
                                                    radius: width / 2
                                                    color: moveArea.containsMouse && usable ? Config.buttonHover : Config.selected
                                                    opacity: usable ? 1 : 0.35
                                                    scale: moveArea.pressed && usable ? 0.94 : 1
                                                    antialiasing: true

                                                    Behavior on color {
                                                        CAnim {}
                                                    }
                                                    Behavior on scale {
                                                        Anim {
                                                            duration: Theme.durFast
                                                        }
                                                    }

                                                    Icon {
                                                        x: Math.round((parent.width - width) / 2)
                                                        y: Math.round((parent.height - height) / 2)
                                                        size: Theme.px(14)
                                                        // the chevrons turned: < becomes ^, > becomes v
                                                        name: moveBtn.modelData < 0 ? "chev-left" : "chev-right"
                                                        rotation: 90
                                                    }

                                                    MouseArea {
                                                        id: moveArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        enabled: moveBtn.usable
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: Apps.movePin(pinRow.modelData.id, moveBtn.modelData)
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                id: unpinBtn
                                                width: unpinLabel.implicitWidth + Theme.px(24)
                                                height: Theme.px(32)
                                                radius: Theme.px(11)
                                                color: unpinArea.containsMouse ? Config.buttonHover : Config.selected
                                                scale: unpinArea.pressed ? 0.97 : 1

                                                Behavior on color {
                                                    CAnim {}
                                                }
                                                Behavior on scale {
                                                    Anim {
                                                        duration: Theme.durFast
                                                    }
                                                }

                                                Txt {
                                                    id: unpinLabel
                                                    anchors.centerIn: parent
                                                    text: "Unpin"
                                                    font.pixelSize: Theme.px(14)
                                                    font.weight: Font.Medium
                                                }

                                                MouseArea {
                                                    id: unpinArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Apps.unpin(pinRow.modelData.id)
                                                }
                                            }
                                        }
                                    }
                                }

                                // nothing yet
                                Rectangle {
                                    width: pins.width
                                    height: Theme.px(52)
                                    radius: Theme.px(12)
                                    color: Config.frame
                                    visible: Apps.pinned.length === 0

                                    Txt {
                                        anchors.centerIn: parent
                                        text: "No pinned apps yet"
                                        font.pixelSize: Theme.px(13)
                                        font.weight: Font.Medium
                                        color: Config.textDim
                                    }
                                }
                            }

                            // ── Add: the apps you have installed ──
                            Column {
                                id: picker
                                x: pinCol.inset
                                width: Math.max(0, parent.width - 2 * pinCol.inset)
                                spacing: Theme.px(8)
                                visible: pcard.adding

                                Item {
                                    width: 1
                                    height: Theme.px(8)
                                }

                                Txt {
                                    text: "Add an app"
                                    font.pixelSize: Theme.px(15)
                                    font.weight: Font.Medium
                                }

                                // a search field like the sidebar's
                                Rectangle {
                                    width: parent.width
                                    height: Theme.px(36)
                                    radius: Theme.px(10)
                                    color: pickField.activeFocus ? Config.selected : Config.frame

                                    Behavior on color {
                                        CAnim {}
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.IBeamCursor
                                        onClicked: pickField.forceActiveFocus()
                                    }

                                    Icon {
                                        x: Theme.px(12)
                                        y: Math.round((parent.height - height) / 2)
                                        size: Theme.px(14)
                                        name: "search"
                                        color: Config.textDim
                                    }

                                    Txt {
                                        x: pickField.x
                                        y: Math.round((parent.height - height) / 2)
                                        visible: pickField.text.length === 0
                                        text: "Search your apps"
                                        font.pixelSize: Theme.px(14)
                                        font.weight: Font.Medium
                                        color: Config.textDim
                                    }

                                    TextInput {
                                        id: pickField
                                        x: Theme.px(34)
                                        y: Math.round((parent.height - height) / 2)
                                        width: parent.width - x - Theme.px(10)
                                        clip: true
                                        font.family: Theme.font
                                        font.pixelSize: Theme.px(14)
                                        font.weight: Font.Medium
                                        color: Config.text
                                        selectionColor: Config.textSelection
                                        selectedTextColor: Config.text
                                        selectByMouse: true
                                        onTextChanged: {
                                            pcard.query = text;
                                            pcard.showAll = false;
                                        }
                                        Keys.onEscapePressed: pcard.adding = false
                                        Keys.onReturnPressed: {
                                            if (pcard.results.length > 0)
                                                Apps.pin(pcard.results[0].id);
                                        }
                                        Keys.onEnterPressed: {
                                            if (pcard.results.length > 0)
                                                Apps.pin(pcard.results[0].id);
                                        }
                                    }
                                }

                                Repeater {
                                    model: pcard.showAll ? pcard.results : pcard.results.slice(0, pcard.shortCount)

                                    Rectangle {
                                        id: appRow
                                        required property var modelData
                                        readonly property real pad: Theme.px(12)

                                        width: picker.width
                                        height: Theme.px(44)
                                        radius: Theme.px(12)
                                        color: appArea.containsMouse ? Config.selected : Config.frame

                                        Behavior on color {
                                            CAnim {}
                                        }

                                        AppIcon {
                                            id: appIcon
                                            x: appRow.pad
                                            y: Math.round((parent.height - height) / 2)
                                            size: Theme.px(24)
                                            source: IconPacks.path(appRow.modelData.entry.icon)
                                            label: appRow.modelData.name
                                        }

                                        Txt {
                                            x: appIcon.x + appIcon.width + Theme.px(12)
                                            y: Math.round((parent.height - height) / 2)
                                            width: Math.max(0, plus.x - x - Theme.px(10))
                                            text: appRow.modelData.name
                                            font.pixelSize: Theme.px(14)
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }

                                        // a plus: pin it
                                        Item {
                                            id: plus
                                            x: parent.width - width - appRow.pad - Theme.px(2)
                                            y: Math.round((parent.height - height) / 2)
                                            width: Theme.px(14)
                                            height: width
                                            opacity: appArea.containsMouse ? 1 : 0.6

                                            Rectangle {
                                                y: Math.round((parent.height - height) / 2)
                                                width: parent.width
                                                height: Theme.px(2)
                                                radius: height / 2
                                                color: Config.text
                                            }
                                            Rectangle {
                                                x: Math.round((parent.width - width) / 2)
                                                width: Theme.px(2)
                                                height: parent.height
                                                radius: width / 2
                                                color: Config.text
                                            }
                                        }

                                        MouseArea {
                                            id: appArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Apps.pin(appRow.modelData.id)
                                        }
                                    }
                                }

                                // nothing found
                                Rectangle {
                                    width: picker.width
                                    height: Theme.px(44)
                                    radius: Theme.px(12)
                                    color: Config.frame
                                    visible: pcard.results.length === 0

                                    Txt {
                                        anchors.centerIn: parent
                                        text: pcard.apps.length === 0 ? "All your apps are pinned" : "No apps found"
                                        font.pixelSize: Theme.px(13)
                                        font.weight: Font.Medium
                                        color: Config.textDim
                                    }
                                }

                                // more than 8: "Show all" under them (then "Show less"), like the history's
                                Item {
                                    width: parent.width
                                    height: moreBtn.height + Theme.px(4)
                                    visible: pcard.results.length > pcard.shortCount

                                    Rectangle {
                                        id: moreBtn
                                        x: Math.round((parent.width - width) / 2)
                                        y: Theme.px(4)
                                        width: moreLabel.implicitWidth + Theme.px(28)
                                        height: Theme.px(32)
                                        radius: Theme.px(11)
                                        color: moreArea.containsMouse ? Config.buttonHover : Config.selected
                                        scale: moreArea.pressed ? 0.97 : 1

                                        Behavior on color {
                                            CAnim {}
                                        }
                                        Behavior on scale {
                                            Anim {
                                                duration: Theme.durFast
                                            }
                                        }

                                        Txt {
                                            id: moreLabel
                                            anchors.centerIn: parent
                                            text: pcard.showAll ? "Show less" : "Show all " + pcard.results.length
                                            font.pixelSize: Theme.px(14)
                                            font.weight: Font.Medium
                                        }

                                        MouseArea {
                                            id: moreArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: pcard.showAll = !pcard.showAll
                                        }
                                    }
                                }
                            }

                            // the card's edge under the last one
                            Item {
                                width: 1
                                height: pinCol.inset
                            }
                        }
                    }
                }

                // ── Notifications: the history ───────────────────────────
                // Its name and a Clear button, then a rounded box per notification (newest
                // first): the app's icon (or the picture it sent), the app's name and
                // when it came, the text. Only the newest 5 until "Show all" is clicked.
                Component {
                    id: historyCard

                    Rectangle {
                        id: hcard
                        readonly property int shortCount: 5
                        property bool showAll: false        // back to 5 when the page is opened again

                        height: histCol.height
                        radius: ui.cardRadius
                        color: Config.hover

                        Column {
                            id: histCol
                            width: parent.width

                            readonly property real inset: Theme.px(16)

                            Item {
                                width: parent.width
                                height: Math.max(Theme.px(64), histHead.height + 2 * Theme.px(14))

                                Column {
                                    id: histHead
                                    x: histCol.inset
                                    y: Math.round((parent.height - height) / 2)
                                    width: Math.max(0, clearBtn.x - x - histCol.inset)
                                    spacing: Theme.px(3)

                                    Txt {
                                        width: parent.width
                                        text: "History"
                                        font.pixelSize: Theme.px(15)
                                        font.weight: Font.Medium
                                    }
                                    Txt {
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        text: "The last " + Notifs.historyMax + ", newest first - also the ones from Do not disturb."
                                        font.pixelSize: Theme.px(12)
                                        font.weight: Font.Medium
                                        color: Config.textDim
                                    }
                                }

                                // like the shell's other buttons (Done, Cancel)
                                Rectangle {
                                    id: clearBtn
                                    readonly property bool usable: Notifs.history.length > 0
                                    x: parent.width - width - histCol.inset
                                    y: Math.round((parent.height - height) / 2)
                                    width: clearLabel.implicitWidth + Theme.px(28)
                                    height: Theme.px(32)
                                    radius: Theme.px(11)
                                    color: clearArea.containsMouse && usable ? Config.buttonHover : Config.selected
                                    opacity: usable ? 1 : 0.4
                                    scale: clearArea.pressed && usable ? 0.97 : 1

                                    Behavior on color {
                                        CAnim {}
                                    }
                                    Behavior on scale {
                                        Anim {
                                            duration: Theme.durFast
                                        }
                                    }

                                    Txt {
                                        id: clearLabel
                                        anchors.centerIn: parent
                                        text: "Clear"
                                        font.pixelSize: Theme.px(14)
                                        font.weight: Font.Medium
                                    }

                                    MouseArea {
                                        id: clearArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: clearBtn.usable
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Notifs.clearHistory();
                                            hcard.showAll = false;
                                        }
                                    }
                                }
                            }

                            // one rounded box per notification (in the window's colour), a little
                            // apart, as wide as the header above them
                            Column {
                                id: entries
                                x: histCol.inset
                                width: Math.max(0, parent.width - 2 * histCol.inset)
                                spacing: Theme.px(8)

                                Repeater {
                                    model: hcard.showAll ? Notifs.history : Notifs.history.slice(0, hcard.shortCount)

                                    Rectangle {
                                        id: entry
                                        required property var modelData

                                        // like the card: the app's name on top, else the summary
                                        readonly property string head: modelData.appName ? modelData.appName : (modelData.summary || "")
                                        readonly property string text: {
                                            const first = modelData.appName ? (modelData.summary || "") : "";
                                            const rest = modelData.body || "";
                                            return first.length > 0 && rest.length > 0 ? first + "\n" + rest : (first.length > 0 ? first : rest);
                                        }
                                        readonly property string iconSource: IconPacks.path(modelData.icon)
                                        readonly property real iconSize: Theme.px(28)
                                        readonly property real gap: Theme.px(12)
                                        readonly property real pad: Theme.px(12)

                                        width: entries.width
                                        height: Math.max(Theme.px(52), entryText.height + 2 * pad)
                                        radius: Theme.px(12)
                                        color: Config.frame

                                        AppIcon {
                                            x: entry.pad
                                            y: entryText.y + Math.round((entryHead.height - height) / 2)
                                            size: entry.iconSize
                                            source: entry.modelData.image ? entry.modelData.image : entry.iconSource
                                            fallbackSource: entry.modelData.image ? entry.iconSource : ""
                                            label: entry.head
                                        }

                                        Column {
                                            id: entryText
                                            x: entry.pad + entry.iconSize + entry.gap
                                            y: Math.round((parent.height - height) / 2)
                                            width: Math.max(0, parent.width - x - entry.pad)
                                            spacing: Theme.px(3)

                                            Item {
                                                id: entryHead
                                                width: parent.width
                                                height: Math.max(headLabel.height, timeLabel.height)

                                                Txt {
                                                    id: headLabel
                                                    width: Math.max(0, parent.width - timeLabel.width - Theme.px(10))
                                                    text: entry.head
                                                    font.pixelSize: Theme.px(15)
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                }
                                                Txt {
                                                    id: timeLabel
                                                    x: parent.width - width
                                                    y: Math.round((parent.height - height) / 2)
                                                    text: root.when(entry.modelData.time)
                                                    font.pixelSize: Theme.px(12)
                                                    font.weight: Font.Medium
                                                    color: Config.textDim
                                                }
                                            }

                                            Txt {
                                                width: parent.width
                                                visible: entry.text.length > 0
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 3
                                                elide: Text.ElideRight
                                                text: entry.text
                                                font.pixelSize: Theme.px(13)
                                                font.weight: Font.Medium
                                                color: Config.textDim
                                            }
                                        }
                                    }
                                }

                                // nothing yet
                                Rectangle {
                                    width: entries.width
                                    height: Theme.px(52)
                                    radius: Theme.px(12)
                                    color: Config.frame
                                    visible: Notifs.history.length === 0

                                    Txt {
                                        anchors.centerIn: parent
                                        text: "No notifications yet"
                                        font.pixelSize: Theme.px(13)
                                        font.weight: Font.Medium
                                        color: Config.textDim
                                    }
                                }
                            }

                            // more than 5: "Show all" under them (then "Show less"), like Clear
                            Item {
                                width: parent.width
                                height: moreBtn.height + Theme.px(12)
                                visible: Notifs.history.length > hcard.shortCount

                                Rectangle {
                                    id: moreBtn
                                    x: Math.round((parent.width - width) / 2)
                                    y: Theme.px(12)
                                    width: moreLabel.implicitWidth + Theme.px(28)
                                    height: Theme.px(32)
                                    radius: Theme.px(11)
                                    color: moreArea.containsMouse ? Config.buttonHover : Config.selected
                                    scale: moreArea.pressed ? 0.97 : 1

                                    Behavior on color {
                                        CAnim {}
                                    }
                                    Behavior on scale {
                                        Anim {
                                            duration: Theme.durFast
                                        }
                                    }

                                    Txt {
                                        id: moreLabel
                                        anchors.centerIn: parent
                                        text: hcard.showAll ? "Show less" : "Show all"
                                        font.pixelSize: Theme.px(14)
                                        font.weight: Font.Medium
                                    }

                                    MouseArea {
                                        id: moreArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: hcard.showAll = !hcard.showAll
                                    }
                                }
                            }

                            // the card's edge under the last one
                            Item {
                                width: 1
                                height: histCol.inset
                            }
                        }
                    }
                }
            }
        }
    }
}
