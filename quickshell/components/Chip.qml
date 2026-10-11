import QtQuick
import ".."
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool active: false
    property string hint: ""
    signal clicked()
    implicitWidth: content.implicitWidth + 28
    implicitHeight: 32
    radius: height / 2
    color: active ? Style.accent : (mouse.containsMouse ? Qt.lighter(Style.card, 1.25) : Style.card)
    opacity: enabled ? 1 : .4
    Behavior on color { ColorAnimation { duration: Style.settings.reduceMotion ? 0 : Style.settings.hover } }
    Row {
        id: content
        anchors.centerIn: parent
        spacing: root.icon && root.text ? 6 : 0
        Icon {
            visible: !!root.icon
            name: root.icon
            width: 16; height: 16
            anchors.verticalCenter: parent.verticalCenter
            color: root.active ? Style.bg : Style.text
        }
        Label { id: label; visible: !!root.text; text: root.text; color: root.active ? Style.bg : Style.text; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    Accessible.role: Accessible.Button
    Accessible.name: text || hint || icon
    Accessible.onPressAction: clicked()
}
