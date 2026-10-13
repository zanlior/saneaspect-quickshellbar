import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "components"

Item {
    id: root
    required property var bridge
    property string page: ""
    property string visualPage: ""
    property real closingContentWidth: 0
    property real closingContentHeight: 0
    property string pendingPage: ""
    property bool switchingPanels: false
    readonly property bool geometryAnimating: sideRevealAnimation.running || mediaRevealAnimation.running || mainWidthAnimation.running || mainHeightAnimation.running
    property bool stageHovered: false
    readonly property bool workspaceTheme: Style.settings.barTheme === 'workspace'
    // Space between the center dock and its floating music and Wi-Fi circles.
    readonly property real dockCircleGap: 20
    // Extra space on each side of the Dock theme only when attached as a notch.
    readonly property real dockNotchSidePadding: 16
    readonly property real collapsedBarWidth: !Style.settings.notch || Style.settings.gameMode ? Style.settings.collapsedWidth : workspaceTheme ? Math.max(240, Style.settings.collapsedWidth) : Style.settings.collapsedWidth + dockNotchSidePadding * 2
    readonly property bool notchHovered: Style.settings.notch && !Style.settings.gameMode && stageHovered && !expanded && visualPage === '' && !bridge.toast && !osd
    onStageHoveredChanged: {
        if (Style.settings.notch && !expanded && visualPage === '' && !bridge.toast && !osd) {
            for (const animation of [mainWidthAnimation, mainHeightAnimation]) {
                animation.duration = Style.settings.reduceMotion ? 0 : Style.settings.hover;
                animation.easing.bezierCurve = Style.settleCurve;
            }
        }
    }
    property string osd: ""
    property real osdValue: 0
    property real lastVolume: -1
    property real lastBrightness: -1
    property var monitorNames: []
    readonly property bool night: !!bridge.state.nightActive
    property int monthOffset: 0
    property string powerConfirm: ""
    property int powerIndex: 0
    readonly property var powerActions: [['lock', 'Lock', 'lock'], ['suspend', 'Suspend', 'suspend'], ['logout', 'Log Out', 'logout'], ['reboot', 'Reboot', 'reboot'], ['poweroff', 'Power Off', 'poweroff']]
    property var pairing: bridge.state.pairing || null
    readonly property string appliedWallpaper: bridge.state.wallpaperSelected || ''
    onAppliedWallpaperChanged: {
        if (page === 'wallpapers') Qt.callLater(() => {
            if (root.page === 'wallpapers' && carousel.model.includes(root.appliedWallpaper))
                carousel.currentIndex = carousel.model.indexOf(root.appliedWallpaper);
        });
    }
    onPairingChanged: {
        if (pairing)
            page = 'pairing';
        else if (page === 'pairing')
            page = 'bluetooth';
    }
    property var media: bridge.state.media || ({})
    property var wifi: bridge.state.wifi || ({
            networks: []
        })
    property var bt: bridge.state.bluetooth || ({
            devices: []
        })
    property var audio: bridge.state.audio || ({
            outputs: [],
            inputs: [],
            apps: []
        })
    property var display: bridge.state.display || ({
            monitors: [],
            brightness: -1
        })
    property var currentOutput: (audio.outputs || []).find(x => x.name === audio.defaultOutput) || ({
            volume: 0
        })
    property var currentInput: (audio.inputs || []).find(x => x.name === audio.defaultInput) || ({
            volume: 0
        })
    property var connected: (wifi.networks || []).find(x => x.active)
    property date now: new Date()
    readonly property bool expanded: page !== ""
    readonly property bool connectionOverlay: page === "wifi" || page === "bluetooth"
    readonly property bool detailOverlay: page === "sound" || page === "display"
    readonly property bool visualDetailOverlay: visualPage === "sound" || visualPage === "display"
    readonly property bool visualConnectionOverlay: visualPage === "wifi" || visualPage === "bluetooth"
    // The notch body starts inside the curved shoulders on both sides.
    readonly property real notchMenuSidePadding: Style.settings.notch && !Style.settings.gameMode ? 12 : 0
    readonly property int panelWidth: page === "glance" ? (workspaceTheme ? 670 : 272) : page === "prayers" ? Math.min(960, root.width - 24) : page === "calendar" ? 360 : page === "media" ? 412 : page === "bars" ? 470 : page === "themes" || page === "wallpapers" ? 860 : page === "launcher" ? Style.settings.launcherWidth : ["control", "wifi", "bluetooth", "sound", "display"].includes(page) ? 514 : 550
    readonly property int panelHeight: page === "glance" ? (workspaceTheme ? Math.max(138, Style.settings.expandedHeight) : Style.settings.expandedHeight) : page === "prayers" ? Math.min(420, (root.width - 24) * 420 / 960) : page === "calendar" ? 300 : page === "media" ? 214 : page === "power" ? 130 : page === "themes" || page === "bars" ? 235 : page === "wallpapers" ? 200 : page === "launcher" ? 88 + Style.settings.rowHeight * Style.settings.launcherRows : page === "sound" ? Math.min(720, Math.max(300, soundSheet.implicitHeight + 44)) : page === "display" ? Math.min(680, displaySheet.implicitHeight + 44) : page === "control" || connectionOverlay ? Math.min(680, Math.max(420, controlContent.contentHeight + 28)) : Math.max(600, 400 + Style.settings.historyHeight)
    // Keep the Wayland buffer stable while the island animates inside it.
    readonly property int surfaceHeight: Style.settings.edgeGap + Math.max(Style.settings.gameHeight + 8, Style.settings.expandedHeight, 720, 400 + Style.settings.historyHeight, 88 + Style.settings.rowHeight * Style.settings.launcherRows) + 130
    readonly property var hitArea: mediaTransition ? mediaPopup : sideTransition ? sidePopup : main
    property alias leftHit: mediaCircle
    property alias rightHit: statusCircle
    property alias clockHit: separateClock
    property alias gameHit: gameBar
    property alias errorHit: errorBox
    readonly property bool sidePanel: ["control", "wifi", "bluetooth", "sound", "display"].indexOf(page) >= 0 && !Style.settings.gameMode && Style.settings.statusCircle && !Style.settings.notch && !workspaceTheme
    readonly property bool mediaPanel: page === "media" && !Style.settings.gameMode && Style.settings.albumCircle && !Style.settings.notch && !workspaceTheme
    readonly property bool visualSidePanel: ["control", "wifi", "bluetooth", "sound", "display"].includes(visualPage) && !Style.settings.gameMode && Style.settings.statusCircle && !Style.settings.notch && !workspaceTheme
    readonly property bool visualMediaPanel: visualPage === "media" && !Style.settings.gameMode && Style.settings.albumCircle && !Style.settings.notch && !workspaceTheme
    readonly property bool sideTransition: sidePanel || sidePopup.reveal > 0 || visualSidePanel
    readonly property bool mediaTransition: mediaPanel || mediaPopup.reveal > 0 || visualMediaPanel
    signal settingsRequested
    function send(a, v, e) {
        bridge.send(a, v, e);
    }
    function setting(k, v) {
        Style.settings = Object.assign({}, Style.settings, {
            [k]: v
        });
        send('setting', k, v);
    }
    function applyChoice() {
        const item = carousel.currentItem;
        if (item) {
            if (page === 'themes') {
                setting('theme', item.modelData);
                requestPage('wallpapers');
            } else if (page === 'bars') {
                setting('barTheme', item.modelData === 'Workspace' ? 'workspace' : 'apple');
                requestPage('');
            } else
                send('wallpaper', item.modelData);
        }
    }
    function panelGroup(p) {
        if (['control', 'wifi', 'bluetooth', 'sound', 'display', 'pairing'].includes(p)) return 'control';
        if (p === 'glance' || p === 'calendar' || p === 'prayers') return 'clock';
        return p;
    }
    function requestPage(p) {
        if (!p) {
            configureMotion(false);
            pendingPage = '';
            switchingPanels = false;
            switchWait.stop();
            page = '';
        } else if (switchingPanels) {
            pendingPage = p;
        } else if ((page && panelGroup(page) !== panelGroup(p)) || (!page && geometryAnimating)) {
            configureMotion(false);
            pendingPage = p;
            switchingPanels = true;
            page = '';
            switchWait.restart();
        } else {
            configureMotion(true);
            page = p;
        }
    }
    function configureMotion(opening) {
        for (const animation of [sideRevealAnimation, mediaRevealAnimation, mainWidthAnimation, mainHeightAnimation]) {
            animation.duration = opening ? Style.duration : Style.closeDuration;
            animation.easing.bezierCurve = opening ? Style.openCurve : Style.closeCurve;
        }
        contentFade.duration = opening ? Math.min(Style.duration, Style.settings.fade) : Style.closeDuration;
        contentFade.easing.type = opening ? Easing.OutQuad : Easing.InQuad;
    }
    function toggle(p) {
        const current = switchingPanels ? pendingPage : page;
        requestPage(current === p || (p === 'control' && panelGroup(current) === 'control') ? '' : p);
    }
    function lockSession() {
        requestPage('');
        send('lock');
    }
    function focusMediaCard() {
        if (page !== 'media') return;
        Qt.callLater(() => {
            if (root.page !== 'media') return;
            (root.mediaPanel ? sideMediaCard : inlineMediaCard).forceActiveFocus();
        });
    }
    onMediaPanelChanged: focusMediaCard()
    function movePowerSelection(direction) {
        if (page !== 'power') return;
        powerIndex = (powerIndex + direction + powerActions.length) % powerActions.length;
        powerConfirm = '';
    }
    function activatePower(index) {
        if (page !== 'power' || index < 0 || index >= powerActions.length) return;
        powerIndex = index;
        const action = powerActions[index][2];
        if (action === 'lock') {
            lockSession();
        } else if (powerConfirm === action) {
            send('power', action);
            requestPage('');
        } else {
            powerConfirm = action;
        }
    }
    Timer {
        id: switchWait
        interval: 16
        repeat: true
        onTriggered: {
            if (root.geometryAnimating) return;
            stop();
            const next = root.pendingPage;
            root.pendingPage = '';
            root.switchingPanels = false;
            root.configureMotion(true);
            root.page = next;
        }
    }
    Timer {
        interval: 16
        repeat: true
        running: root.visualPage !== '' && !root.expanded
        onTriggered: {
            if (!root.geometryAnimating) root.visualPage = '';
        }
    }
    function timeText(s) {
        return Math.floor((s || 0) / 60) + ':' + ('0' + Math.floor((s || 0) % 60)).slice(-2);
    }
    function showOsd(kind, value) {
        if (!expanded) {
            osd = kind;
            osdValue = value;
            osdTimer.restart();
        }
    }
    onPageChanged: {
        configureMotion(page !== '');
        if (page !== '') {
            visualPage = page;
        } else {
            closingContentWidth = Math.max(0, expandedContent.parent.width - expandedContent.inset * 2);
            closingContentHeight = Math.max(0, expandedContent.parent.height - expandedContent.inset * 2);
            if (Style.settings.reduceMotion || Style.duration === 0) visualPage = '';
        }
        powerConfirm = '';
        if (page === 'power') powerIndex = 0;
        if (expanded) stageHovered = false;
        send('page', page);
        if (page === 'themes' || page === 'wallpapers' || page === 'bars')
            Qt.callLater(() => {
                if (page === 'bars') themeSearch.text = '';
                carousel.currentIndex = Math.max(0, carousel.model.indexOf(page === 'bars' ? (root.workspaceTheme ? 'Workspace' : 'Dock') : page === 'themes' ? Style.settings.theme : (bridge.state.wallpaperSelected || '')));
                if (page === 'themes' || page === 'bars') themeSearch.forceActiveFocus();
                else expandedContent.forceActiveFocus();
            });
        if (page === 'clipboard')
            Qt.callLater(() => clipboardPanel.focusSearch());
        if (page === 'launcher')
            Qt.callLater(() => launcherPanel.focusSearch());
        if (page === 'media') focusMediaCard();
        if (page === 'power') Qt.callLater(() => {
            if (root.page === 'power') expandedContent.forceActiveFocus();
        });
    }
    onCurrentOutputChanged: {
        if (lastVolume >= 0 && currentOutput.volume !== lastVolume)
            showOsd('sound', currentOutput.volume);
        lastVolume = currentOutput.volume;
    }
    onDisplayChanged: {
        const names = (display.monitors || []).map(m => m.name);
        if (JSON.stringify(names) !== JSON.stringify(monitorNames)) monitorNames = names;
        if (lastBrightness >= 0 && display.brightness >= 0 && display.brightness !== lastBrightness)
            showOsd('display', display.brightness);
        lastBrightness = display.brightness;
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
    Timer {
        id: osdTimer
        interval: Style.settings.osdTimeout
        onTriggered: root.osd = ''
    }
    Rectangle {
        id: gameBar
        visible: Style.settings.gameMode
        anchors.top: parent.top
        width: parent.width
        height: Style.settings.gameHeight
        color: Style.bg
        ClockLabel {
            anchors.centerIn: parent
            text: Qt.formatDateTime(root.now, Style.clockFormat)
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.toggle('control')
        }
    }
    Rectangle {
        id: mediaCircle
        objectName: 'media-circle'
        visible: !root.workspaceTheme && Style.settings.albumCircle && !!root.media.title && !Style.settings.gameMode && !root.mediaTransition
        width: Style.settings.barHeight
        height: width
        antialiasing: true
        radius: width / 2
        color: Style.bg
        x: root.sideTransition ? root.width / 2 - Style.settings.collapsedWidth / 2 - width - root.dockCircleGap : main.x - width - root.dockCircleGap
        y: Math.max(0, Style.settings.edgeGap - (mediaMouse.containsMouse ? Style.settings.hoverLift : 0))
        Behavior on y { NumberAnimation { duration: Style.settings.reduceMotion ? 0 : Style.settings.hover; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.settleCurve } }
        RoundedImage {
            objectName: 'circle-artwork'
            anchors.fill: parent
            anchors.margins: 5
            source: root.media.art || ''
            textureSize: 64
        }
        Icon {
            anchors.centerIn: parent
            visible: !root.media.art
            name: 'media'
            width: 16; height: 16
            color: Style.accent
        }
        MouseArea {
            id: mediaMouse
            objectName: 'media-hover'
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle('media')
        }
    }
    Rectangle {
        id: statusCircle
        objectName: 'status-circle'
        visible: !root.workspaceTheme && Style.settings.statusCircle && !Style.settings.gameMode && !root.sideTransition
        width: Style.settings.barHeight
        height: width
        antialiasing: true
        radius: width / 2
        color: Style.bg
        x: root.mediaTransition ? root.width / 2 + Style.settings.collapsedWidth / 2 + root.dockCircleGap : main.x + main.width + root.dockCircleGap
        y: Math.max(0, Style.settings.edgeGap - (statusMouse.containsMouse ? Style.settings.hoverLift : 0))
        Behavior on y { NumberAnimation { duration: Style.settings.reduceMotion ? 0 : Style.settings.hover; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.settleCurve } }
        WifiBadge { anchors.fill: parent }
        MouseArea {
            id: statusMouse
            objectName: 'status-hover'
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    root.settingsRequested();
                else
                    root.toggle('control');
            }
        }
    }
    Rectangle {
        id: separateClock
        objectName: 'separate-clock'
        visible: root.sideTransition || root.mediaTransition
        x: (root.width - width) / 2
        y: Style.settings.notch ? 0 : Math.max(0, Style.settings.edgeGap - (separateClockMouse.containsMouse ? Style.settings.hoverLift : 0))
        Behavior on y { NumberAnimation { duration: Style.settings.reduceMotion ? 0 : Style.settings.hover; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.settleCurve } }
        readonly property bool notchHovered: Style.settings.notch && separateClockMouse.containsMouse
        width: Style.settings.collapsedWidth + (notchHovered ? Style.settings.hoverLift * 2 : 0)
        height: Style.settings.barHeight + (notchHovered ? Style.settings.hoverLift : 0)
        Behavior on width { NumberAnimation { duration: Style.settings.reduceMotion ? 0 : Style.settings.hover; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Style.settings.reduceMotion ? 0 : Style.settings.hover; easing.type: Easing.OutCubic } }
        radius: Style.settings.radius
        color: Style.settings.notch ? 'transparent' : Style.bg
        antialiasing: true
        NotchBackground {
            anchors.fill: parent
            visible: Style.settings.notch
            color: Style.bg
        }
        ClockLabel {
            anchors.centerIn: parent
            text: Qt.formatDateTime(root.now, Style.clockFormat)
        }
        MouseArea {
            id: separateClockMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.toggle('glance')
        }
    }
    // Mirror the media morph at the Wi-Fi circle's upper-left corner.
    Rectangle {
        id: sidePopup
        objectName: 'side-popup'
        property real reveal: root.sidePanel ? 1 : 0
        property real openHeight: 420
        property real openWidth: 550
        Connections {
            target: root
            function onPanelHeightChanged() { if (root.sidePanel) sidePopup.openHeight = root.panelHeight; }
            function onPanelWidthChanged() { if (root.sidePanel) sidePopup.openWidth = root.panelWidth; }
            function onSidePanelChanged() {
                if (root.sidePanel) {
                    sidePopup.openHeight = root.panelHeight;
                    sidePopup.openWidth = root.panelWidth;
                }
            }
        }
        x: root.width / 2 + Style.settings.collapsedWidth / 2 + root.dockCircleGap
        y: Style.settings.edgeGap
        width: Style.settings.barHeight + (Math.min(openWidth, root.width - x - 8) - Style.settings.barHeight) * reveal
        height: Style.settings.barHeight + (openHeight - Style.settings.barHeight) * reveal
        radius: Style.settings.radius + (Style.settings.expandedRadius - Style.settings.radius) * reveal
        visible: root.sideTransition
        color: Style.bg
        antialiasing: true
        clip: true
        Behavior on reveal {
            NumberAnimation {
                id: sideRevealAnimation
                duration: Style.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Style.openCurve
            }
        }
        WifiBadge {
            width: Style.settings.barHeight; height: width
            opacity: 1 - sidePopup.reveal
        }
        RoundedPanel {
            id: sideContentMask
            anchors.fill: parent
            radius: sidePopup.radius
            color: 'transparent'
            visible: root.visualSidePanel
        }
    }
    // The artwork circle is the fixed upper-right corner throughout the morph.
    Rectangle {
        id: mediaPopup
        objectName: 'media-popup'
        property real reveal: root.mediaPanel ? 1 : 0
        readonly property real corner: root.width / 2 - Style.settings.collapsedWidth / 2 - root.dockCircleGap
        x: Math.max(8, corner - width)
        y: Style.settings.edgeGap
        width: Style.settings.barHeight + (Math.min(412, Math.max(Style.settings.barHeight, corner - 8)) - Style.settings.barHeight) * reveal
        height: Style.settings.barHeight + (214 - Style.settings.barHeight) * reveal
        radius: Style.settings.radius + (Style.settings.expandedRadius - Style.settings.radius) * reveal
        color: '#000000'
        visible: root.mediaTransition
        antialiasing: true
        clip: true
        Behavior on reveal {
            NumberAnimation {
                id: mediaRevealAnimation
                duration: Style.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Style.openCurve
            }
        }
        RoundedPanel {
            anchors.fill: parent
            radius: mediaPopup.radius
            // Keep the original black frame, but contain artwork while folding.
            RoundedImage {
                anchors.fill: parent
                anchors.margins: 5
                source: root.media.art || ''
                antialiasing: true
                radius: width / 2
                opacity: 1 - mediaPopup.reveal
            }
            MediaCard {
                id: sideMediaCard
                objectName: 'media-card'
                menuOpen: root.mediaPanel
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                width: Math.min(412, Math.max(Style.settings.barHeight, mediaPopup.corner - 8)) - 28
                height: 186
                bridge: root.bridge
                opacity: mediaPopup.reveal
                enabled: root.mediaPanel
                focus: root.mediaPanel
                Keys.onEscapePressed: root.requestPage('')
            }
        }
    }
    Rectangle {
        id: main
        objectName: 'island-panel'
        visible: !root.mediaTransition && !root.sideTransition && (!Style.settings.gameMode || root.expanded || root.visualPage !== '' || !!bridge.toast || !!root.osd)
        x: (root.width - width) / 2
        y: Style.settings.notch ? 0 : Style.settings.gameMode ? Style.settings.gameHeight + 8 : Math.max(0, Style.settings.edgeGap - (root.stageHovered ? Style.settings.hoverLift : 0))
        width: Math.min(root.width - 16, root.expanded && !root.mediaPanel && !root.sidePanel ? root.panelWidth + root.notchMenuSidePadding * 2 : bridge.toast ? Style.settings.notificationWidth : root.osd ? 300 : Math.max(root.collapsedBarWidth, root.workspaceTheme ? compactContents.minimumBarWidth : 0) + (root.notchHovered ? Style.settings.hoverLift * 2 : 0))
        height: root.expanded ? root.panelHeight : bridge.toast ? 74 : root.osd ? 46 : Style.settings.barHeight + (root.notchHovered ? Style.settings.hoverLift : 0)
        radius: root.expanded ? Style.settings.expandedRadius : Style.settings.radius
        color: Style.settings.notch && !Style.settings.gameMode ? 'transparent' : root.page === 'media' ? '#000000' : Style.bg
        antialiasing: true
        NotchBackground {
            anchors.fill: parent
            visible: Style.settings.notch && !Style.settings.gameMode
            color: Style.bg
            cornerRadius: main.radius
        }
        clip: true
        HoverHandler { onHoveredChanged: root.stageHovered = hovered }
        Behavior on width {
            NumberAnimation {
                id: mainWidthAnimation
                duration: Style.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Style.openCurve
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Style.settings.reduceMotion ? 0 : Style.settings.hover
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Style.settings.reduceMotion ? 0 : Style.settings.fade
            }
        }
        Behavior on height {
            NumberAnimation {
                id: mainHeightAnimation
                duration: Style.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Style.openCurve
            }
        }
        RoundedPanel {
            id: mainContentMask
            anchors.fill: parent
            radius: main.radius
            color: 'transparent'
            visible: root.visualPage !== '' && !root.visualSidePanel && !root.visualMediaPanel
        }
        Item {
            anchors.fill: parent
            visible: root.visualPage === ''
            ClockLabel {
                anchors.centerIn: parent
                visible: !root.workspaceTheme && !bridge.toast && !root.osd
                text: Qt.formatDateTime(root.now, Style.clockFormat)
            }
            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                visible: !!root.osd && !bridge.toast
                Icon {
                    name: root.osd
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: Style.settings.osdThickness
                    radius: 3
                    color: Style.card
                    Rectangle {
                        width: parent.width * root.osdValue / 100
                        height: parent.height
                        radius: 3
                        color: Style.accent
                    }
                }
                Label {
                    text: Math.round(root.osdValue) + '%'
                    monospace: true
                    font.pixelSize: 11
                }
            }
            Column {
                visible: !!bridge.toast
                x: 20
                y: 10
                width: parent.width - 40
                Label {
                    text: bridge.toast ? bridge.toast.appName : ''
                    color: Style.muted
                    font.pixelSize: 11
                }
                Label {
                    text: bridge.toast ? bridge.toast.summary : ''
                    width: parent.width
                }
                Label {
                    visible: Style.settings.showBody
                    text: bridge.toast ? bridge.toast.body : ''
                    color: Style.muted
                    font.pixelSize: 11
                    width: parent.width
                }
            }
            NotchContents {
                id: compactContents
                objectName: 'notch-compact'
                anchors.fill: parent
                anchors.leftMargin: 24; anchors.rightMargin: 24
                visible: root.workspaceTheme && !bridge.toast && !root.osd
                z: 1
                bridge: root.bridge
                now: root.now
                onOpenPage: p => root.toggle(p)
            }
            MouseArea {
                objectName: 'clock-hover'
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    root.stageHovered = true;
                }
                onExited: {
                    root.stageHovered = false;
                }
                onClicked: m => {
                    if (m.button === Qt.RightButton)
                        root.settingsRequested();
                    else if (m.button === Qt.MiddleButton)
                        root.toggle('launcher');
                    else if (m.modifiers & Qt.ShiftModifier)
                        root.toggle('prayers');
                    else
                        root.toggle(bridge.toast ? 'control' : 'glance');
                }
                onWheel: w => root.send('volume', Math.max(0, Math.min(100, root.currentOutput.volume + (w.angleDelta.y > 0 ? 5 : -5))))
            }
        }
        Item {
            id: expandedContent
            objectName: 'expanded-content'
            parent: root.visualSidePanel ? sideContentMask : mainContentMask
            readonly property real inset: root.visualPage === 'media' || root.visualPage === 'control' || root.visualConnectionOverlay || root.visualDetailOverlay ? 14 : 13 + Style.settings.innerPadding
            readonly property real horizontalInset: inset + root.notchMenuSidePadding
            x: horizontalInset; y: inset
            width: root.expanded ? Math.max(0, parent.width - horizontalInset * 2) : root.closingContentWidth
            height: root.expanded ? Math.max(0, parent.height - inset * 2) : root.closingContentHeight
            visible: root.visualPage !== ''
            enabled: root.expanded
            opacity: root.expanded ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    id: contentFade
                    duration: Math.min(Style.duration, Style.settings.fade)
                    easing.type: Easing.OutQuad
                }
            }
            focus: root.expanded
            Keys.onEscapePressed: root.requestPage('')
            Keys.onLeftPressed: {
                if (root.page === 'power') root.movePowerSelection(-1);
                else if (['themes', 'wallpapers', 'bars'].includes(root.page)) carousel.decrementCurrentIndex();
            }
            Keys.onRightPressed: {
                if (root.page === 'power') root.movePowerSelection(1);
                else if (['themes', 'wallpapers', 'bars'].includes(root.page)) carousel.incrementCurrentIndex();
            }
            Keys.onReturnPressed: event => {
                if (root.page === 'power') {
                    if (!event.isAutoRepeat) root.activatePower(root.powerIndex);
                } else if (['themes', 'wallpapers', 'bars'].includes(root.page)) root.applyChoice();
            }
            Keys.onEnterPressed: event => {
                if (root.page === 'power' && !event.isAutoRepeat) root.activatePower(root.powerIndex);
            }
            Keys.onPressed: event => {
                if (root.page !== 'power') return;
                if (event.key === Qt.Key_Up) {
                    root.movePowerSelection(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    root.movePowerSelection(1);
                    event.accepted = true;
                }
            }
            Item {
                id: glancePreview
                objectName: 'clock-preview'
                visible: root.visualPage === 'glance' && !root.workspaceTheme
                anchors.fill: parent
                Rectangle {
                    objectName: 'clock-preview-highlight'
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 16
                    antialiasing: true
                    color: Style.panel
                    opacity: glanceMouse.containsMouse ? .7 : 0
                    Behavior on opacity { NumberAnimation { duration: Style.settings.reduceMotion ? 0 : Style.settings.hover } }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    ClockLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(root.now, Style.clockFormat)
                        font.pixelSize: 24
                    }
                    Row {
                        height: 38
                        Repeater {
                            model: 7
                            Item {
                                required property int index
                                property date day: new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate() + index - 3)
                                width: 28; height: 38
                                opacity: [0.22, 0.45, 0.72, 1, 0.72, 0.45, 0.22][index]
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Qt.formatDateTime(parent.day, 'ddd').slice(0, parent.index === 3 ? 3 : 1).toUpperCase()
                                    font.pixelSize: 10
                                    font.weight: parent.index === 3 ? Font.DemiBold : Font.Normal
                                    color: parent.day.getDay() === 0 ? '#a65b52' : Style.muted
                                }
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 14; height: 24
                                    verticalAlignment: Text.AlignVCenter
                                    text: Qt.formatDateTime(parent.day, 'd')
                                    color: parent.index === 3 ? Style.accent : parent.day.getDay() === 0 ? '#a65b52' : Style.muted
                                    font.pixelSize: parent.index === 3 ? 20 : 14
                                    font.weight: parent.index === 3 ? Font.DemiBold : Font.Normal
                                }
                            }
                        }
                    }
                }
                MouseArea {
                    id: glanceMouse
                    objectName: 'clock-preview-hover'
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        root.monthOffset = 0;
                        root.page = event.modifiers & Qt.ShiftModifier ? 'calendar' : 'prayers';
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: 'Open prayer times'
                }
            }
            NotchContents {
                objectName: 'notch-expanded'
                visible: root.visualPage === 'glance' && root.workspaceTheme
                anchors.fill: parent
                bridge: root.bridge
                now: root.now
                expanded: true
                onOpenPage: p => root.requestPage(p)
            }
            ColumnLayout {
                objectName: 'full-calendar'
                visible: root.visualPage === 'calendar'
                anchors.fill: parent
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Chip {
                        objectName: 'calendar-previous'
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28
                        radius: 14
                        icon: 'chevron-left'
                        onClicked: root.monthOffset--
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(new Date(root.now.getFullYear(), root.now.getMonth() + root.monthOffset, 1), 'MMMM yyyy')
                        font.weight: Font.DemiBold
                    }
                    Chip {
                        objectName: 'calendar-next'
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28
                        radius: 14
                        icon: 'chevron-right'
                        onClicked: root.monthOffset++
                    }
                }
                GridLayout {
                    columns: 7
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Repeater {
                        model: Style.settings.weekMonday ? ['M', 'T', 'W', 'T', 'F', 'S', 'S'] : ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        Label {
                            required property string modelData
                            text: modelData
                            color: Style.muted
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 11
                        }
                    }
                    Repeater {
                        model: 42
                        Rectangle {
                            required property int index
                            property date first: new Date(root.now.getFullYear(), root.now.getMonth() + root.monthOffset, 1)
                            property date date: new Date(first.getFullYear(), first.getMonth(), index - ((first.getDay() + (Style.settings.weekMonday ? 6 : 0)) % 7) + 1)
                            property bool today: date.toDateString() === root.now.toDateString()
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: 'transparent'
                            Rectangle {
                                anchors.centerIn: parent
                                width: 28
                                height: 28
                                radius: 14
                                color: parent.today ? Style.accent : 'transparent'
                            }
                            Label {
                                anchors.centerIn: parent
                                text: parent.date.getDate()
                                font.pixelSize: 12
                                color: parent.today ? Style.bg : parent.date.getMonth() === parent.first.getMonth() ? Style.text : Style.muted
                                opacity: parent.date.getMonth() === parent.first.getMonth() ? 1 : .45
                            }
                        }
                    }
                }
            }
            PrayerPanel {
                objectName: 'prayer-panel'
                visible: root.visualPage === 'prayers'
                anchors.fill: parent
                bridge: root.bridge
                now: root.now
                onSettingsRequested: root.settingsRequested()
            }
            MediaCard {
                id: inlineMediaCard
                objectName: 'media-game-card'
                menuOpen: root.page === 'media' && !root.mediaPanel
                visible: root.visualPage === 'media' && !root.visualMediaPanel
                anchors.fill: parent
                bridge: root.bridge
            }
            ControlCenter {
                id: controlContent
                visible: root.visualPage === 'control' || root.visualConnectionOverlay
                enabled: !root.visualDetailOverlay
                anchors.fill: parent
                bridge: root.bridge
                onOpenPage: p => root.requestPage(p)
                onLockRequested: root.lockSession()
            }
            Rectangle {
                objectName: 'connection-dimmer'
                visible: root.visualConnectionOverlay
                anchors.fill: parent
                color: '#99000000'
                z: 9
                MouseArea { anchors.fill: parent; onClicked: root.requestPage('control') }
            }
            ConnectionSheet {
                objectName: 'connection-sheet'
                visible: root.visualConnectionOverlay
                anchors.centerIn: parent
                width: parent.width - 12
                height: implicitHeight
                bridge: root.bridge
                mode: root.visualPage === 'bluetooth' ? 'bluetooth' : 'wifi'
                z: 10
                onClosed: root.page = 'control'
            }
            SoundSheet {
                id: soundSheet
                objectName: 'sound-sheet'
                visible: root.visualPage === 'sound'
                anchors.fill: parent
                anchors.margins: 8
                bridge: root.bridge
                z: 10
                onClosed: root.requestPage('control')
            }
            DisplaySheet {
                id: displaySheet
                objectName: 'display-sheet'
                visible: root.visualPage === 'display'
                anchors.fill: parent
                anchors.margins: 8
                bridge: root.bridge
                monitorNames: root.monitorNames
                z: 10
                onClosed: root.requestPage('control')
            }
            ClipboardPanel {
                id: clipboardPanel
                anchors.fill: parent
                visible: root.visualPage === 'clipboard'
                bridge: root.bridge
            }
            LauncherPanel {
                id: launcherPanel
                visible: root.visualPage === 'launcher'
                anchors.fill: parent
                bridge: root.bridge
                onLaunched: root.requestPage('')
            }
            ColumnLayout {
                visible: root.visualPage === 'pairing'
                anchors.fill: parent
                spacing: 16
                Label {
                    text: 'Bluetooth pairing'
                    font.pixelSize: 20
                }
                Label {
                    text: root.pairing ? root.pairing.message : ''
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                Field {
                    id: pairPin
                    Layout.fillWidth: true
                    visible: root.pairing && ['pin', 'passkey'].indexOf(root.pairing.kind) >= 0
                    placeholderText: 'PIN or passkey'
                }
                Item {
                    Layout.fillHeight: true
                }
                RowLayout {
                    Chip {
                        text: 'Cancel'
                        onClicked: {
                            root.send('pair-response', null);
                            root.page = 'bluetooth';
                        }
                    }
                    Chip {
                        text: 'Confirm'
                        active: true
                        visible: root.pairing && ['confirm', 'pin', 'passkey'].indexOf(root.pairing.kind) >= 0
                        onClicked: {
                            root.send('pair-response', root.pairing.kind === 'confirm' ? true : pairPin.text);
                            pairPin.text = '';
                        }
                    }
                }
            }
            RowLayout {
                visible: root.visualPage === 'power'
                anchors.fill: parent
                spacing: 8
                Repeater {
                    model: root.powerActions
                    Rectangle {
                        required property int index
                        required property var modelData
                        objectName: 'power-' + modelData[2]
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 22
                        color: powerMouse.containsMouse || root.powerIndex === index ? Style.accent : Style.panel
                        border.width: root.powerIndex === index ? 2 : 0
                        border.color: Style.text
                        Column {
                            anchors.centerIn: parent
                            spacing: 9
                            PowerIcon {
                                objectName: 'power-icon-' + modelData[2]
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: modelData[0]
                                width: 20; height: 20
                                color: powerMouse.containsMouse || root.powerIndex === index ? Style.bg : Style.text
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.powerConfirm === modelData[2] ? 'Confirm?' : modelData[1]
                                font.pixelSize: 12
                                color: powerMouse.containsMouse || root.powerIndex === index ? Style.bg : Style.text
                            }
                        }
                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.activatePower(index);
                            }
                        }
                    }
                }
            }
            ColumnLayout {
                id: selector
                readonly property bool bars: root.visualPage === 'bars'
                readonly property bool theme: root.visualPage === 'themes' || bars
                visible: root.visualPage === 'themes' || root.visualPage === 'wallpapers' || root.visualPage === 'bars'
                anchors.fill: parent
                spacing: selector.theme ? 12 : 8
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: selector.theme ? 40 : 26
                    SelectorSearch {
                        id: themeSearch
                        objectName: 'theme-search'
                        placeholderText: selector.bars ? 'Search bar themes…' : 'Search themes…'
                        visible: selector.theme
                        Layout.fillWidth: true
                        onPrevious: carousel.decrementCurrentIndex()
                        onNext: carousel.incrementCurrentIndex()
                        onAccepted: root.applyChoice()
                        onTextChanged: carousel.currentIndex = 0
                    }
                    Label {
                        visible: !selector.theme
                        text: 'Wallpaper'
                        Layout.fillWidth: true
                        font.pixelSize: 14
                    }
                    Label {
                        objectName: 'selector-heading-status'
                        text: selector.theme ? (carousel.count ? carousel.currentIndex + 1 : 0) + '/' + carousel.count : Style.settings.theme
                        color: Style.muted
                        font.pixelSize: selector.theme ? 12 : 10
                    }
                }
                ListView {
                    id: carousel
                    objectName: 'selector-carousel'
                    readonly property real cardWidth: selector.theme ? 190 : 152
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    highlightRangeMode: selector.bars ? ListView.NoHighlightRange : ListView.StrictlyEnforceRange
                    snapMode: ListView.SnapOneItem
                    preferredHighlightBegin: (width - cardWidth) / 2
                    preferredHighlightEnd: (width + cardWidth) / 2
                    highlightMoveDuration: Style.duration
                    spacing: selector.theme ? 12 : 14
                    clip: true
                    model: selector.theme ? (selector.bars ? ['Workspace', 'Dock'] : Object.keys(Style.palettes).sort()).filter(t => t.toLowerCase().includes(themeSearch.text.toLowerCase())) : (bridge.state.wallpapers || [])
                    onModelChanged: if (root.page === 'bars') Qt.callLater(() => { carousel.contentX = 0; }); else if (root.page === 'wallpapers') Qt.callLater(() => {
                        if (root.page === 'wallpapers') carousel.currentIndex = Math.max(0, carousel.model.indexOf(root.appliedWallpaper));
                    })
                    delegate: SelectorCard {
                        required property int index
                        required property string modelData
                        objectName: 'selector-card-' + modelData
                        entry: modelData
                        theme: selector.theme
                        bar: selector.bars
                        selected: ListView.isCurrentItem
                        applied: selector.bars ? modelData === (root.workspaceTheme ? 'Workspace' : 'Dock') : selector.theme ? modelData === Style.settings.theme : modelData === root.appliedWallpaper
                        onSelectedByClick: {
                            carousel.currentIndex = index;
                            if (selector.theme) root.applyChoice();
                        }
                        onAppliedByClick: { carousel.currentIndex = index; root.applyChoice(); }
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: carousel.count === 0
                        text: selector.theme ? (selector.bars ? 'No bar themes found' : 'No themes found') : 'Add images to ' + Style.settings.wallpaperFolder
                        color: Style.muted
                        font.pixelSize: 12
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    Label {
                        objectName: 'wallpaper-filename'
                        visible: !selector.theme
                        Layout.fillWidth: true
                        text: carousel.currentItem ? carousel.currentItem.entry.split('/').pop() : ''
                        color: Style.muted
                        font.pixelSize: 10
                    }
                    Item { visible: selector.theme; Layout.fillWidth: true }
                    Label {
                        objectName: 'selector-apply-hint'
                        text: selector.theme ? 'Enter to apply' : (carousel.count ? carousel.currentIndex + 1 : 0) + '/' + carousel.count + '  ·  Enter to apply'
                        color: Style.muted
                        font.pixelSize: selector.theme ? 12 : 10
                    }
                }
            }

        }
    }
    MouseArea {
        objectName: 'detail-scroll-gutter'
        parent: root.visualSidePanel ? sideContentMask : mainContentMask
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: expandedContent.inset + 8
        visible: root.visualDetailOverlay
        enabled: root.expanded && root.visualDetailOverlay
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const distance = wheel.pixelDelta.y || wheel.angleDelta.y / 120 * 64;
            if (root.visualPage === 'sound') soundSheet.scrollBy(-distance);
            else displaySheet.scrollBy(-distance);
            wheel.accepted = true;
        }
    }
    Rectangle {
        id: errorBox
        visible: !!bridge.error
        x: Math.max(8, (root.width - width) / 2)
        y: main.y + main.height + 4
        width: Math.min(root.width - 16, 600)
        height: errorLabel.implicitHeight + 20
        radius: 12
        color: '#502a27'
        Label {
            id: errorLabel
            anchors.fill: parent
            anchors.margins: 10
            text: bridge.error
            wrapMode: Text.WordWrap
            font.pixelSize: 12
        }
    }
}
