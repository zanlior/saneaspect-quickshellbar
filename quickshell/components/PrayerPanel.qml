pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../PrayerTimes.js" as Prayers

Item {
    id: root
    required property var bridge
    property date now: new Date()
    readonly property var timetable: bridge.state.prayers || ({})
    readonly property real epoch: now.getTime() / 1000
    readonly property var selected: Prayers.selection(timetable, epoch)
    readonly property var nextPrayer: selected.next
    readonly property var remaining: Prayers.countdown(nextPrayer ? nextPrayer.epoch - epoch : 0)
    readonly property int nextIndex: selected.cards.findIndex(p => nextPrayer && p.epoch === nextPrayer.epoch)
    readonly property var orbitCards: {
        const index = Math.max(0, nextIndex);
        const ordered = selected.cards.slice(index).concat(selected.cards.slice(0, index));
        const cards = ordered.map(p => ({name:p.name, time:p.time, epoch:p.epoch, passed:false}));
        if (selected.previous) {
            const p = selected.previous;
            cards.push({name:p.name, time:p.time, epoch:p.epoch, passed:true});
        }
        return cards;
    }
    readonly property date localNow: new Date(now.getTime() + ((timetable.utcOffset === undefined ? 240 : timetable.utcOffset) + now.getTimezoneOffset()) * 60000)
    readonly property real fit: Math.min(width / 900, height / 390)
    property real orbitPhase: 0
    NumberAnimation on orbitPhase {
        from: 0; to: Math.PI * 2; duration: 24000; loops: Animation.Infinite
        running: root.visible && !Style.settings.reduceMotion
    }
    signal settingsRequested()

    function prayerIcon(name) {
        return ({Fajr:'prayer-dawn', Dhuhr:'sun', Asr:'prayer-afternoon', Maghrib:'prayer-sunset', Isha:'prayer-night'})[name] || 'clock';
    }

    Item {
        id: scene
        width: 900; height: 390
        anchors.centerIn: parent
        scale: root.fit

        Item {
            id: hub
            x: 308; y: 192
            width: 0; height: 0
            Canvas {
                id: orbit
                x: -282; y: -134; width: 564; height: 268
                opacity: .28
                onPaint: {
                    const ctx = getContext('2d');
                    ctx.clearRect(0, 0, width, height);
                    ctx.beginPath();
                    for (let angle = 0; angle <= Math.PI * 2 + .05; angle += .05) {
                        const x = width / 2 + Math.cos(angle) * 255;
                        const y = height / 2 + Math.sin(angle) * 111;
                        if (!angle) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    }
                    ctx.strokeStyle = Style.muted;
                    ctx.lineWidth = 1.4;
                    ctx.setLineDash([4, 12]);
                    ctx.stroke();
                }
                Connections { target: Style; function onColorsChanged() { orbit.requestPaint(); } }
            }

            Column {
                x: -190; y: -49; width: 380
                spacing: 9
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 3
                    ClockLabel {
                        objectName: 'prayer-center-clock'
                        text: Qt.formatDateTime(root.localNow, Style.settings.clock24 ? 'HH:mm' : 'h:mm')
                        font.family: Style.monoFont
                        font.pixelSize: 62; font.weight: Font.Bold
                    }
                    Label {
                        // Keep the smaller seconds aligned to the bottom of the clock.
                        y: 35
                        text: Qt.formatDateTime(root.localNow, ':ss')
                        monospace: true
                        font.pixelSize: 25; font.weight: Font.DemiBold
                        color: Style.muted
                    }
                    Label {
                        visible: !Style.settings.clock24
                        y: 41
                        text: Qt.formatDateTime(root.localNow, 'AP')
                        font.pixelSize: 14; color: Style.muted
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(root.localNow, 'dddd, MMMM d')
                    monospace: true; font.pixelSize: 12
                    color: Style.muted
                }
            }

            Repeater {
                model: root.orbitCards
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    objectName: modelData.passed ? 'prayer-card-previous' : 'prayer-card-' + modelData.name
                    readonly property bool highlighted: !modelData.passed && root.nextPrayer !== null && modelData.epoch === root.nextPrayer.epoch
                    readonly property int relativeIndex: index
                    readonly property real angle: (65 + relativeIndex * 45 + (Style.settings.reduceMotion ? 0 : Math.sin(root.orbitPhase + index) * 2.5)) * Math.PI / 180
                    readonly property real depth: (Math.sin(angle) + 1) / 2
                    width: modelData.passed ? 84 : 72; height: modelData.passed ? 116 : 92; radius: width / 2
                    x: Math.cos(angle) * 255 - width / 2
                    y: Math.sin(angle) * 111 - height / 2
                    scale: highlighted ? 1.14 : modelData.passed ? .92 : .7 + .35 * depth
                    z: Math.sin(angle) * 10
                    opacity: highlighted || modelData.passed ? 1 : .5 + .5 * depth
                    color: highlighted ? Style.accent : hover.hovered ? Qt.lighter(Style.panel, 1.2) : Style.panel
                    border.width: 1
                    border.color: highlighted ? Qt.lighter(Style.accent, 1.08) : Qt.alpha(modelData.passed ? Style.accent : Style.muted, modelData.passed ? .45 : .08)
                    Behavior on x { NumberAnimation { duration: Style.duration; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: Style.duration; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: Style.duration } }
                    Behavior on color { ColorAnimation { duration: Style.duration } }
                    HoverHandler { id: hover }
                    Column {
                        anchors.centerIn: parent
                        spacing: card.modelData.passed ? 4 : 6
                        Label {
                            visible: card.modelData.passed
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: 'PASSED'
                            font.pixelSize: 9; font.weight: Font.DemiBold
                            color: Style.accent
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Prayers.timeLabel(card.modelData.time, Style.settings.clock24)
                            monospace: true; font.pixelSize: Style.settings.clock24 ? 12 : 10; font.weight: Font.DemiBold
                            color: card.highlighted ? Style.bg : Style.muted
                        }
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: root.prayerIcon(card.modelData.name)
                            width: 21; height: 21
                            color: card.highlighted ? Style.bg : Style.text
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.modelData.name
                            font.pixelSize: 12; font.weight: Font.DemiBold
                            color: card.highlighted ? Style.bg : Style.text
                        }
                        Label {
                            objectName: card.modelData.passed ? 'prayer-previous-elapsed' : ''
                            visible: card.modelData.passed
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.modelData.passed ? Prayers.elapsedLabel(root.epoch - card.modelData.epoch) : ''
                            font.pixelSize: 10; color: Style.muted
                        }
                    }
                    Accessible.role: Accessible.StaticText
                    Accessible.name: modelData.name + ' at ' + modelData.time + (highlighted ? ', next prayer' : modelData.passed ? ', passed, ' + Prayers.elapsedLabel(root.epoch - modelData.epoch) : '')
                }
            }
        }

        Column {
            x: 618; y: 38; width: 264
            spacing: 16
            Label {
                objectName: 'prayer-next'
                anchors.right: parent.right
                text: root.nextPrayer ? root.nextPrayer.name.toUpperCase() + ' · ' + Prayers.timeLabel(root.nextPrayer.time, Style.settings.clock24) : 'PRAYER TIMES'
                monospace: true; font.pixelSize: 13; font.weight: Font.DemiBold
            }
            Row {
                anchors.right: parent.right
                spacing: 2
                Label {
                    objectName: 'prayer-countdown'
                    text: root.nextPrayer ? root.remaining.main : '--:--'
                    monospace: true; font.pixelSize: 60; font.weight: Font.Bold
                }
                Label {
                    y: 36
                    text: root.nextPrayer ? ':' + root.remaining.seconds : ''
                    monospace: true; font.pixelSize: 24; color: Style.muted
                }
            }
            Label {
                anchors.right: parent.right
                text: root.nextPrayer ? 'Until ' + root.nextPrayer.name + (root.selected.tomorrow ? ' tomorrow' : '') : 'Fetching your timetable'
                monospace: true; font.pixelSize: 12; color: Style.muted
            }
        }

        Row {
            objectName: 'prayer-hijri-row'
            x: 618; y: 302; width: 264
            spacing: 10
            Icon {
                objectName: 'prayer-hijri-icon'
                name: 'mosque-crescent'
                width: 29; height: 29
                color: Style.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Label {
                objectName: 'prayer-hijri-date'
                anchors.verticalCenter: parent.verticalCenter
                width: 225
                text: root.selected.hijriDate || 'Hijri date unavailable'
                font.pixelSize: 13; font.weight: Font.DemiBold
                fontSizeMode: Text.Fit; minimumPixelSize: 10
            }
        }

        Label {
            x: 618; y: 349; width: 264
            text: root.timetable.message || ''
            font.pixelSize: 11; color: Style.muted
            horizontalAlignment: Text.AlignRight
        }
        Column {
            visible: !root.selected.cards.length
            x: 130; y: 290; width: 356
            spacing: 10
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.timetable.status === 'error' ? 'Waiting for a prayer timetable' : root.timetable.status === 'unconfigured' ? 'Choose your prayer location' : 'Loading prayer times…'
                color: Style.muted; font.pixelSize: 12
            }
            Chip { anchors.horizontalCenter: parent.horizontalCenter; text: 'Prayer settings'; icon: 'settings'; onClicked: root.settingsRequested() }
        }
    }
}
