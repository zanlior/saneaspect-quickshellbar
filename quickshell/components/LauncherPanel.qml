import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root
    required property var bridge
    signal launched()
    spacing: 12
    function focusSearch() { search.text = ''; search.forceActiveFocus(); }
    function launchSelected() {
        const app = apps.model[apps.currentIndex];
        if (app) { app.execute(); root.launched(); }
    }
    function moveSelection(delta) {
        apps.currentIndex = Math.max(0, Math.min(apps.count - 1, apps.currentIndex + delta));
        apps.positionViewAtIndex(apps.currentIndex, ListView.Contain);
    }
    SelectorSearch {
        id: search
        objectName: 'launcher-search'
        inputObjectName: 'launcher-search-input'
        placeholderText: 'Search...'
        separator: true
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        onTextChanged: apps.currentIndex = 0
        onDown: root.moveSelection(1)
        onUp: root.moveSelection(-1)
        onAccepted: root.launchSelected()
    }
    ListView {
        id: apps
        objectName: 'launcher-results'
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: {
            const words = search.text.trim().toLowerCase().split(/\s+/).filter(Boolean);
            return (root.bridge.applications || []).filter(app => {
                const haystack = [app.name, app.genericName, app.comment,
                    (app.keywords || []).join(' ')].join(' ').toLowerCase();
                return words.every(word => haystack.includes(word));
            }).sort((a, b) => a.name.localeCompare(b.name));
        }
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool selected: ListView.isCurrentItem
            width: ListView.view.width
            height: Style.settings.rowHeight
            radius: 8
            color: selected ? Style.card : 'transparent'
            Rectangle {
                x: 1
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: parent.height - 18
                radius: 1.5
                color: Style.accent
                visible: row.selected
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 12
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 10
                    color: Style.panel
                    Image {
                        id: appIcon
                        anchors.centerIn: parent
                        width: 24; height: 24
                        source: root.bridge.iconPath ? root.bridge.iconPath(row.modelData.icon) : ''
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                    Icon {
                        anchors.centerIn: parent
                        name: 'app-window'
                        width: 20; height: 20
                        visible: appIcon.status !== Image.Ready
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        text: row.modelData.name
                        textFormat: Text.PlainText
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }
                    Label {
                        text: row.modelData.comment || row.modelData.genericName || ''
                        textFormat: Text.PlainText
                        color: Style.muted
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: apps.currentIndex = row.index
                onClicked: { apps.currentIndex = row.index; root.launchSelected(); }
            }
        }
        Label {
            anchors.centerIn: parent
            visible: apps.count === 0
            text: search.text.trim() ? 'No applications found' : 'No applications available'
            color: Style.muted
        }
    }
}
