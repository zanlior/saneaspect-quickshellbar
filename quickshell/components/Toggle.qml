import QtQuick
import ".."
Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool value)
    implicitWidth: 44; implicitHeight: 24; radius: 12
    color: checked ? Style.accent : Style.card
    Rectangle { x: root.checked ? root.width - width - 3 : 3; y: 3; width: root.height - 6; height: width; radius: width / 2; color: root.checked ? Style.bg : Style.muted; Behavior on x { NumberAnimation { duration: Style.settings.reduceMotion ? 0 : 150 } } }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled(!root.checked) }
    Accessible.role: Accessible.CheckBox; Accessible.name: "Toggle"; Accessible.checked: checked
}
