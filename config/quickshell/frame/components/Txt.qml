import QtQuick
import qs

// ═══════════════════════════════════════════════════════════════════════════
//  Txt.qml - Text in the shell font (Clarity City).
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
