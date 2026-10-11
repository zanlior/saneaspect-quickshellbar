import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    required property var bridge
    property string mode: 'wifi'
    property string passwordSsid: ''
    readonly property var service: bridge.state[mode] || ({})
    readonly property bool busy: (bridge.state.busy || []).includes(mode)
    readonly property bool scanning: (bridge.state.busyCommands || {})[mode] === mode + '-scan'
    readonly property var devices: mode === 'wifi' ? (service.networks || []) : (service.devices || []).slice().sort((a, b) => Number(b.paired) - Number(a.paired))
    readonly property var connectedNetworks: mode === 'wifi' && service.enabled ? devices.filter(network => network.active) : []
    readonly property var nearbyDevices: mode === 'wifi' ? devices.filter(network => !network.active) : devices
    signal closed()
    implicitHeight: Math.min(480, content.implicitHeight + 28)
    radius: 24
    color: Style.panel
    onModeChanged: {
        passwordSsid = ''; password.text = '';
        if (visible) scanOnOpen.restart();
    }
    onVisibleChanged: { if (visible) scanOnOpen.restart(); }
    function startScan() {
        if (visible && service.enabled && !busy) bridge.send(mode + '-scan');
    }
    Timer { id: scanOnOpen; interval: 0; onTriggered: root.startScan() }
    function connectNetwork(ssid, secret) {
        bridge.send('wifi-connect', ssid, secret);
        password.text = '';
        passwordSsid = '';
    }
    component DeviceCard: Rectangle {
        required property var network
        Layout.fillWidth: true
        implicitHeight: 68
        radius: 16
        color: Style.card
        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: 21
                color: network.active || network.connected ? Style.accent : Qt.lighter(Style.card, 1.2)
                Icon {
                    anchors.centerIn: parent
                    name: root.mode
                    width: 18; height: 18
                    color: network.active || network.connected ? Style.bg : Style.text
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    text: network.ssid || network.name
                    Layout.fillWidth: true
                    font.weight: Font.DemiBold
                    font.pixelSize: 13
                }
                Label {
                    text: root.mode === 'wifi' ? (network.active ? 'Connected · ' : '') + (network.security || 'Open') + ' · ' + network.signal + '% signal' : network.connected ? 'Connected' : network.paired ? 'Saved' : 'Not paired'
                    Layout.fillWidth: true
                    color: Style.muted
                    font.pixelSize: 11
                }
            }
            Chip {
                objectName: root.mode === 'wifi' && network.active ? 'wifi-disconnect' : 'device-connect'
                text: root.mode === 'wifi' ? (network.active ? 'Disconnect' : 'Connect') : network.connected ? 'Disconnect' : network.paired ? 'Connect' : 'Pair'
                enabled: !root.busy || root.scanning
                implicitHeight: 34
                radius: 8
                color: Qt.lighter(Style.card, 1.2)
                onClicked: {
                    if (root.mode === 'wifi') {
                        if (network.active) root.bridge.send('wifi-disconnect', network.device);
                        else if (network.security && !network.saved) {
                            root.passwordSsid = network.ssid;
                            password.text = '';
                            password.forceActiveFocus();
                        } else root.connectNetwork(network.ssid);
                    } else root.bridge.send(network.connected ? 'bluetooth-disconnect' : network.paired ? 'bluetooth-connect' : 'bluetooth-pair', network.address);
                }
            }
        }
    }
    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            Chip { objectName: 'connection-back'; icon: 'chevron-left'; onClicked: root.closed() }
            Label {
                text: root.mode === 'wifi' ? 'Wi-Fi' : 'Bluetooth'
                Layout.fillWidth: true
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
            Toggle {
                checked: !!root.service.enabled
                enabled: !root.busy || root.scanning
                onToggled: value => root.bridge.send(root.mode + '-toggle', value)
            }
        }
        Repeater {
            model: root.connectedNetworks
            DeviceCard {
                required property var modelData
                objectName: 'connected-network'
                network: modelData
            }
        }
        RowLayout {
            objectName: 'networks-heading'
            Layout.fillWidth: true
            Label {
                text: root.mode === 'wifi' ? 'Networks' : 'Saved and nearby devices'
                Layout.fillWidth: true
                color: Style.muted
                font.pixelSize: 11
            }
            RowLayout {
                objectName: 'connection-scanning'
                visible: root.scanning
                spacing: 7
                Rectangle {
                    width: 5; height: 5; radius: 2.5
                    color: Style.accent
                    SequentialAnimation on opacity {
                        running: root.scanning && !Style.settings.reduceMotion
                        loops: Animation.Infinite
                        NumberAnimation { to: .35; duration: 650 }
                        NumberAnimation { to: 1; duration: 650 }
                    }
                }
                Label { text: 'Scanning'; color: Style.muted; font.pixelSize: 11 }
            }
            Chip {
                objectName: 'connection-scan'
                visible: !root.scanning
                text: 'Scan'
                enabled: !!root.service.enabled && !root.busy
                implicitHeight: 26
                onClicked: root.startScan()
            }
        }
        Controls.ScrollView {
            id: scroll
            visible: !root.service.enabled || root.nearbyDevices.length > 0 || root.devices.length === 0 || root.passwordSsid !== ''
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(330, rows.implicitHeight)
            contentWidth: availableWidth
            clip: true
            Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AlwaysOff
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
            ColumnLayout {
                id: rows
                width: scroll.availableWidth
                spacing: 6
                Repeater {
                    model: root.service.enabled ? root.nearbyDevices : []
                    DeviceCard {
                        required property var modelData
                        network: modelData
                    }
                }
                Label {
                    visible: !root.service.enabled || root.devices.length === 0
                    text: !root.service.enabled ? (root.mode === 'wifi' ? 'Wi-Fi is off' : 'Bluetooth is off') : root.scanning ? 'Looking for nearby networks…' : 'No devices found. Try scanning again.'
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Style.muted
                    font.pixelSize: 12
                }
                ColumnLayout {
                    visible: root.passwordSsid !== ''
                    Layout.fillWidth: true
                    Label { text: 'Connect to ' + root.passwordSsid; Layout.fillWidth: true }
                    Field {
                        id: password
                        Layout.fillWidth: true
                        placeholderText: 'Network password'
                        echoMode: TextInput.Password
                        onAccepted: root.connectNetwork(root.passwordSsid, text)
                    }
                    RowLayout {
                        Chip { text: 'Cancel'; onClicked: { root.passwordSsid = ''; password.text = ''; } }
                        Chip { text: 'Connect'; active: true; onClicked: root.connectNetwork(root.passwordSsid, password.text) }
                    }
                }
            }
        }
    }
}
