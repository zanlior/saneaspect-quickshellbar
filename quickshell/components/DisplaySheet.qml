import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    required property var bridge
    property var monitorNames: []
    readonly property var display: bridge.state.display || ({})
    readonly property bool night: !!bridge.state.nightActive
    implicitHeight: content.implicitHeight + 84
    radius: 24
    color: Style.panel
    readonly property real scrollPosition: scroll.contentItem ? scroll.contentItem.contentY : 0
    function scrollBy(distance) {
        const viewport = scroll.contentItem;
        if (!viewport) return;
        viewport.cancelFlick();
        viewport.contentY = Math.max(0, Math.min(Math.max(0, viewport.contentHeight - viewport.height), viewport.contentY + distance));
    }
    signal closed()
    function setTemperature(value) {
        const temperature = Math.round(value);
        Style.settings = Object.assign({}, Style.settings, {nightTemperature: temperature});
        bridge.send('setting', 'nightTemperature', temperature);
        if (night) bridge.send('night', true, temperature);
    }
    function modeText(monitor) {
        return monitor.width + '×' + monitor.height + ' @ ' + Math.round(monitor.refreshRate) + ' Hz';
    }
    MouseArea { anchors.fill: parent }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 22
        spacing: 20
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Chip {
                objectName: 'display-back'
                icon: 'chevron-left'
                implicitWidth: 26; implicitHeight: 26
                onClicked: root.closed()
            }
            Label {
                text: 'Display'
                Layout.fillWidth: true
                font.pixelSize: 17
                font.weight: Font.Medium
            }
        }
        Controls.ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AlwaysOff
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
            ColumnLayout {
                id: content
                width: scroll.availableWidth
                spacing: 10
                Repeater {
                    model: root.monitorNames
                    Rectangle {
                        id: monitorCard
                        required property string modelData
                        readonly property var monitor: (root.display.monitors || []).find(m => m.name === modelData) || ({})
                        objectName: 'monitor-' + modelData
                        Layout.fillWidth: true
                        implicitHeight: 164
                        radius: 18
                        color: Style.card
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 7
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Rectangle {
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                    radius: 15
                                    color: monitorCard.monitor.focused ? Style.accent : Qt.lighter(Style.card, 1.5)
                                    Icon {
                                        anchors.centerIn: parent
                                        width: 16; height: 16
                                        name: 'monitor'
                                        color: monitorCard.monitor.focused ? Style.bg : Style.text
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Label { text: monitorCard.modelData; Layout.fillWidth: true; font.pixelSize: 13; font.weight: Font.Medium }
                                    Label {
                                        text: monitorCard.monitor.width + '×' + monitorCard.monitor.height + ' · ' + Math.round(monitorCard.monitor.refreshRate) + ' Hz · ' + Number(monitorCard.monitor.scale || 1).toFixed(2).replace(/0$/, '') + '×'
                                        Layout.fillWidth: true
                                        font.pixelSize: 11
                                        color: Style.muted
                                    }
                                }
                                Label { text: monitorCard.monitor.focused ? 'focused' : ''; color: Style.accent; font.pixelSize: 11 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                Level {
                                    id: monitorBrightness
                                    objectName: 'brightness-' + monitorCard.modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 26
                                    enabled: monitorCard.monitor.brightness >= 0
                                    value: Math.max(0, monitorCard.monitor.brightness || 0)
                                    icon: 'display'
                                    onMoved: v => root.bridge.send('brightness', v, monitorCard.monitor.name)
                                }
                                Label {
                                    text: monitorCard.monitor.brightness >= 0 ? Math.round(monitorBrightness.shownValue) + '%' : 'Unavailable'
                                    color: Style.muted
                                    font.pixelSize: 11
                                }
                            }
                            RowLayout {
                                spacing: 4
                                Repeater {
                                    model: [1, 1.25, 1.5, 1.75, 2]
                                    Chip {
                                        required property real modelData
                                        objectName: 'scale-' + monitorCard.modelData + '-' + modelData
                                        implicitHeight: 26
                                        implicitWidth: 46
                                        text: modelData.toFixed(2).replace(/0$/, '') + '×'
                                        active: monitorCard.monitor.scale === modelData
                                        color: active ? Style.accent : Qt.lighter(Style.card, 1.16)
                                        onClicked: root.bridge.send('monitor', monitorCard.monitor.name, {
                                            mode: monitorCard.monitor.width + 'x' + monitorCard.monitor.height + '@' + monitorCard.monitor.refreshRate,
                                            scale: modelData
                                        })
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: 'Resolution'; color: Style.muted; font.pixelSize: 11 }
                                Select {
                                    objectName: 'resolution-' + monitorCard.modelData
                                    popupBoundary: root
                                    Layout.fillWidth: true
                                    implicitHeight: 30
                                    model: monitorCard.monitor.availableModes || []
                                    currentIndex: model.findIndex(mode => {
                                        const parts = String(mode).match(/^(\d+)x(\d+)@([\d.]+)/);
                                        return parts && Number(parts[1]) === monitorCard.monitor.width && Number(parts[2]) === monitorCard.monitor.height && Math.abs(Number(parts[3]) - monitorCard.monitor.refreshRate) < .1;
                                    })
                                    displayText: root.modeText(monitorCard.monitor)
                                    background: Item {}
                                    contentItem: Label {
                                        text: root.modeText(monitorCard.monitor)
                                        horizontalAlignment: Text.AlignRight
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 12
                                    }
                                    indicator: Icon {
                                        x: parent.width - width - 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 12; height: 12
                                        name: 'chevron-right'
                                        color: Style.muted
                                    }
                                    onActivated: i => root.bridge.send('monitor', monitorCard.monitor.name, {
                                        mode: model[i], scale: monitorCard.monitor.scale
                                    })
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 90
                    radius: 18
                    color: Style.card
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Rectangle {
                                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                radius: 15
                                color: root.night ? Style.accent : Qt.lighter(Style.card, 1.5)
                                Icon { anchors.centerIn: parent; width: 16; height: 16; name: 'night'; color: root.night ? Style.bg : Style.text }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label { text: 'Night Light'; Layout.fillWidth: true; font.pixelSize: 13; font.weight: Font.Medium }
                                Label { text: Style.settings.nightTemperature + ' K'; Layout.fillWidth: true; font.pixelSize: 11; color: Style.muted }
                            }
                            Toggle {
                                objectName: 'night-toggle'
                                implicitWidth: 42; implicitHeight: 22
                                color: checked ? Style.accent : Qt.lighter(Style.card, 1.5)
                                checked: root.night
                                onToggled: v => root.bridge.send('night', v, Style.settings.nightTemperature)
                            }
                        }
                        Level {
                            objectName: 'night-temperature'
                            Layout.fillWidth: true
                            implicitHeight: 26
                            icon: 'night'
                            from: 2500; to: 6500
                            value: Style.settings.nightTemperature
                            onMoved: v => root.setTemperature(v)
                        }
                    }
                }
                RowLayout {
                    visible: !!root.bridge.state.monitorConfirm
                    Layout.fillWidth: true
                    Label { text: 'Keep display changes? Reverting in 15 seconds.'; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 12 }
                    Chip { text: 'Keep'; active: true; onClicked: root.bridge.send('monitor-keep') }
                    Chip { text: 'Revert'; onClicked: root.bridge.send('monitor-revert') }
                }
            }
        }
    }
}
