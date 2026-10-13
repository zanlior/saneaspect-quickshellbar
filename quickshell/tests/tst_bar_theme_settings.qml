import QtQuick
import QtTest
import ".."

Item {
    width: 1200; height: 900
    QtObject {
        id: mock
        property var state: ({})
        signal commandSent(string action, var value, var extra)
        function send(action, value, extra) { commandSent(action, value, extra); }
    }
    Settings { id: settings; anchors.fill: parent; bridge: mock }
    SignalSpy { id: commands; target: mock; signalName: 'commandSent' }
    TestCase {
        name: 'BarThemeSettings'
        when: windowShown
        property var defaults
        function initTestCase() { defaults = Object.assign({}, Style.settings); }
        function init() {
            Style.settings = Object.assign({}, defaults, {theme:'monochrome', barTheme:'apple', notch:false});
            commands.clear();
        }
        function cleanupTestCase() { Style.settings = defaults; }
        function test_settings_only_changes_mode() {
            const notch = findChild(settings, 'settings-toggle-notch');
            verify(notch.visible);
            verify(settings.fields['Bar & Island'].every(field => field[0] !== 'barTheme'));
            mouseClick(notch);
            compare(Style.settings.barTheme, 'apple');
            compare(Style.settings.notch, true);
            compare(commands.signalArguments[0][1], 'notch');
            compare(Style.settings.theme, 'monochrome');
            compare(commands.count, 1);
        }
    }
}
