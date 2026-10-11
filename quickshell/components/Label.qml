import QtQuick
import ".."
Text {
    property bool monospace: false
    color: Style.text
    font.family: monospace ? Style.monoFont : Style.uiFont
    font.pixelSize: Style.settings.fontSize
    textFormat: Text.PlainText
    elide: Text.ElideRight
}
