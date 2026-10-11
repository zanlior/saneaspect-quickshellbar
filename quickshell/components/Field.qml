import QtQuick
import QtQuick.Controls
import ".."
TextField {
    id: field
    color: Style.text
    placeholderTextColor: Style.muted
    font.family: Style.uiFont
    font.pixelSize: 14
    selectByMouse: true
    leftPadding: 16; rightPadding: 16
    implicitHeight: 44
    background: Rectangle { color: Style.panel; radius: 16; border.width: field.activeFocus ? 1 : 0; border.color: Style.accent }
}
