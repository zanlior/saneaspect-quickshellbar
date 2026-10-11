import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: root
    required property var bridge
    property bool editing: false
    property string selected: ""
    property var order: Style.settings.controlOrder
    property var sizes: Style.settings.controlSizes
    property var heights: Style.settings.controlHeights || ({})
    readonly property int columns: Style.settings.controlColumns
    readonly property real unit: (grid.width - (columns - 1) * 11) / columns
    readonly property real contentHeight: grid.implicitHeight
    implicitHeight: contentHeight
    signal openPage(string page)
    signal lockRequested()
    signal layoutEdited(var order, var sizes, var heights)
    function span(key) {
        return Math.min(columns, sizes[key] || (['lock', 'night'].includes(key) ? 1 : ['sound', 'display', 'notifications'].includes(key) ? columns : 3));
    }
    function rows(key) {
        return heights[key] || (key === 'notifications' ? Math.ceil(Style.settings.historyHeight / 71) : key === 'media' ? 2 : 1);
    }
    function resize(key, width, height) {
        const s = Object.assign({}, sizes), h = Object.assign({}, heights);
        s[key] = Math.max(1, Math.min(columns, width));
        h[key] = Math.max(1, Math.min(5, height));
        layoutEdited(order.slice(), s, h);
    }
    function remove(key) {
        layoutEdited(order.filter(k => k !== key), Object.assign({}, sizes), Object.assign({}, heights));
    }
    function reorder(from, to) {
        if (from === to) {
            grid.forceLayout();
            return;
        }
        let a = order.slice(), item = a.splice(from, 1)[0];
        a.splice(to, 0, item);
        layoutEdited(a, Object.assign({}, sizes), Object.assign({}, heights));
    }
    Keys.onDeletePressed: if (editing && selected)
        remove(selected)
    Keys.onLeftPressed: if (editing && selected)
        reorder(order.indexOf(selected), Math.max(0, order.indexOf(selected) - 1))
    Keys.onRightPressed: if (editing && selected)
        reorder(order.indexOf(selected), Math.min(order.length - 1, order.indexOf(selected) + 1))
    Keys.onPressed: event => {
        if (editing && selected && (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BracketRight)) {
            resize(selected, span(selected) + (event.key === Qt.Key_BracketRight ? 1 : -1), rows(selected));
            event.accepted = true;
        }
    }
    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        Flow {
            id: grid
            width: parent.width
            spacing: 11
            Repeater {
                id: cards
                model: root.order
                Rectangle {
                    id: card
                    objectName: 'card-' + modelData
                    required property string modelData
                    required property int index
                    readonly property bool slider: ['sound', 'display'].includes(modelData)
                    readonly property bool small: ['lock', 'night'].includes(modelData)
                    readonly property bool history: modelData === 'notifications'
                    readonly property var wifi: root.bridge.state.wifi || ({})
                    readonly property var bt: root.bridge.state.bluetooth || ({})
                    readonly property var media: root.bridge.state.media || ({})
                    readonly property var audio: root.bridge.state.audio || ({})
                    readonly property var output: (audio.outputs || []).find(x => x.name === audio.defaultOutput) || ({
                            volume: 0
                        })
                    readonly property var connected: (wifi.networks || []).find(x => x.active)
                    readonly property bool active: modelData === 'wifi' ? !!wifi.enabled : modelData === 'bluetooth' ? !!bt.enabled : modelData === 'focus' ? Style.settings.focus : modelData === 'game' ? Style.settings.gameMode : modelData === 'night' ? !!root.bridge.state.nightActive : false
                    readonly property string title: ({
                            wifi: 'Wi-Fi',
                            bluetooth: 'Bluetooth',
                            focus: 'Focus',
                            game: 'Game Mode',
                            media: 'Now Playing',
                            lock: 'Lock',
                            night: 'Night Light',
                            sound: 'Sound',
                            display: 'Display',
                            notifications: 'Notifications'
                        })[modelData] || modelData
                    // Flow rounds item positions; fractional spans can push the
                    // last card onto another row as the popup finishes opening.
                    width: Math.floor(root.unit * root.span(modelData) + (root.span(modelData) - 1) * 11)
                    height: root.rows(modelData) * 60 + (root.rows(modelData) - 1) * 11
                    radius: small ? 32 : slider || history || modelData === 'media' ? 22 : 32
                    color: small && active ? Style.accent : Style.panel
                    border.width: root.editing && root.selected === modelData ? 2 : 1
                    border.color: root.editing && root.selected === modelData ? Style.accent : Style.card
                    z: drag.pressed ? 5 : 0
                    opacity: drag.pressed ? .8 : 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        visible: !card.slider && !card.history
                        Rectangle {
                            visible: !card.small
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: 22
                            color: card.active ? Style.accent : Style.card
                            Icon {
                                anchors.centerIn: parent
                                name: card.modelData
                                color: card.active ? Style.bg : Style.text
                            }
                        }
                        ColumnLayout {
                            visible: !card.small
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                text: card.title
                                Layout.fillWidth: true
                                font.weight: Font.DemiBold
                            }
                            Label {
                                Layout.fillWidth: true
                                color: Style.muted
                                font.pixelSize: 11
                                text: card.modelData === 'wifi' ? (card.connected ? card.connected.ssid : 'Disconnected') : card.modelData === 'media' ? (card.media.title || 'Nothing playing') : card.active ? 'On' : 'Off'
                            }
                        }
                        Item {
                            visible: card.small
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Icon {
                                anchors.centerIn: parent
                                name: card.modelData
                                color: card.active ? Style.bg : Style.text
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.editing
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const key = card.modelData;
                            if (key === 'focus') {
                                const v = !Style.settings.focus;
                                Style.settings = Object.assign({}, Style.settings, {
                                    focus: v
                                });
                                root.bridge.send('setting', 'focus', v);
                            } else if (key === 'lock')
                                root.lockRequested();
                            else if (key === 'game')
                                root.bridge.send('game', !Style.settings.gameMode);
                            else if (key === 'night')
                                root.bridge.send('night', !root.bridge.state.nightActive, Style.settings.nightTemperature);
                            else
                                root.openPage(key);
                        }
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4
                        visible: card.slider
                        RowLayout {
                            Label {
                                text: card.title
                                Layout.fillWidth: true
                            }
                            Chip {
                                icon: 'chevron-right'
                                implicitWidth: 24; implicitHeight: 16
                                onClicked: root.openPage(card.modelData)
                            }
                        }
                        Level {
                            id: summaryLevel
                            implicitHeight: 24
                            Layout.fillWidth: true
                            enabled: !root.editing && (card.modelData === 'sound' || ((root.bridge.state.display || {}).brightness >= 0))
                            value: card.modelData === 'sound' ? card.output.volume : Math.max(0, (root.bridge.state.display || {}).brightness || 0)
                            icon: card.modelData
                            onMoved: v => root.bridge.send(card.modelData === 'sound' ? 'volume' : 'brightness', v)
                        }
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 7
                        visible: card.history
                        RowLayout {
                            Label {
                                text: 'Notifications'
                                Layout.fillWidth: true
                                color: Style.muted
                                font.pixelSize: 12
                            }
                            Chip {
                                text: 'Clear all'
                                color: 'transparent'
                                implicitHeight: 20
                                implicitWidth: 52
                                enabled: !root.editing
                                onClicked: root.bridge.clearNotifications()
                            }
                        }
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 7
                            interactive: !root.editing
                            model: root.bridge.notifications
                            delegate: Rectangle {
                                id: note
                                required property var modelData
                                width: ListView.view.width
                                height: noteColumn.implicitHeight + 20
                                radius: 18
                                color: Style.card
                                Rectangle {
                                    x: 12; y: 12
                                    width: 30; height: 30; radius: 15
                                    color: Qt.rgba(Style.accent.r, Style.accent.g, Style.accent.b, .16)
                                    Label {
                                        anchors.centerIn: parent
                                        text: (note.modelData.appName || 'N').charAt(0).toUpperCase()
                                        color: Style.accent
                                        font.pixelSize: 12
                                    }
                                }
                                ColumnLayout {
                                    id: noteColumn
                                    x: 52
                                    y: 10
                                    width: parent.width - 86
                                    spacing: 1
                                    Label {
                                        Layout.fillWidth: true
                                        text: note.modelData.appName
                                        color: Style.muted
                                        font.pixelSize: 11
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: note.modelData.summary
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        visible: Style.settings.showBody
                                        text: note.modelData.body
                                        color: Style.muted
                                        font.pixelSize: 11
                                    }
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 5
                                        Repeater {
                                            model: note.modelData.actions || []
                                            Chip {
                                                required property var modelData
                                                text: modelData.text
                                                enabled: !root.editing
                                                onClicked: modelData.invoke()
                                            }
                                        }
                                    }
                                }
                                Chip {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    icon: 'x'
                                    enabled: !root.editing
                                    onClicked: root.bridge.dismiss(note.modelData)
                                }
                            }
                            Label {
                                anchors.centerIn: parent
                                visible: root.bridge.notifications.length === 0
                                text: Style.settings.focus ? 'Focus is on' : 'All caught up'
                                color: Style.muted
                            }
                        }
                    }
                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        enabled: root.editing
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: card
                        drag.threshold: 8
                        property real startX: 0
                        property real startY: 0
                        onPressed: mouse => {
                            root.selected = card.modelData;
                            root.forceActiveFocus();
                            startX = card.x;
                            startY = card.y;
                            if (mouse.button === Qt.RightButton)
                                sizeMenu.popup();
                        }
                        onReleased: mouse => {
                            if (mouse.button === Qt.RightButton)
                                return;
                            if (Math.abs(card.x - startX) + Math.abs(card.y - startY) < 8) {
                                grid.forceLayout();
                                return;
                            }
                            const cx = card.x + card.width / 2, cy = card.y + card.height / 2;
                            let closest = card.index, distance = Infinity;
                            for (let i = 0; i < cards.count; i++) {
                                if (i === card.index)
                                    continue;
                                let c = cards.itemAt(i), d = Math.pow(cx - c.x - c.width / 2, 2) + Math.pow(cy - c.y - c.height / 2, 2);
                                if (d < distance) {
                                    distance = d;
                                    closest = i;
                                }
                            }
                            root.reorder(card.index, closest);
                        }
                        onCanceled: grid.forceLayout()
                    }
                    Rectangle {
                        visible: root.editing && root.selected === card.modelData
                        width: 22
                        height: 22
                        radius: 11
                        color: '#f36955'
                        x: -3
                        y: -3
                        z: 7
                        Icon {
                            anchors.centerIn: parent
                            width: 14; height: 14
                            name: 'minus'
                            color: 'white'
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.remove(card.modelData)
                        }
                    }
                    Rectangle {
                        visible: root.editing && root.selected === card.modelData
                        width: 24
                        height: 24
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        color: 'transparent'
                        z: 7
                        Icon {
                            anchors.centerIn: parent
                            name: 'arrow-down-right'
                            width: 20; height: 20
                            color: Style.accent
                        }
                        MouseArea {
                            objectName: 'resize-' + card.modelData
                            anchors.fill: parent
                            cursorShape: Qt.SizeFDiagCursor
                            property real startWidth: 0
                            property real startHeight: 0
                            property point origin
                            onPressed: m => {
                                startWidth = card.width;
                                startHeight = card.height;
                                origin = mapToItem(grid, m.x, m.y);
                            }
                            onReleased: m => {
                                const p = mapToItem(grid, m.x, m.y);
                                root.resize(card.modelData, Math.round((startWidth + p.x - origin.x + 11) / (root.unit + 11)), Math.round((startHeight + p.y - origin.y + 11) / 71));
                            }
                        }
                    }
                    Menu {
                        id: sizeMenu
                        Repeater {
                            model: root.columns
                            MenuItem {
                                font.family: Style.uiFont
                                required property int index
                                text: (index + 1) + ' columns'
                                onTriggered: root.resize(card.modelData, index + 1, root.rows(card.modelData))
                            }
                        }
                        MenuSeparator {}
                        Repeater {
                            model: 5
                            MenuItem {
                                font.family: Style.uiFont
                                required property int index
                                text: (index + 1) + ' rows'
                                onTriggered: root.resize(card.modelData, root.span(card.modelData), index + 1)
                            }
                        }
                    }
                }
            }
        }
    }
}
