pragma ComponentBehavior: Bound
import QtQuick
import ".."

RoundedPanel {
    id: root
    required property var bridge
    property var snapshot: bridge.state.media || ({})
    readonly property var players: snapshot.players || []
    property string selectedPlayer: ''
    onPlayersChanged: {
        if (selectedPlayer && !players.some(player => player.id === selectedPlayer))
            selectedPlayer = '';
    }
    readonly property string displayedPlayer: media.id || ''
    onDisplayedPlayerChanged: progress.previewing = false
    readonly property var media: players.find(player => player.id === selectedPlayer) || snapshot
    readonly property int playerIndex: Math.max(0, players.findIndex(player => player.id === media.id))
    property real swipeOffset: 0
    function switchPlayer(direction) {
        if (players.length < 2) return;
        selectedPlayer = players[(playerIndex + direction + players.length) % players.length].id;
    }
    Keys.onLeftPressed: switchPlayer(-1)
    Keys.onRightPressed: switchPlayer(1)
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
    MouseArea {
        id: swipe
        objectName: 'media-swipe'
        anchors.fill: parent
        enabled: root.players.length > 1
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real startX: 0
        property real startY: 0
        property bool switched: false
        onPressed: mouse => { startX = mouse.x; startY = mouse.y; switched = false; }
        onPositionChanged: mouse => {
            if (!pressed || switched) return;
            const distance = mouse.x - startX;
            root.swipeOffset = Math.max(-45, Math.min(45, distance));
            if (Math.abs(distance) >= 45 && Math.abs(distance) > Math.abs(mouse.y - startY)) {
                root.switchPlayer(distance < 0 ? 1 : -1);
                switched = true;
                root.swipeOffset = 0;
            }
        }
        onReleased: root.swipeOffset = 0
        onCanceled: root.swipeOffset = 0
    }
    Item {
        id: content
        x: root.swipeOffset
        width: root.width
        height: root.height
        Behavior on x { enabled: !swipe.pressed || swipe.switched; NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
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
                onMoved: value => root.bridge.send('seek', value, root.media.id || '')
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
    }
    Column {
        x: 14; y: 146; width: 120
        spacing: 5
        visible: root.players.length > 1
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 5
            Repeater {
                model: root.players.length
                Rectangle {
                    required property int index
                    width: 5; height: 5; radius: 2.5
                    color: index === root.playerIndex ? Style.accent : Style.muted
                }
            }
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
            onClicked: root.bridge.send('media', parent.action, root.media.id || '')
        }
        Accessible.role: Accessible.Button
        Accessible.name: action
    }
}
