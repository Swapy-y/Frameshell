import QtQuick
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  AppIcon.qml - Application icon (from the icon pack in use: YAMIS, or the one
//  picked in the Settings app, services/IconPacks.qml). When the pack has no
//  icon for the app, a rounded square with the app's first letter is shown
//  instead.
//
//    source          file path / url from IconPacks.path(), may be empty
//    fallbackSource  shown when `source` can't be read (a picture that is gone)
//    label           app name, used for the letter of the fallback tile
//    size            width and height in pixels
//    asynchronous    read the picture in the background (false: at once - the dock,
//                    so a new app's icon is there as it grows in)
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root

    property string source: ""
    property string fallbackSource: ""
    property string label: ""
    property real size: 24
    property color fallbackColor: Config.iconTile
    property real fallbackRadius: size * 0.22
    property bool asynchronous: true

    width: size
    height: size

    onSourceChanged: img.sourceFailed = false

    Image {
        id: img
        property bool sourceFailed: false
        anchors.fill: parent
        source: sourceFailed ? root.fallbackSource : root.source
        onStatusChanged: {
            if (status === Image.Error && !sourceFailed && root.fallbackSource.length > 0)
                sourceFailed = true;
        }
        sourceSize.width: Math.ceil(root.size * 2)
        sourceSize.height: Math.ceil(root.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: root.asynchronous
        smooth: true
        mipmap: true
        visible: status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        radius: root.fallbackRadius
        color: root.fallbackColor
        visible: img.status !== Image.Ready

        Txt {
            anchors.centerIn: parent
            visible: root.size >= Theme.px(20) && root.label.length > 0
            text: root.label.charAt(0).toUpperCase()
            color: Config.frame
            font.pixelSize: root.size * 0.5
            font.weight: Font.DemiBold
        }
    }
}
