import QtQuick
import ".."

FocusScope {
    id: root
    property alias text: input.text
    property string placeholderText: 'Search themes…'
    property string inputObjectName: 'theme-search-input'
    property bool separator: false
    signal previous()
    signal next()
    signal up()
    signal down()
    signal accepted()
    implicitHeight: 32
    Icon { id: searchIcon; name: 'search'; width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter; color: Style.muted }
    TextInput {
        id: input
        objectName: root.inputObjectName
        anchors.left: searchIcon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 26
        verticalAlignment: TextInput.AlignVCenter
        font.family: Style.uiFont
        font.pixelSize: 14
        color: Style.text
        selectionColor: Style.accent
        selectedTextColor: Style.bg
        selectByMouse: true
        clip: true
        focus: true
        Keys.onLeftPressed: event => { if (!text) root.previous(); else event.accepted = false; }
        Keys.onRightPressed: event => { if (!text) root.next(); else event.accepted = false; }
        onAccepted: root.accepted()
        Keys.onUpPressed: root.up()
        Keys.onDownPressed: root.down()
    }
    Label {
        anchors.fill: input
        text: root.placeholderText
        color: Style.muted
        font.pixelSize: 14
        verticalAlignment: Text.AlignVCenter
        visible: !input.text
    }
    Rectangle {
        visible: root.separator
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Style.text
        opacity: .12
    }
}
