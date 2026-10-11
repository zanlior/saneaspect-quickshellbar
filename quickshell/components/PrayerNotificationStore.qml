import QtQuick

QtObject {
    id: root
    property var notifications: []
    signal dismissed(var notification)

    function post(message) {
        const note = {
            appName: 'Prayer times',
            summary: message.summary,
            body: message.body,
            actions: [],
            dismiss: () => root.remove(note)
        };
        notifications = [note].concat(notifications).slice(0, 50);
        return note;
    }

    function remove(note) {
        notifications = notifications.filter(n => n !== note);
        dismissed(note);
    }
}
