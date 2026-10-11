import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root
    required property var bridge
    spacing: 12
    function focusSearch() { search.text = ''; search.forceActiveFocus(); }
    function copySelected() { if (history.currentItem) bridge.send('clipboard-copy', history.currentItem.modelData.id); }
    Label { text: 'Clipboard history'; font.pixelSize: 20 }
    Field {
        id: search
        objectName: 'clipboard-search'
        Layout.fillWidth: true
        placeholderText: 'Search clipboard…'
        onTextChanged: history.currentIndex = 0
        Keys.onDownPressed: history.currentIndex = Math.min(history.count - 1, history.currentIndex + 1)
        Keys.onUpPressed: history.currentIndex = Math.max(0, history.currentIndex - 1)
        onAccepted: root.copySelected()
    }
    ListView {
        id: history
        objectName: 'clipboard-history'
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6
        clip: true
        model: (root.bridge.state.clipboard || []).filter(entry => entry.text.toLowerCase().includes(search.text.toLowerCase()))
        delegate: Rectangle {
            required property var modelData
            required property int index
            width: ListView.view.width
            height: 54
            radius: 12
            color: ListView.isCurrentItem ? Style.card : Style.panel
            Label {
                anchors.fill: parent
                anchors.margins: 12
                verticalAlignment: Text.AlignVCenter
                textFormat: Text.PlainText
                text: modelData.text
                elide: Text.ElideRight
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: history.currentIndex = index
                onClicked: { history.currentIndex = index; root.copySelected(); }
            }
        }
        Label {
            anchors.centerIn: parent
            visible: history.count === 0
            text: search.text ? 'No matches' : 'Copy something to start your history'
            color: Style.muted
        }
    }
    Label { text: 'Enter to copy · Escape to close'; color: Style.muted; font.pixelSize: 12 }
}
