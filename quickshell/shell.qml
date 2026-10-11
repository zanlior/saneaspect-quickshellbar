//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "components"

ShellRoot {
    id: shell
    property var state: ({})
    property var applications: DesktopEntries.applications.values
    function iconPath(name) { return Quickshell.iconPath(name, true); }
    property var notifications: prayerNotificationStore.notifications.concat(notificationServer.trackedNotifications.values.slice().reverse())
    property var toast: null
    property string error: ""
    property string activePage: ""
    property bool barVisible: true
    function send(action, value, extra) {
        if (action === 'page') activePage = value;
        backend.write(JSON.stringify({
            action: action,
            value: value,
            extra: extra
        }) + "\n");
    }
    function dismiss(n) {
        if (toast === n)
            toast = null;
        n.dismiss();
    }
    function clearNotifications() {
        const items = notifications.slice();
        items.forEach(n => n.dismiss());
    }
    Process {
        id: backend
        command: ["python3", Quickshell.shellDir + "/scripts/backend.py"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const v = JSON.parse(data);
                    if (v.prayerNotification) {
                        shell.toast = prayerNotificationStore.post(v.prayerNotification);
                        shell.barVisible = true;
                        shell.requestPage('');
                        toastTimer.interval = 10000;
                        toastTimer.restart();
                    }
                    if ('dynamicPalette' in v) Style.dynamicPalette = v.dynamicPalette;
                    if (v.clipboardCopied) shell.requestPage('');
                    if (v.settings)
                        Style.settings = v.settings;
                    if (v.error) {
                        shell.error = v.error;
                        errorTimer.restart();
                    }
                    shell.state = Object.assign({}, shell.state, v);
                } catch (e) {
                    console.warn("Bridge response:", e);
                }
            }
        }
        onExited: (code, status) => {
            shell.error = "System bridge stopped. Restart Island to reconnect.";
        }
    }
    Timer {
        id: errorTimer
        interval: 8000
        onTriggered: shell.error = ""
    }
    Timer {
        id: toastTimer
        onTriggered: shell.toast = null
    }
    PrayerNotificationStore {
        id: prayerNotificationStore
        onDismissed: n => { if (shell.toast === n) shell.toast = null; }
    }
    NotificationServer {
        id: notificationServer
        bodySupported: true
        actionsSupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true;
            n.closed.connect(() => {
                if (shell.toast === n)
                    shell.toast = null;
            });
            if (!Style.settings.focus || n.appName === 'Prayer times') {
                shell.toast = n;
                toastTimer.interval = n.appName === 'Prayer times' ? 10000 : n.urgency === 2 ? Style.settings.urgentTimeout : Style.settings.popupTimeout;
                toastTimer.restart();
            }
        }
    }
    Loader {
        active: Style.settings.polkitAgent
        source: "Authentication.qml"
    }
    IpcHandler {
        target: "island"
        function open(page: string): void {
            shell.barVisible = true;
            shell.requestPage(page);
        }
        function close(): void {
            shell.requestPage("");
        }
        function lock(): void {
            shell.requestPage("");
            shell.send('lock');
        }
        function toggle(page: string): void {
            shell.barVisible = true;
            shell.requestToggle(page);
        }
        function bar(): void {
            shell.requestPage('');
            shell.barVisible = !shell.barVisible;
        }
        function night(): void { shell.send('night-toggle'); }
        function game(): void { shell.send('game-toggle'); }
        function volumeStep(delta: int): void { shell.send('volume-step', delta); }
        function brightnessStep(delta: int): void { shell.send('brightness-step', delta); }
        function refresh(): void { shell.send('page', shell.activePage); }
        function theme(name: string): void { shell.send('setting', 'theme', name); }
        function settings(): void {
            settingsWindow.visible = !settingsWindow.visible;
        }
        function prayers(): void {
            shell.barVisible = true;
            shell.requestToggle('prayers');
        }
        function testPrayerReminder(): void { shell.send('prayer-test-reminder'); }
        function fonts(interfaceFont: string, numericFont: string): void {
            shell.send('setting', 'fontFamily', interfaceFont);
            shell.send('setting', 'monoFontFamily', numericFont);
        }
        function brightness(value: int, monitor: string): void {
            shell.send('brightness', value, monitor);
        }
        function status(): string {
            return JSON.stringify({fontFamily: Style.uiFont, monoFontFamily: Style.monoFont, page: shell.activePage, theme: Style.settings.theme, barStyle: Style.settings.notch ? 'Notch' : 'Dock', barVisible: shell.barVisible, prayerReminder: shell.toast && shell.toast.appName === 'Prayer times' ? shell.toast.summary : '', prayerReminderCount: prayerNotificationStore.notifications.length, display: shell.state.display});
        }
    }
    signal requestPage(string page)
    signal requestToggle(string page)
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            visible: shell.barVisible
            anchors.top: true
            anchors.left: true
            anchors.right: true
            implicitHeight: Math.min(screen.height, island.surfaceHeight)
            exclusiveZone: !shell.barVisible ? 0 : Style.settings.gameMode ? Style.settings.gameHeight : Style.settings.barHeight + Style.settings.edgeGap * 2
            color: "transparent"
            WlrLayershell.namespace: "island-shell"
            WlrLayershell.keyboardFocus: island.page !== "" && island.page !== "glance" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            mask: Region {
                HitRegion {
                    target: island.hitArea
                }
                HitRegion {
                    target: island.leftHit
                }
                HitRegion {
                    target: island.rightHit
                }
                HitRegion {
                    target: island.clockHit
                }
                HitRegion {
                    target: island.gameHit
                }
                HitRegion {
                    target: island.errorHit
                }
            }
            HyprlandFocusGrab {
                windows: [window]
                active: island.expanded || island.switchingPanels
                onCleared: island.requestPage("")
            }
            Island {
                id: island
                anchors.fill: parent
                bridge: shell
                onSettingsRequested: {
                    if (island.page === 'prayers') settingsContent.section = 'Prayer Times';
                    settingsWindow.visible = true;
                }
                Connections {
                    target: shell
                    function onRequestPage(page) {
                        const monitor = Hyprland.monitorFor(window.screen);
                        island.requestPage(!page || !Hyprland.focusedMonitor || monitor === Hyprland.focusedMonitor ? page : "");
                    }
                    function onRequestToggle(page) {
                        const monitor = Hyprland.monitorFor(window.screen);
                        if (!Hyprland.focusedMonitor || monitor === Hyprland.focusedMonitor)
                            island.toggle(page);
                        else
                            island.requestPage('');
                    }
                }
            }
        }
    }
    component HitRegion: Region {
        required property var target
        x: target.x
        y: target.y
        width: target.visible ? target.width : 0
        height: target.visible ? target.height : 0
        radius: target.radius || 0
    }
    FloatingWindow {
        id: settingsWindow
        visible: false
        onClosed: visible = false
        title: "Island Settings"
        color: Style.bg
        implicitWidth: 1180
        implicitHeight: 830
        Settings {
            id: settingsContent
            anchors.fill: parent
            bridge: shell
        }
    }
}
