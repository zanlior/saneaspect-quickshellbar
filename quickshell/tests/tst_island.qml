import QtQuick
import QtTest
import ".."

Item {
    id: scene
    width: 1440; height: 900
    QtObject {
        id: mock
        property var state: ({
            media: {title:'Sample Track',artist:'Example Artist',album:'Example Album',player:'Spotify',art:Qt.resolvedUrl('fixtures/cover.svg'),position:126,length:178,playing:false},
            wifi: {enabled:true,networks:[{ssid:'Example Wi-Fi',active:true,security:'WPA2',signal:63,device:'wlan0'}]},
            bluetooth: {enabled:true,devices:[]},
            audio: {outputs:[],inputs:[],apps:[]},
            display: {brightness:40,monitors:[{name:'DP-1',make:'ASUSTek',model:'VG248',width:1920,height:1080,refreshRate:165,scale:1,brightness:40,availableModes:[]}]}
        })
        property var applications: []
        property int launches: 0
        property var notifications: []
        property var toast: null
        property string error: ''
        signal commandSent(string action, var value, var extra)
        function send(action, value, extra) { commandSent(action, value, extra); }
        function clearNotifications() {}
        function dismiss() {}
    }
    Island { id: island; anchors.fill: parent; bridge: mock }
    SignalSpy { id: commands; target: mock; signalName: 'commandSent' }
    TestCase {
        name: 'IslandInteraction'
        when: windowShown
        property var defaults
        property var originalState
        function initTestCase() {
            defaults = Object.assign({}, Style.settings);
            originalState = Object.assign({}, mock.state);
        }
        function init() {
            island.requestPage(''); island.stageHovered = false;
            mock.state = Object.assign({}, originalState);
            mock.applications = []; mock.launches = 0;
            Style.settings = Object.assign({}, defaults, {movement:100,hover:80,reduceMotion:false});
            mouseMove(scene, 20, 700); wait(180);
            commands.clear();
        }
        function test_launcher_search_navigation_launch_and_reopen() {
            mock.applications = [
                {name:'About Xfce',comment:'Information about the Xfce Desktop Environment',keywords:[],execute:()=>mock.launches++},
                {name:'Alacritty',comment:'Terminal',genericName:'Console',keywords:['shell'],execute:()=>mock.launches++},
                {name:'Settings',comment:'Configure the desktop',keywords:['preferences'],execute:()=>mock.launches++}
            ];
            island.requestPage('launcher'); wait(180);
            const input = findChild(island,'launcher-search-input');
            const results = findChild(island,'launcher-results');
            verify(input.activeFocus);
            input.text='  TERMINAL  shell  '; wait(30);
            compare(results.count,1);
            compare(results.model[0].name,'Alacritty');
            input.text='missing'; wait(30); compare(results.count,0);
            keyClick(Qt.Key_Return); compare(mock.launches,0);
            input.text=''; wait(30); compare(results.count,3);
            keyClick(Qt.Key_Down); compare(results.currentIndex,1);
            keyClick(Qt.Key_Up); compare(results.currentIndex,0);
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Return);
            compare(mock.launches,1); compare(island.page,'');
            wait(180); island.requestPage('launcher'); wait(180);
            compare(input.text,''); verify(input.activeFocus);
        }
        function test_control_lock_locks_directly_and_closes_menu() {
            island.page = 'control'; wait(180); commands.clear();
            mouseClick(findChild(island, 'card-lock'));
            compare(island.page, '');
            compare(commands.signalArguments.map(args => args[0]).join(','), 'page,lock');
        }
        function test_power_menu_lock_uses_the_same_lock_action() {
            island.page = 'power'; wait(180); commands.clear();
            mouseClick(findChild(island, 'power-lock'));
            compare(island.page, '');
            compare(commands.signalArguments.map(args => args[0]).join(','), 'page,lock');
        }
        function test_clock_click_preview_and_calendar_toggle() {
            let clock = findChild(island, 'clock-hover');
            mouseMove(clock, 48, 16); wait(600);
            compare(island.page, '');
            mouseClick(clock, 48, 16); compare(island.page, 'glance');
            wait(180);
            const preview = findChild(island, 'clock-preview-hover');
            const highlight = findChild(island, 'clock-preview-highlight');
            mouseMove(scene, 20, 700);
            tryCompare(highlight, 'opacity', 0);
            mouseMove(preview, preview.width / 2, preview.height / 2);
            tryCompare(highlight, 'opacity', .7);
            compare(island.page, 'glance');
            island.monthOffset = 2;
            mouseClick(preview, preview.width / 2, preview.height / 2);
            compare(island.page, 'prayers');
            compare(island.monthOffset, 0);
            verify(findChild(island, 'prayer-panel').visible);
            island.toggle('prayers'); compare(island.page, '');
            island.requestPage('calendar'); wait(180);
            verify(findChild(island, 'full-calendar').visible);
            mouseClick(findChild(island, 'calendar-next'));
            compare(island.monthOffset, 1);
            mouseClick(findChild(island, 'calendar-previous'));
            compare(island.monthOffset, 0);
            island.toggle('calendar'); compare(island.page, '');
            island.toggle('calendar'); tryCompare(island, 'page', 'calendar');
            island.toggle('calendar'); compare(island.page, '');
        }
        function test_status_and_artwork_hover_lift() {
            for (const name of ['media', 'status']) {
                let circle = findChild(island, name + '-circle');
                let area = findChild(island, name + '-hover');
                verify(circle.visible);
                let origin = circle.y;
                mouseMove(area, 16, 16);
                tryCompare(circle, 'y', origin - Style.settings.hoverLift);
                compare(island.page, '');
                mouseMove(scene, 20, 700);
                tryCompare(circle, 'y', origin);
            }
        }
        function test_compact_connection_sheet_over_control_center() {
            island.page = 'wifi'; wait(180);
            let sheet = findChild(island, 'connection-sheet');
            verify(sheet.visible);
            verify(findChild(island, 'connection-dimmer').visible);
            verify(sheet.height < island.hitArea.height - 100);
            mouseClick(findChild(sheet, 'connection-back'));
            compare(island.page, 'control');
        }
        function test_clock_to_control_updates_the_menu_width() {
            const popup = findChild(island, 'side-popup');
            for (const clock of ['glance', 'calendar']) {
                for (const target of ['control', 'wifi']) {
                    island.page = clock; wait(180);
                    island.page = target;
                    tryCompare(popup, 'reveal', 1);
                    compare(popup.openWidth, 514);
                    fuzzyCompare(popup.width, 514, .1);
                    island.requestPage(''); wait(180);
                }
            }
        }
        function test_switch_waits_for_the_current_panel_to_close() {
            island.page = 'glance'; wait(180);
            mouseClick(findChild(island, 'status-hover'));
            compare(island.page, '');
            compare(island.pendingPage, 'control');
            wait(40);
            compare(island.page, '');
            verify(island.geometryAnimating);
            tryCompare(island, 'page', 'control');
            fuzzyCompare(findChild(island, 'island-panel').width, Style.settings.collapsedWidth, .1);
            compare(island.pendingPage, '');
            island.toggle('media');
            compare(island.page, '');
            wait(40);
            compare(island.page, '');
            tryCompare(island, 'page', 'media');
            compare(findChild(island, 'side-popup').reveal, 0);
        }
        function test_shortcuts_toggle_and_replace_pending_panels() {
            for (const page of ['launcher', 'control', 'calendar', 'power', 'themes', 'wallpapers']) {
                island.toggle(page); tryCompare(island, 'page', page); wait(180);
                island.toggle(page); compare(island.page, ''); wait(180);
            }
            island.page = 'media'; wait(180);
            island.toggle('control');
            island.toggle('power');
            compare(island.pendingPage, 'power');
            tryCompare(island, 'page', 'power'); wait(180);
            island.toggle('control');
            island.toggle('control');
            compare(island.pendingPage, '');
            wait(180); compare(island.page, '');
            island.page = 'wifi'; wait(180);
            island.toggle('control'); compare(island.page, ''); wait(180);
            island.page = 'themes'; wait(180);
            island.toggle('wallpapers');
            compare(island.page, '');
            tryCompare(island, 'page', 'wallpapers');
        }
        function test_wifi_connected_card_scanning_and_disconnect() {
            island.page = 'wifi'; wait(180);
            verify(commands.signalArguments.some(args => args[0] === 'wifi-scan'));
            const sheet = findChild(island, 'connection-sheet');
            const connected = findChild(sheet, 'connected-network');
            verify(connected.y < findChild(sheet, 'networks-heading').y);
            const disconnect = findChild(sheet, 'wifi-disconnect');
            mock.state = Object.assign({}, mock.state, {busy:['wifi'],busyCommands:{wifi:'wifi-scan'}});
            tryCompare(findChild(sheet, 'connection-scanning'), 'visible', true);
            verify(disconnect.enabled);
            mock.state = Object.assign({}, mock.state, {busy:['wifi'],busyCommands:{wifi:'wifi-connect'}});
            tryCompare(findChild(sheet, 'connection-scanning'), 'visible', false);
            mock.state = Object.assign({}, mock.state, {busy:[],busyCommands:{}});
            commands.clear(); mouseClick(disconnect);
            compare(commands.signalArguments[0][0], 'wifi-disconnect');
            compare(commands.signalArguments[0][1], 'wlan0');
        }
        function test_clipboard_search_and_copy_with_keyboard() {
            mock.state = Object.assign({}, mock.state, {clipboard:[{id:'10',text:'First entry'},{id:'20',text:'Second entry'}]});
            island.requestPage('clipboard'); wait(180);
            const input = findChild(island, 'clipboard-search');
            const list = findChild(island, 'clipboard-history');
            input.text = 'second';
            tryCompare(list, 'count', 1);
            compare(list.model[0].id, '20');
            commands.clear(); input.forceActiveFocus(); keyClick(Qt.Key_Return);
            compare(commands.signalArguments[0][0], 'clipboard-copy');
            compare(commands.signalArguments[0][1], '20');
            keyClick(Qt.Key_Escape); compare(island.page, '');
        }
        function test_power_icons_load_as_vectors() {
            island.page = 'power'; wait(180);
            for (const action of ['lock','suspend','logout','reboot','poweroff'])
                tryCompare(findChild(island, 'power-icon-' + action), 'status', Image.Ready);
        }
        function test_theme_search_and_applied_dot_are_independent_of_selection() {
            island.page = 'themes'; wait(180);
            const carousel = findChild(island, 'selector-carousel');
            compare(carousel.model[0], 'anime');
            compare(carousel.model[1], 'ariadne');
            compare(carousel.currentIndex, 1);
            compare(findChild(island, 'selector-heading-status').text, '2/' + Object.keys(Style.palettes).length);
            const applied = findChild(island, 'applied-dot-ariadne');
            verify(applied.visible);
            commands.clear();
            keyClick(Qt.Key_Right);
            compare(carousel.currentIndex, 2);
            compare(Style.settings.theme, 'ariadne');
            verify(applied.visible);
            compare(commands.count, 0);
            const input = findChild(island, 'theme-search-input');
            mouseClick(input);
            for (const key of [Qt.Key_N,Qt.Key_O,Qt.Key_R,Qt.Key_D]) keyClick(key);
            tryCompare(carousel, 'count', 1);
            compare(carousel.model[0], 'nord');
            compare(findChild(island, 'selector-heading-status').text, '1/1');
            keyClick(Qt.Key_Return);
            compare(Style.settings.theme, 'nord');
            compare(commands.signalArguments[0][0], 'setting');
            compare(commands.signalArguments[0][1], 'theme');
            compare(commands.signalArguments[0][2], 'nord');
            tryCompare(island, 'page', 'wallpapers');
            input.text = '';
        }
        function test_wallpaper_selection_preserves_the_applied_dot_until_enter() {
            const first = Qt.resolvedUrl('fixtures/cover.svg').toString().replace('file://','');
            const second = Qt.resolvedUrl('fixtures/wallpaper.svg').toString().replace('file://','');
            mock.state = Object.assign({}, mock.state, {wallpapers:[first,second],wallpaperSelected:first});
            island.page = 'wallpapers'; wait(180);
            const carousel = findChild(island, 'selector-carousel');
            compare(carousel.currentIndex, 0);
            verify(findChild(island, 'applied-dot-' + first).visible);
            commands.clear();
            mouseClick(findChild(island, 'selector-card-' + second));
            compare(carousel.currentIndex, 1);
            verify(findChild(island, 'applied-dot-' + first).visible);
            verify(!findChild(island, 'applied-dot-' + second).visible);
            compare(commands.count, 0);
            compare(findChild(island, 'wallpaper-filename').text, 'wallpaper.svg');
            keyClick(Qt.Key_Return);
            compare(commands.signalArguments[0][0], 'wallpaper');
            compare(commands.signalArguments[0][1], second);
            mock.state = Object.assign({}, mock.state, {wallpaperSelected:second});
            tryCompare(findChild(island, 'applied-dot-' + second), 'visible', true);
            verify(!findChild(island, 'applied-dot-' + first).visible);
        }
        function test_contents_stay_visible_during_every_close_data() {
            let cases = [];
            for (const gameMode of [false, true])
                for (const page of ['glance', 'calendar', 'control', 'wifi', 'power', 'themes'])
                    for (const method of ['shortcut', 'dismiss'])
                        cases.push({tag:page + '-' + method + '-' + gameMode,page:page,gameMode:gameMode,method:method});
            return cases;
        }
        function test_contents_stay_visible_during_every_close(data) {
            Style.settings = Object.assign({}, Style.settings, {gameMode:data.gameMode});
            island.page = data.page; wait(180);
            const content = findChild(island, 'expanded-content');
            const openWidth = content.width;
            verify(content.visible);
            if (data.method === 'shortcut') island.toggle(data.page);
            else island.requestPage(''); // Also used by outside-click dismissal and Escape.
            compare(island.page, '');
            wait(25);
            compare(island.visualPage, data.page);
            verify(content.visible);
            verify(content.opacity > 0 && content.opacity < 1);
            verify(!content.enabled);
            fuzzyCompare(content.width, openWidth, .1);
            verify(island.geometryAnimating);
            tryCompare(island, 'visualPage', '');
            verify(!content.visible);
        }
        function test_media_contents_stay_visible_during_close() {
            for (const gameMode of [false, true]) {
                Style.settings = Object.assign({}, Style.settings, {gameMode:gameMode});
                island.page = 'media'; wait(180);
                const card = findChild(island, gameMode ? 'media-game-card' : 'media-card');
                verify(card.visible);
                island.requestPage(''); wait(25);
                verify(card.visible);
                verify(island.geometryAnimating);
                tryCompare(island, 'visualPage', '');
                wait(40); verify(!card.visible);
            }
        }
        function test_brightness_drag_survives_delayed_monitor_readings() {
            island.page = 'display'; wait(180);
            let slider = findChild(island, 'brightness-DP-1'); verify(slider !== null);
            mousePress(slider, slider.width * .8, 14);
            compare(Math.round(slider.shownValue), 80);
            mock.state = Object.assign({}, mock.state, {display:{brightness:45,monitors:[Object.assign({}, mock.state.display.monitors[0], {brightness:45})]}});
            wait(100);
            compare(findChild(island, 'brightness-DP-1'), slider);
            compare(Math.round(slider.shownValue), 80);
            mouseMove(slider, slider.width * .9, 14);
            mouseRelease(slider, slider.width * .9, 14);
            mock.state = Object.assign({}, mock.state, {display:{brightness:60,monitors:[Object.assign({}, mock.state.display.monitors[0], {brightness:60})]}});
            wait(100); compare(Math.round(slider.shownValue), 90);
            mock.state = Object.assign({}, mock.state, {display:{brightness:90,monitors:[Object.assign({}, mock.state.display.monitors[0], {brightness:90})]}});
            tryCompare(slider, 'previewing', false);
        }
        function test_media_unfolds_and_closes_at_artwork_corner() {
            wait(250); // Let the previous panel's position animation settle.
            // Leave enough time to observe the reveal before the open curve's overshoot.
            Style.settings = Object.assign({}, Style.settings, {movement:300});
            const circle = findChild(island, 'media-circle');
            const popup = findChild(island, 'media-popup');
            const corner = circle.x + circle.width;
            island.page = 'media';
            tryVerify(function() { return popup.reveal > 0.05 && popup.reveal < 0.95; }, 1000);
            fuzzyCompare(popup.x + popup.width, corner, .1);
            compare(island.hitArea, popup);
            tryCompare(popup, 'reveal', 1);
            island.page = '';
            wait(40);
            verify(popup.visible);
            verify(!circle.visible);
            fuzzyCompare(popup.x + popup.width, corner, .1);
            tryCompare(popup, 'reveal', 0);
            verify(circle.visible);
            verify(!popup.visible);
            fuzzyCompare(circle.x + circle.width, corner, .1);
        }
        function test_clock_stays_centered_during_expansion_and_collapse() {
            const panel = findChild(island, 'island-panel');
            const left = findChild(island, 'media-circle');
            const right = findChild(island, 'status-circle');
            for (const page of ['glance', '']) {
                island.page = page;
                for (let frame = 0; frame < 8; frame++) {
                    wait(20);
                    fuzzyCompare(panel.x + panel.width / 2, island.width / 2, .1);
                    fuzzyCompare(island.width / 2 - left.x - left.width / 2,
                                 right.x + right.width / 2 - island.width / 2, .1);
                }
            }
        }
        function test_wifi_unfolds_and_closes_at_status_corner() {
            const circle = findChild(island, 'status-circle');
            const popup = findChild(island, 'side-popup');
            const corner = circle.x;
            island.page = 'control';
            wait(40);
            verify(popup.reveal > 0 && popup.reveal < 1);
            fuzzyCompare(popup.x, corner, .1);
            compare(island.hitArea, popup);
            tryCompare(popup, 'reveal', 1);
            island.page = '';
            wait(40);
            verify(popup.visible);
            verify(!circle.visible);
            fuzzyCompare(popup.x, corner, .1);
            tryCompare(popup, 'reveal', 0);
            tryCompare(circle, 'visible', true);
            fuzzyCompare(circle.x, corner, .1);
        }
        function test_surface_size_stays_stable_across_pages() {
            const height = island.surfaceHeight;
            for (const page of ['glance','calendar','media','control','wifi','display','']) {
                island.page = page; wait(140);
                compare(island.surfaceHeight, height);
            }
        }
    }
}
