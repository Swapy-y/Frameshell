import QtQuick
import Quickshell
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  AppRow.qml - One row of the app switcher / app launcher: the app's icon and
//  name. The selected row: a grey card and a white name; the others: a grey
//  name (a faint card under the pointer).
//
//    name, icon   what to show           selected   highlighted by the keyboard
//    faded        a minimized window (the app switcher): its icon and name faded,
//                 like on the dock - also while selected, so you see what you pick
//    detail       smaller text under the name, e.g. the window's title (the app switcher;
//                 none with "Less app switcher info", Config.lessSwitcherInfo); "" = none
//    clicked()    emitted on a mouse click
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    // the frame's colours inside the frame (Overlay.qml), else the theme's (Config.paletteFor)
    readonly property var pal: Config.paletteFor(QsWindow.window)

    property string name: ""
    property string icon: ""
    property bool selected: false
    property bool faded: false
    property real iconSize: Theme.pop(32)
    property real fontSize: Theme.pop(17)
    property string detail: ""                  // smaller text under the name ("" = none)
    property real detailSize: Theme.pop(13)

    signal clicked

    // a quick, small dip while the mouse button is held
    scale: area.pressed ? 0.985 : 1
    Behavior on scale {
        Anim {
            duration: Theme.durFast
            curve: Theme.curveSpring
        }
    }

    // highlight
    Rectangle {
        anchors.fill: parent
        radius: Theme.pop(14)
        color: root.selected ? root.pal.controlBackground : (area.containsMouse ? root.pal.cardBackground : "transparent")

        Behavior on color {
            CAnim {}
        }
    }

    AppIcon {
        id: appIcon
        x: Theme.pop(13)
        y: Math.round((parent.height - height) / 2)
        size: root.iconSize
        source: root.icon
        label: root.name
        fallbackRadius: Theme.pop(8)
        opacity: root.faded ? 0.4 : 1           // (the dock's minimized windows: 0.4 too)
    }

    // the name, and the detail (if any) under it: the two centred together
    readonly property bool hasDetail: detail.length > 0
    readonly property real textGap: Theme.pop(1)
    readonly property real textBlockH: nameText.height + (hasDetail ? textGap + detailText.height : 0)

    Txt {
        id: nameText
        x: appIcon.x + appIcon.width + Theme.pop(16)
        y: Math.round((parent.height - root.textBlockH) / 2)
        width: parent.width - x - Theme.pop(16)
        text: root.name
        font.pixelSize: root.fontSize
        font.weight: Font.Medium
        color: root.selected ? Config.text : root.pal.textSecondary
        opacity: root.faded ? 0.4 : 1
        elide: Text.ElideRight

        Behavior on color {
            CAnim {}
        }
    }

    Txt {
        id: detailText
        visible: root.hasDetail
        x: nameText.x
        y: nameText.y + nameText.height + root.textGap
        width: nameText.width
        text: root.detail
        font.pixelSize: root.detailSize
        font.weight: Font.Normal
        color: root.pal.textSecondary
        opacity: (root.faded ? 0.4 : 1) * (root.selected ? 0.9 : 0.7)
        elide: Text.ElideRight
        maximumLineCount: 1
        textFormat: Text.PlainText
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
