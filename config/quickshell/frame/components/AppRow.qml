import QtQuick
import Quickshell
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  AppRow.qml - One row of the app switcher / app launcher: the app's icon and
//  name. The selected row: a grey card and a white name; the others: a grey
//  name (a faint card under the pointer).
//
//    name, icon   what to show           selected   highlighted by the keyboard
//    clicked()    emitted on a mouse click
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    // the frame's colours inside the frame (Overlay.qml), else the theme's (Config.paletteFor)
    readonly property var pal: Config.paletteFor(QsWindow.window)

    property string name: ""
    property string icon: ""
    property bool selected: false
    property real iconSize: Theme.pop(32)
    property real fontSize: Theme.pop(17)

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
    }

    Txt {
        x: appIcon.x + appIcon.width + Theme.pop(16)
        y: Math.round((parent.height - height) / 2)
        width: parent.width - x - Theme.pop(16)
        text: root.name
        font.pixelSize: root.fontSize
        font.weight: Font.Medium
        color: root.selected ? Config.text : root.pal.textSecondary
        elide: Text.ElideRight

        Behavior on color {
            CAnim {}
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
