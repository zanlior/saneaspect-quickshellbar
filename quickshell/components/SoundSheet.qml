import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    required property var bridge
    readonly property var audio: bridge.state.audio || ({})
    readonly property var output: (audio.outputs || []).find(d => d.name === audio.defaultOutput) || ({volume: 0})
    readonly property var input: (audio.inputs || []).find(d => d.name === audio.defaultInput) || ({volume: 0})
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
    function deviceIcon(device, group) {
        if (group === 'inputs') return 'input';
        const description = (device.name + ' ' + device.label).toLowerCase();
        if (/hdmi|displayport/.test(description)) return 'monitor';
        if (/headphone|headset/.test(description)) return 'headphones';
        return 'sound';
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
                objectName: 'sound-back'
                icon: 'chevron-left'
                implicitWidth: 26; implicitHeight: 26
                onClicked: root.closed()
            }
            Label {
                text: 'Sound'
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
                spacing: 14
                Repeater {
                    model: ['outputs', 'inputs', 'apps']
                    ColumnLayout {
                        required property string modelData
                        readonly property string group: modelData
                        Layout.fillWidth: true
                        spacing: 4
                        Label {
                            text: ({outputs:'Output', inputs:'Input', apps:'Apps'})[group]
                            color: Style.muted
                            font.pixelSize: 12
                            Layout.bottomMargin: 7
                        }
                        Repeater {
                            model: root.audio[group] || []
                            Rectangle {
                                id: device
                                required property var modelData
                                readonly property bool selected: group === 'outputs' ? modelData.name === root.audio.defaultOutput : group === 'inputs' && modelData.name === root.audio.defaultInput
                                objectName: 'audio-' + group + '-' + modelData.id
                                Layout.fillWidth: true
                                implicitHeight: group === 'apps' ? 60 : 41
                                radius: 14
                                color: Style.card
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: group !== 'apps'
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.bridge.send(group === 'outputs' ? 'output' : 'input', device.modelData.name)
                                }
                                RowLayout {
                                    visible: group !== 'apps'
                                    anchors.fill: parent
                                    anchors.leftMargin: 8; anchors.rightMargin: 12
                                    spacing: 12
                                    Rectangle {
                                        Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                        radius: 15
                                        color: device.selected ? Style.accent : Qt.lighter(Style.card, 1.5)
                                        Icon {
                                            anchors.centerIn: parent
                                            width: 16; height: 16
                                            name: root.deviceIcon(device.modelData, group)
                                            color: device.selected ? Style.bg : Style.text
                                        }
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: device.modelData.label
                                        font.pixelSize: 13
                                        font.weight: device.selected ? Font.Medium : Font.Normal
                                    }
                                    Icon {
                                        visible: device.selected
                                        Layout.preferredWidth: 14; Layout.preferredHeight: 14
                                        name: 'check'; color: Style.accent
                                    }
                                }
                                ColumnLayout {
                                    visible: group === 'apps'
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 3
                                    Label { text: device.modelData.label; Layout.fillWidth: true; font.pixelSize: 13 }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Level {
                                            id: appLevel
                                            Layout.fillWidth: true
                                            implicitHeight: 26
                                            icon: 'sound'
                                            value: device.modelData.volume
                                            onMoved: v => root.bridge.send('app-volume', v, device.modelData.id)
                                        }
                                        Label { text: Math.round(appLevel.shownValue) + '%'; color: Style.muted; font.pixelSize: 11 }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            visible: group !== 'apps'
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            spacing: 14
                            Level {
                                id: deviceLevel
                                objectName: 'audio-level-' + group
                                Layout.fillWidth: true
                                implicitHeight: 26
                                enabled: (root.audio[group] || []).length > 0
                                value: group === 'outputs' ? root.output.volume : root.input.volume
                                icon: group === 'outputs' ? 'sound' : 'input'
                                onMoved: v => root.bridge.send(group === 'outputs' ? 'volume' : 'mic', v)
                            }
                            Label {
                                text: Math.round(deviceLevel.shownValue) + '%'
                                color: Style.muted
                                font.pixelSize: 11
                                Layout.preferredWidth: 26
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }
    }
}
