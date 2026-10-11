import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root
    required property var bridge
    required property date now
    property bool expanded: false
    readonly property var desktop: bridge.state.desktop || ({active: 1, workspaces: []})
    readonly property var media: bridge.state.media || ({})
    readonly property var wifi: bridge.state.wifi || ({})
    readonly property var connected: (wifi.networks || []).find(n => n.active)
    // The expanded host supplies 16px; the compact host supplies 24px.
    readonly property real sidePadding: expanded ? 22 : 14
    signal openPage(string page)

    Column {
        anchors.left: parent.left
        anchors.leftMargin: root.sidePadding - (root.expanded ? 0 : 12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Row {
            visible: root.expanded
            spacing: 14
            Rectangle {
                width: 5; height: 5; radius: 2.5
                anchors.verticalCenter: parent.verticalCenter
                color: Style.accent; opacity: .4
            }
            Label { text: 'Desktop'; font.pixelSize: 12 }
        }
        Row {
            spacing: 5
            Repeater {
                model: Math.max(5, Math.min(10, root.desktop.active || 1))
                Rectangle {
                    required property int index
                    readonly property bool active: index + 1 === root.desktop.active
                    width: 6; height: active ? 18 : 11
                    y: (18 - height) / 2
                    radius: 3
                    color: Style.accent
                    opacity: active ? 1 : (root.desktop.workspaces || []).includes(index + 1) ? .65 : .3
                    Behavior on height { NumberAnimation { duration: Style.settings.reduceMotion ? 0 : Style.settings.hover } }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -2
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.bridge.send('workspace', index + 1)
                    }
                }
            }
        }
    }
    Row {
        id: clockRow
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.expanded ? 4 : (parent.height - height) / 2
        spacing: 9
        ClockLabel {
            text: Qt.formatDateTime(root.now, Style.settings.clock24 ? (Style.settings.seconds ? 'HH:mm:ss' : 'HH:mm') : 'h:mm AP')
            font.pixelSize: root.expanded ? 22 : 15
        }
        Label {
            visible: root.expanded
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(root.now, 'ddd, MMM d')
            font.pixelSize: 12
            color: Style.muted
        }
        MouseArea {
            parent: root
            anchors.fill: clockRow
            enabled: root.expanded
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openPage('prayers')
        }
    }
    Row {
        id: status
        anchors.right: parent.right
        anchors.rightMargin: root.sidePadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9
        Row {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 3; height: 4 + index * 3
                    y: 13 - height
                    radius: 1
                    color: Style.accent
                    opacity: root.connected && root.connected.signal >= index * 25 ? 1 : .25
                }
            }
        }
        MouseArea {
            parent: root
            anchors.fill: status
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => root.openPage(m.button === Qt.RightButton ? 'control' : 'wifi')
        }
    }
    Rectangle {
        visible: root.expanded
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        width: Math.min(280, parent.width - 180); height: 54
        radius: 18; color: Style.panel
        RoundedImage {
            x: 9; y: 9; width: 36; height: 36; radius: 10
            source: root.media.art || ''
        }
        Icon {
            visible: !root.media.art
            x: 17; y: 17; width: 20; height: 20; name: 'media'; color: Style.accent
        }
        Column {
            x: 56; y: 11; width: parent.width - 70
            spacing: 3
            Label { width: parent.width; text: root.media.title || 'No music playing'; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Label { width: parent.width; text: root.media.artist || 'Open music controls'; font.pixelSize: 11; color: Style.muted; elide: Text.ElideRight }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openPage('media')
        }
    }
}
