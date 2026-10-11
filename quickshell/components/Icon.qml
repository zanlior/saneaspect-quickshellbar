import QtQuick

// All shell controls use the same SVG renderer as the power menu.
PowerIcon {
    name: 'wifi'
    readonly property var aliases: ({
        focus: 'circle-minus', game: 'gamepad-2', sound: 'volume-2',
        display: 'sun', night: 'suspend', media: 'music',
        previous: 'skip-back', next: 'skip-forward', input: 'mic',
        notifications: 'bell'
    })
    iconName: aliases[name] || name
    width: 22
    height: 22
}
