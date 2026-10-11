import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: root
    required property var bridge
    property string section: 'Bar & Island'
    property string query: ''
    property var undoLayouts: []
    readonly property var sectionIcons: ['app-window', 'clock', 'mosque-crescent', 'palette', 'sparkles', 'search', 'bell', 'sliders-horizontal', 'lock', 'settings']
    property var sections: ['Bar & Island', 'Clock & Date', 'Prayer Times', 'Appearance', 'Motion', 'Launcher', 'Notifications', 'Control Center', 'Lock Screen', 'System']
    property var descriptions: ({
            'Bar & Island': 'Shape and size of the island, the notch, and the Game Mode bar.',
            'Clock & Date': 'Time, date, and the calendar.',
            'Prayer Times': 'Your location and prayer timetable.',
            'Appearance': 'Colours and typography throughout the shell.',
            'Motion': 'How fast the shell animates, or whether it animates at all.',
            'Launcher': 'Size of the app launcher and its result rows.',
            'Notifications': 'How long popups stay up and how much they show.',
            'Control Center': 'Arrange, resize, add and remove the controls.',
            'Lock Screen': 'Lock your session with Hyprlock.',
            'System': 'Desktop integration and wallpaper location.'
        })
    property var fields: ({
            'Bar & Island': [['notch', 'Notch mode', 'bool'], ['barHeight', 'Bar height', 24, 60, 'px'], ['collapsedWidth', 'Collapsed width', 80, 240, 'px'], ['expandedHeight', 'Expanded height', 100, 200, 'px'], ['edgeGap', 'Gap from screen edge', 0, 32, 'px'], ['innerPadding', 'Inner padding', 0, 12, 'px'], ['radius', 'Corner radius', 0, 40, 'px'], ['expandedRadius', 'Corner radius (expanded)', 0, 48, 'px'], ['statusCircle', 'Status circle (battery and Wi-Fi)', 'bool'], ['albumCircle', 'Album art circle while a player is open', 'bool'], ['hoverLift', 'Stage lift on hover', 0, 20, 'px'], ['gameHeight', 'Game mode bar height', 32, 72, 'px'], ['clusterGap', 'Game mode cluster gap', 60, 240, 'px']],
            'Clock & Date': [['clock24', '24-hour clock', 'bool'], ['seconds', 'Show seconds', 'bool'], ['weekMonday', 'Start week on Monday', 'bool'], ['dateFormat', 'Date format', 'text']],
            'Prayer Times': [['prayerApiUrl', 'Prayer API URL ({date} placeholder)', 'text'], ['prayerCity', 'City', 'text'], ['prayerCountry', 'Country', 'text'], ['prayerFajrAzanFolder', 'Fajr MP3 folder', 'text'], ['prayerAzanFolder', 'Other prayers MP3 folder', 'text'], ['prayerAzanFile', 'Fallback MP3 file (other prayers)', 'text'], ['prayerHanafi', 'Hanafi Asr calculation', 'bool'], ['prayerReminders', 'Remind me 15 and 5 minutes before', 'bool'], ['prayerAzan', 'Play azan at prayer time', 'bool'], ['prayerAzanVolume', 'Azan volume', 0, 100, '%']],
            'Appearance': [['fontFamily', 'Interface and clock font', 'text'], ['monoFontFamily', 'Numeric readout font', 'text'], ['fontSize', 'Text size', 11, 20, 'px']],
            'Motion': [['reduceMotion', 'Reduce motion', 'bool'], ['movement', 'Movement (size / position)', 0, 900, 'ms'], ['fade', 'Fades & colour', 0, 700, 'ms'], ['hover', 'Hover response', 0, 400, 'ms'], ['bounce', 'Bounce', 0, 100, '%']],
            'Launcher': [['launcherWidth', 'Width', 360, 1000, 'px'], ['rowHeight', 'Row height', 36, 72, 'px'], ['launcherRows', 'Rows before scrolling', 3, 12, '']],
            'Notifications': [['popupTimeout', 'Popup timeout', 500, 15000, 'ms'], ['urgentTimeout', 'Urgent timeout', 1000, 30000, 'ms'], ['notificationWidth', 'Width', 300, 800, 'px'], ['showBody', 'Show body text', 'bool'], ['historyHeight', 'History height', 100, 500, 'px'], ['osdTimeout', 'On-screen time', 500, 6000, 'ms'], ['osdThickness', 'Level bar thickness', 2, 14, 'px']],
            'Control Center': [['controlColumns', 'Layout columns', 5, 9, '']],
            'Lock Screen': [['lockClockSize', 'Clock size', 36, 120, 'px'], ['lockBlur', 'Background blur', 0, 20, 'px']],
            'System': [['wallpaperFolder', 'Wallpaper folder', 'text'], ['polkitAgent', 'Built-in authentication agent', 'bool']]
        })
    function set(k, v) {
        Style.settings = Object.assign({}, Style.settings, {
            [k]: v
        });
        bridge.send('setting', k, v);
    }
    function layoutChange(order, sizes, heights) {
        undoLayouts = undoLayouts.concat([
            {
                order: Style.settings.controlOrder.slice(),
                sizes: Object.assign({}, Style.settings.controlSizes),
                heights: Object.assign({}, Style.settings.controlHeights)
            }
        ]);
        applyLayout(order, sizes === undefined ? Style.settings.controlSizes : sizes, heights === undefined ? Style.settings.controlHeights : heights);
    }
    function applyLayout(order, sizes, heights) {
        set('controlOrder', order);
        set('controlSizes', sizes);
        set('controlHeights', heights);
    }
    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: Qt.lighter(Style.bg, 1.2)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                SelectorSearch {
                    Layout.fillWidth: true
                    inputObjectName: 'settings-search-input'
                    placeholderText: 'Search Settings'
                    onTextChanged: root.query = text
                }
                Repeater {
                    model: root.sections
                    Rectangle {
                        required property string modelData
                        Layout.fillWidth: true
                        implicitHeight: 44
                        radius: 15
                        visible: !root.query || modelData.toLowerCase().includes(root.query.toLowerCase()) || (root.fields[modelData] || []).some(f => f[1].toLowerCase().includes(root.query.toLowerCase()))
                        color: root.section === modelData ? Style.card : 'transparent'
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: root.section === modelData ? Style.accent : Qt.darker(Style.accent, 3)
                                Icon {
                                    anchors.centerIn: parent
                                    width: 18; height: 18
                                    name: root.sectionIcons[root.sections.indexOf(modelData)]
                                    color: root.section === modelData ? Style.bg : Style.accent
                                }
                            }
                            Label {
                                text: modelData
                                Layout.fillWidth: true
                                font.pixelSize: 13
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.section = modelData
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                }
                Label {
                    text: 'ISLAND / CACHYOS'
                    color: Style.muted
                    font.pixelSize: 10
                    Layout.leftMargin: 10
                }
            }
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                width: parent.width
                spacing: 12
                Rectangle {
                    Layout.fillWidth: true
                    Layout.margins: 20
                    Layout.bottomMargin: 0
                    implicitHeight: 160
                    radius: 20
                    color: Style.panel
                    Column {
                        anchors.centerIn: parent
                        spacing: 14
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 58
                            height: 58
                            radius: 29
                            color: Qt.darker(Style.accent, 3)
                            Icon {
                                anchors.centerIn: parent
                                width: 28; height: 28
                                name: root.sectionIcons[root.sections.indexOf(root.section)]
                                color: Style.accent
                            }
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.section
                            font.pixelSize: 21
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.descriptions[root.section]
                            font.pixelSize: 13
                            color: Style.muted
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    implicitHeight: fieldColumn.implicitHeight + 24
                    radius: 18
                    color: Style.panel
                    ColumnLayout {
                        id: fieldColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 16
                        y: 12
                        spacing: 12
                        Repeater {
                            model: root.fields[root.section] || []
                            ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label {
                                        text: modelData[1]
                                        Layout.fillWidth: true
                                        font.pixelSize: 13
                                    }
                                    Toggle {
                                        visible: modelData[2] === 'bool'
                                        checked: !!Style.settings[modelData[0]]
                                        onToggled: v => root.set(modelData[0], v)
                                    }
                                    Label {
                                        visible: typeof modelData[2] === 'number'
                                        monospace: true
                                        text: Style.settings[modelData[0]] + ' ' + (modelData[4] || '')
                                        color: Style.muted
                                        font.pixelSize: 13
                                    }
                                }
                                Slider {
                                    id: settingSlider
                                    objectName: 'settings-slider-' + modelData[0]
                                    visible: typeof modelData[2] === 'number'
                                    Layout.fillWidth: true
                                    // Custom track/handle geometry needs an explicit control hit area.
                                    implicitHeight: 32
                                    from: typeof modelData[2] === 'number' ? modelData[2] : 0
                                    to: typeof modelData[3] === 'number' ? modelData[3] : 100
                                    stepSize: 1
                                    value: Style.settings[modelData[0]] || 0
                                    onMoved: root.set(modelData[0], Math.round(value))
                                    background: Rectangle {
                                        implicitHeight: 5
                                        x: settingSlider.leftPadding
                                        y: settingSlider.topPadding + settingSlider.availableHeight / 2 - height / 2
                                        width: settingSlider.availableWidth
                                        height: 5
                                        radius: 3
                                        color: Style.card
                                        Rectangle {
                                            width: parent.width * settingSlider.visualPosition
                                            height: parent.height
                                            radius: 3
                                            color: Style.accent
                                        }
                                    }
                                    handle: Rectangle {
                                        implicitWidth: 14
                                        implicitHeight: 14
                                        x: settingSlider.leftPadding + settingSlider.visualPosition * (settingSlider.availableWidth - width)
                                        y: settingSlider.topPadding + settingSlider.availableHeight / 2 - height / 2
                                        width: 14
                                        height: 14
                                        radius: 7
                                        color: Style.text
                                        border.width: 2
                                        border.color: Style.accent
                                    }
                                }
                                Field {
                                    visible: modelData[2] === 'text'
                                    Layout.fillWidth: true
                                    text: String(Style.settings[modelData[0]] || '')
                                    onEditingFinished: root.set(modelData[0], text)
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Style.card
                                    opacity: .65
                                }
                            }
                        }
                        RowLayout {
                            visible: root.section === 'Prayer Times'
                            Layout.fillWidth: true
                            Label { text: 'Calculation method'; Layout.fillWidth: true; font.pixelSize: 13 }
                            Select {
                                Layout.preferredWidth: 240
                                model: ['Dubai', 'Muslim World League', 'Umm al-Qura (Makkah)', 'Egyptian General Authority', 'Karachi', 'North America (ISNA)', 'Gulf Region']
                                property var methodIds: [16, 3, 4, 5, 1, 2, 8]
                                currentIndex: Math.max(0, methodIds.indexOf(Style.settings.prayerMethod))
                                onActivated: root.set('prayerMethod', methodIds[currentIndex])
                            }
                        }
                        Label {
                            visible: root.section === 'Prayer Times'
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: 'Choose your local MP3 folders above. Audio paths start blank. Add recordings to your chosen folders at any time; no upload is needed.'
                            color: Style.muted; font.pixelSize: 12
                        }
                        Flow {
                            visible: root.section === 'Prayer Times'
                            Layout.fillWidth: true
                            spacing: 8
                            Chip { text: 'Test reminder'; icon: 'bell'; onClicked: root.bridge.send('prayer-test-reminder') }
                            Chip { text: 'Test Fajr'; icon: 'play'; enabled: !!(root.bridge.state.prayerAudio || {}).fajrCount; onClicked: root.bridge.send('prayer-test-azan', 'Fajr') }
                            Chip { text: 'Test other prayers'; icon: 'play'; enabled: !!(root.bridge.state.prayerAudio || {}).regularCount; onClicked: root.bridge.send('prayer-test-azan', 'Dhuhr') }
                            Chip { text: 'Stop azan'; icon: 'x'; enabled: !!(root.bridge.state.prayerAudio || {}).playing; onClicked: root.bridge.send('prayer-stop-azan') }
                        }
                        Label {
                            visible: root.section === 'Prayer Times'
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: (root.bridge.state.prayerAudio || {}).error || ((root.bridge.state.prayerAudio || {}).playing ? 'Playing: ' + ((root.bridge.state.prayerAudio || {}).currentFile || '').split('/').pop() : 'Fajr: ' + ((root.bridge.state.prayerAudio || {}).fajrCount || 0) + ' MP3s · Other prayers: ' + ((root.bridge.state.prayerAudio || {}).regularCount || 0) + ' MP3s. ' + (Style.settings.prayerAzan ? 'A random recording is chosen at each prayer time.' : 'Automatic azan playback is off.'))
                            color: Style.muted; font.pixelSize: 12
                        }
                        Label {
                            visible: root.section === 'Prayer Times'
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: 'Set an HTTPS API URL with a {date} placeholder, city and country. The service must return AlAdhan-compatible timetables. Timetables are saved for offline use. Reminders appear 15 and 5 minutes before each prayer, including during Focus mode. Keep Island running for reminders and azan. Shift-click the bar clock or click the date preview to open prayer times.'
                            color: Style.muted; font.pixelSize: 12
                        }
                        Label {
                            visible: root.section === 'Lock Screen'
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: 'The lock button uses Hyprlock with the included clock and password layout. Authentication is handled by the system PAM stack. Clock size and blur apply the next time you lock.'
                            color: Style.muted
                        }
                    }
                }
                Flow {
                    visible: root.section === 'Appearance'
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    spacing: 10
                    Repeater {
                        model: Object.keys(Style.palettes)
                        Rectangle {
                            required property string modelData
                            width: 170
                            height: 90
                            radius: 16
                            color: Style.palettes[modelData][1]
                            border.width: 2
                            border.color: Style.settings.theme === modelData ? Style.accent : Style.card
                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                Repeater {
                                    model: Style.palettes[modelData]
                                    Rectangle {
                                        required property string modelData
                                        width: 13
                                        height: 13
                                        radius: 7
                                        color: modelData
                                    }
                                }
                            }
                            Label {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 9
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData
                                font.pixelSize: 11
                                color: Style.palettes[modelData][3]
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.set('theme', modelData)
                            }
                        }
                    }
                }
                ColumnLayout {
                    visible: root.section === 'Control Center'
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    spacing: 10
                    RowLayout {
                        Chip {
                            text: 'Tidy'
                            onClicked: {
                                root.layoutChange(Style.settings.controlOrder.slice(), {}, {});
                            }
                        }
                        Chip {
                            text: 'Undo'
                            enabled: root.undoLayouts.length > 0
                            onClicked: {
                                let a = root.undoLayouts.slice();
                                const l = a.pop();
                                root.applyLayout(l.order, l.sizes, l.heights);
                                root.undoLayouts = a;
                            }
                        }
                        Chip {
                            text: 'Reset'
                            onClicked: root.layoutChange(['wifi', 'focus', 'lock', 'bluetooth', 'game', 'night', 'sound', 'display', 'notifications'], {}, {})
                        }
                        Label {
                            text: 'Drag to move · corner to resize · right-click for sizes'
                            color: Style.muted
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    ControlCenter {
                        Layout.preferredWidth: 520
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: contentHeight
                        bridge: root.bridge
                        editing: true
                        onLayoutEdited: (order, sizes, heights) => root.layoutChange(order, sizes, heights)
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: ['wifi', 'focus', 'lock', 'bluetooth', 'game', 'night', 'sound', 'display', 'notifications', 'media'].filter(x => Style.settings.controlOrder.indexOf(x) < 0)
                            Chip {
                                required property string modelData
                                text: '+ ' + modelData
                                onClicked: root.layoutChange(Style.settings.controlOrder.concat([modelData]))
                            }
                        }
                    }
                }
                ColumnLayout {
                    visible: root.section === 'System'
                    Layout.fillWidth: true
                    Layout.margins: 20
                    spacing: 12
                    Label {
                        text: 'Service availability'
                        font.pixelSize: 18
                    }
                    Repeater {
                        model: Object.keys(bridge.state.capabilities || {})
                        RowLayout {
                            required property string modelData
                            Layout.fillWidth: true
                            Label {
                                text: modelData
                                Layout.fillWidth: true
                            }
                            Label {
                                text: bridge.state.capabilities[modelData] ? 'Available' : 'Not installed'
                                color: bridge.state.capabilities[modelData] ? Style.accent : Style.muted
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: 'Super+comma or right-click the clock or status circle opens Settings. Middle-click the clock for apps. Escape closes panels. IPC target: island.'
                        color: Style.muted
                    }
                    Chip {
                        text: 'Reset all settings'
                        onClicked: resetDialog.open()
                    }
                }
                Item {
                    Layout.preferredHeight: 20
                }
            }
        }
    }
    Dialog {
        id: resetDialog
        title: 'Reset all Island settings?'
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: bridge.send('reset')
    }
}
