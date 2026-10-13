import QtQuick
import QtTest
import ".."

Item {
    id: scene
    width: 1440
    height: 900

    QtObject {
        id: mock
        property var state: ({
            media: {
                id: 'spotify:one', title: 'First', artist: 'Artist', player: 'Spotify',
                playing: true,
                players: [
                    {id: 'spotify:one', title: 'First', artist: 'Artist', player: 'Spotify', playing: true},
                    {id: 'firefox:two', title: 'Second', artist: 'Artist', player: 'Firefox', playing: false}
                ]
            },
            wifi: {enabled:true, networks:[]},
            bluetooth: {enabled:true, devices:[]},
            audio: {outputs:[], inputs:[], apps:[]},
            display: {brightness:40, monitors:[]}
        })
        property var notifications: []
        property string error: ''
        signal commandSent(string action, var value, var extra)
        function send(action, value, extra) { commandSent(action, value, extra); }
        function clearNotifications() {}
        function dismiss() {}
    }

    Island { id: island; anchors.fill: parent; bridge: mock }
    SignalSpy { id: commands; target: mock; signalName: 'commandSent' }

    TestCase {
        name: 'KeyboardControls'
        when: windowShown
        property var defaults
        function initTestCase() { defaults = Object.assign({}, Style.settings); }
        function init() {
            island.requestPage('');
            Style.settings = Object.assign({}, defaults, {movement:100, hover:80, reduceMotion:false});
            mock.state = Object.assign({}, mock.state, {media: {
                id:'spotify:one', title:'First', artist:'Artist', player:'Spotify', playing:true,
                players:[
                    {id:'spotify:one',title:'First',artist:'Artist',player:'Spotify',playing:true},
                    {id:'firefox:two',title:'Second',artist:'Artist',player:'Firefox',playing:false}
                ]
            }});
            mouseMove(scene, 20, 700);
            wait(220);
            commands.clear();
        }

        function test_media_space_targets_visible_player_once() {
            island.page = 'media';
            tryCompare(island, 'page', 'media');
            wait(180);
            commands.clear();
            keyClick(Qt.Key_Space);
            compare(commands.count, 1);
            compare(commands.signalArguments[0][0], 'media');
            compare(commands.signalArguments[0][1], 'play-pause');
            compare(commands.signalArguments[0][2], 'spotify:one');
        }

        function test_media_space_works_in_dock_notch_workspace_and_game_layouts() {
            const layouts = [
                {barTheme:'apple', notch:false, gameMode:false},
                {barTheme:'apple', notch:true, gameMode:false},
                {barTheme:'workspace', notch:false, gameMode:false},
                {barTheme:'apple', notch:false, gameMode:true}
            ];
            for (const layout of layouts) {
                island.requestPage('');
                Style.settings = Object.assign({}, Style.settings, layout);
                wait(120);
                commands.clear();
                island.page = 'media';
                wait(220);
                commands.clear();
                keyClick(Qt.Key_Space);
                compare(commands.count, 1, JSON.stringify(layout));
                compare(commands.signalArguments[0][2], 'spotify:one', JSON.stringify(layout));
            }
        }

        function test_media_left_wraps_from_first_to_last_player() {
            island.page = 'media';
            wait(180);
            const card = findChild(island, 'media-card') || findChild(island, 'media-game-card');
            keyClick(Qt.Key_Left);
            wait(460);
            compare(card.selectedPlayer, 'firefox:two');
            commands.clear();
            keyClick(Qt.Key_Space);
            compare(commands.count, 1);
            compare(commands.signalArguments[0][2], 'firefox:two');
        }

        function test_layout_change_keeps_media_keyboard_target() {
            island.page = 'media';
            wait(180);
            Style.settings = Object.assign({}, Style.settings, {barTheme:'workspace'});
            wait(180);
            commands.clear();
            keyClick(Qt.Key_Space);
            compare(commands.count, 1);
            compare(commands.signalArguments[0][2], 'spotify:one');
        }

        function test_opening_media_from_launcher_search_routes_space_to_media() {
            island.requestPage('launcher');
            wait(180);
            island.requestPage('media');
            wait(240);
            commands.clear();
            keyClick(Qt.Key_Space);
            compare(commands.count, 1);
            compare(commands.signalArguments[0][0], 'media');
        }

        function test_media_space_without_a_player_sends_no_command() {
            mock.state = Object.assign({}, mock.state, {media:{title:'', player:'', id:'', players:[]}});
            island.page = 'media';
            wait(180);
            commands.clear();
            keyClick(Qt.Key_Space);
            compare(commands.count, 0);
        }

        function test_media_navigation_changes_the_target_before_space() {
            island.page = 'media';
            wait(180);
            commands.clear();
            keyClick(Qt.Key_Right);
            keyClick(Qt.Key_Space);
            compare(commands.count, 0);
            wait(460);
            keyClick(Qt.Key_Space);
            compare(commands.count, 1);
            compare(commands.signalArguments[0][0], 'media');
            compare(commands.signalArguments[0][1], 'play-pause');
            compare(commands.signalArguments[0][2], 'firefox:two');
        }

        function test_power_opens_on_lock_and_enter_uses_lock_action() {
            island.requestPage('launcher');
            wait(180);
            island.requestPage('power');
            wait(180);
            keyClick(Qt.Key_Return);
            compare(island.page, '');
            compare(commands.signalArguments.filter(args => args[0] === 'lock').length, 1);
            compare(commands.signalArguments.filter(args => args[0] === 'power').length, 0);
        }

        function test_power_entry_replaces_hidden_theme_search_focus() {
            island.requestPage('themes');
            wait(180);
            island.requestPage('power');
            wait(180);
            keyClick(Qt.Key_Down);
            compare(island.powerIndex, 1);
        }

        function test_power_navigation_wraps_and_confirmation_requires_second_press() {
            island.page = 'power';
            wait(180);
            // Lock is initially selected. Down chooses Suspend and arms confirmation.
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            compare(island.page, 'power');
            compare(commands.signalArguments.filter(args => args[0] === 'power').length, 0);
            // Navigation cancels the armed action and moves to Log Out.
            keyClick(Qt.Key_Right);
            keyClick(Qt.Key_Return);
            compare(island.page, 'power');
            keyClick(Qt.Key_Return);
            compare(island.page, '');
            const power = commands.signalArguments.filter(args => args[0] === 'power');
            compare(power.length, 1);
            compare(power[0][1], 'logout');
        }

        function test_power_wraps_and_resets_to_lock_each_time_it_opens() {
            island.page = 'power';
            wait(180);
            compare(island.powerIndex, 0);
            keyClick(Qt.Key_Up);
            compare(island.powerIndex, 4);
            keyClick(Qt.Key_Return);
            compare(island.powerConfirm, 'poweroff');
            island.requestPage('');
            wait(180);
            island.requestPage('power');
            wait(180);
            compare(island.powerIndex, 0);
            compare(island.powerConfirm, '');
        }

        function test_keyboard_power_selection_remains_visible_over_hovered_card() {
            island.page = 'power';
            wait(180);
            const lock = findChild(island, 'power-lock');
            const suspend = findChild(island, 'power-suspend');
            const reboot = findChild(island, 'power-reboot');
            mouseMove(reboot, reboot.width / 2, reboot.height / 2);
            keyClick(Qt.Key_Down);
            compare(island.powerIndex, 1);
            compare(lock.border.width, 0);
            compare(suspend.border.width, 2);
            compare(reboot.border.width, 0);
        }

        function test_navigation_clears_confirmation_for_same_power_action() {
            island.page = 'power';
            wait(180);
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            compare(island.powerConfirm, 'suspend');
            keyClick(Qt.Key_Up);
            keyClick(Qt.Key_Down);
            compare(island.powerConfirm, '');
            keyClick(Qt.Key_Return);
            compare(island.page, 'power');
            compare(island.powerConfirm, 'suspend');
            compare(commands.signalArguments.filter(args => args[0] === 'power').length, 0);
        }

        function test_power_escape_closes_without_running_an_action() {
            island.page = 'power';
            wait(180);
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            keyClick(Qt.Key_Escape);
            compare(island.page, '');
            compare(commands.signalArguments.filter(args => args[0] === 'power').length, 0);
        }
    }
}
