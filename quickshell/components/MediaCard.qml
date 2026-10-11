import QtQuick
import ".."

RoundedPanel {
    id: root
    required property var bridge
    property var media: bridge.state.media || ({})
    antialiasing: true
    radius: 24
    color: Style.panel
    function timeText(seconds) {
        return Math.floor((seconds || 0) / 60) + ':' + ('0' + Math.floor((seconds || 0) % 60)).slice(-2);
    }
    RoundedImage {
        anchors.fill: parent
        source: root.media.art || ''
        // The panel masks artwork and shading together after compositing.
        radius: 0
        blur: 1
        visible: !!root.media.art && root.visible
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(Style.panel.r, Style.panel.g, Style.panel.b, .58) }
            GradientStop { position: 1; color: Qt.rgba(Style.bg.r, Style.bg.g, Style.bg.b, .88) }
        }
    }
    Rectangle {
        id: cover
        x: 14; y: 14; width: 120; height: 120
        radius: 12
        color: Style.card
        RoundedImage {
            objectName: 'player-artwork'
            anchors.fill: parent
            source: root.media.art || ''
            radius: parent.radius
        }
        Icon { anchors.centerIn: parent; name: 'media'; visible: !root.media.art; width: 36; height: 36 }
    }
    Item {
        id: info
        anchors.left: cover.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        Column {
            width: parent.width
            spacing: 2
            Label { width: parent.width; text: root.media.title || 'Nothing playing'; font.pixelSize: 20; font.weight: Font.DemiBold }
            Label { width: parent.width; text: root.media.artist || 'Open a music or video player'; font.pixelSize: 14; color: Style.muted }
            Label { width: parent.width; text: root.media.album || ''; font.pixelSize: 12; color: Style.muted }
            Label { width: parent.width; text: root.media.player || ''; font.pixelSize: 11; color: Style.muted }
        }
        Level {
            id: progress
            objectName: 'media-progress'
            y: 88
            width: parent.width
            thin: true
            value: root.media.position || 0
            to: Math.max(1, root.media.length || 0)
            enabled: root.media.length > 0
            onMoved: value => root.bridge.send('seek', value)
        }
        Label {
            x: 0; y: 104
            text: root.timeText(progress.shownValue)
            monospace: true; font.pixelSize: 11; color: Style.muted
        }
        Label {
            anchors.right: parent.right
            y: 104
            text: root.timeText(root.media.length)
            monospace: true; font.pixelSize: 11; color: Style.muted
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 12
            TransportButton { action: 'previous'; icon: 'previous' }
            TransportButton { action: 'play-pause'; icon: root.media.playing ? 'pause' : 'play'; highlighted: true }
            TransportButton { action: 'next'; icon: 'next' }
        }
    }
    component TransportButton: Rectangle {
        required property string action
        required property string icon
        property bool highlighted: false
        width: 40; height: 40; radius: 20
        color: Qt.rgba(1, 1, 1, button.pressed ? .22 : button.containsMouse ? .17 : highlighted ? .12 : 0)
        Icon { anchors.centerIn: parent; name: parent.icon; width: 18; height: 18 }
        MouseArea {
            id: button
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.bridge.send('media', parent.action)
        }
        Accessible.role: Accessible.Button
        Accessible.name: action
    }
}
