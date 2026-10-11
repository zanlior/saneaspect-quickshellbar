pragma ComponentBehavior: Bound
import QtQuick
import ".."

RoundedPanel {
    id: root
    required property var bridge
    property var snapshot: bridge.state.media || ({})
    property bool menuOpen: visible && enabled
    property var playerOrder: []
    property bool awaitingRefresh: false
    readonly property var players: {
        const available = snapshot.players || [];
        return available.slice().sort((a, b) => {
            const ai = playerOrder.indexOf(a.id);
            const bi = playerOrder.indexOf(b.id);
            return (ai < 0 ? playerOrder.length : ai) - (bi < 0 ? playerOrder.length : bi);
        });
    }
    onMenuOpenChanged: {
        if (menuOpen) beginOpening();
        else finishOpeningRefresh();
    }
    onSnapshotChanged: {
        if (menuOpen && snapshot.id && (!selectedPlayer || (awaitingRefresh && !swipe.pressed && !settling))) {
            openLatest();
            finishOpeningRefresh();
        }
    }
    Component.onCompleted: { if (menuOpen) beginOpening(); }
    function beginOpening() {
        openLatest();
        awaitingRefresh = true;
        openingRefresh.restart();
    }
    function finishOpeningRefresh() {
        awaitingRefresh = false;
        openingRefresh.stop();
    }
    Timer { id: openingRefresh; interval: 1500; onTriggered: root.awaitingRefresh = false }
    function openLatest() {
        cancelSwipe();
        playerOrder = (snapshot.players || []).map(player => player.id);
        selectedPlayer = snapshot.id || playerOrder[0] || '';
    }
    property string selectedPlayer: ''
    readonly property var media: players.find(player => player.id === selectedPlayer) || snapshot
    readonly property int playerIndex: Math.max(0, players.findIndex(player => player.id === media.id))
    readonly property real pageDistance: width + 12
    property real swipeOffset: 0
    property string pendingPlayer: ''
    readonly property bool settling: settle.running
    onPlayersChanged: {
        if (selectedPlayer && !players.some(player => player.id === selectedPlayer)) {
            cancelSwipe();
            selectedPlayer = '';
            if (menuOpen) openLatest();
        }
        if (players.length < 2 || (pendingPlayer && !players.some(player => player.id === pendingPlayer)))
            cancelSwipe();
    }
    function pageMedia(offset) {
        if (offset === 0 || players.length < 2) return media;
        return players[(playerIndex + offset + players.length) % players.length];
    }
    function cancelSwipe() {
        settle.stop();
        pendingPlayer = '';
        swipeOffset = 0;
    }
    function switchPlayer(direction) {
        if (players.length < 2 || settling) return;
        finishOpeningRefresh();
        selectedPlayer = media.id || '';
        pendingPlayer = pageMedia(direction).id;
        settle.to = -direction * pageDistance;
        settle.start();
    }
    function returnToCurrent() {
        pendingPlayer = '';
        settle.to = 0;
        settle.start();
    }
    Keys.onLeftPressed: switchPlayer(-1)
    Keys.onRightPressed: switchPlayer(1)
    antialiasing: true
    radius: 24
    color: Style.panel

    // Keep the gesture surface still while complete pages slide over it.
    // The page controls sit above this surface and retain their own gestures.
    MouseArea {
        id: swipe
        objectName: 'media-swipe'
        anchors.fill: parent
        enabled: root.players.length > 1 && !root.settling
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real startX: 0
        property real startY: 0
        onPressed: mouse => {
            root.finishOpeningRefresh();
            startX = mouse.x;
            startY = mouse.y;
            // Pin the page during playback updates from other players.
            root.selectedPlayer = root.media.id || '';
        }
        onPositionChanged: mouse => {
            if (!pressed) return;
            const dx = mouse.x - startX;
            const dy = mouse.y - startY;
            root.swipeOffset = Math.abs(dx) > Math.abs(dy)
                ? Math.max(-root.pageDistance, Math.min(root.pageDistance, dx)) : 0;
        }
        onReleased: {
            if (Math.abs(root.swipeOffset) >= Math.min(45, root.width * .2))
                root.switchPlayer(root.swipeOffset < 0 ? 1 : -1);
            else
                root.returnToCurrent();
        }
        onCanceled: {
            if (!root.settling) root.returnToCurrent();
        }
    }
    Item {
        id: viewport
        anchors.fill: parent
        clip: true
        Repeater {
            model: 3
            MediaPage {
                required property int index
                readonly property int pageOffset: index - 1
                objectName: pageOffset < 0 ? 'media-page-previous' : pageOffset > 0 ? 'media-page-next' : 'media-page-current'
                x: root.swipeOffset + pageOffset * root.pageDistance
                width: root.width
                height: root.height
                media: root.pageMedia(pageOffset)
                bridge: root.bridge
                interactive: pageOffset === 0
                enabled: interactive && !root.settling
                visible: (pageOffset === 0 || root.players.length > 1) && x < root.width && x + width > 0
            }
        }
    }
    NumberAnimation {
        id: settle
        target: root
        property: 'swipeOffset'
        duration: 420
        easing.type: Easing.OutCubic
        onFinished: {
            if (root.pendingPlayer) root.selectedPlayer = root.pendingPlayer;
            root.pendingPlayer = '';
            root.swipeOffset = 0;
        }
    }
    Item {
        y: root.height - 10
        width: root.width
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
}
