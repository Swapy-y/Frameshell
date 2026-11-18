import QtQuick
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Txt.qml - Text in the shell font (Theme.font: SF Pro Text, or Inter).
// ═══════════════════════════════════════════════════════════════════════════
Text {
    color: Config.text
    font.family: Theme.font
    font.pixelSize: Theme.fsBody
    font.weight: Font.Normal
    renderType: Text.QtRendering
    elide: Text.ElideNone
    verticalAlignment: Text.AlignVCenter
}
