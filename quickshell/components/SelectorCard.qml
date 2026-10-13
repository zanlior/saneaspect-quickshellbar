import QtQuick
import ".."

Item {
    id: root
    required property string entry
    property bool theme: true
    property bool bar: false
    property bool selected: false
    property bool applied: false
    signal selectedByClick()
    signal appliedByClick()
    width: theme ? 190 : 152
    height: bar ? 92 : theme ? 122 : 106
    RoundedPanel {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.bar ? 0 : root.selected ? 0 : root.theme ? 8 : 4
        width: root.theme ? 190 : root.selected ? 152 : 140
        height: root.bar ? 92 : root.theme ? 102 : root.selected ? 90 : 82
        radius: root.theme ? 14 : 11
        color: root.bar ? Style.card : root.theme ? root.entry === 'ariadne' ? '#061310' : (Style.palettes[root.entry] || Style.palettes.ariadne)[1] : Style.card
        Behavior on y { NumberAnimation { duration: Style.settings.reduceMotion ? 0 : Style.settings.hover; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Style.settings.reduceMotion ? 0 : Style.settings.hover; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Style.settings.reduceMotion ? 0 : Style.settings.hover; easing.type: Easing.OutCubic } }
        Image {
            visible: !root.theme
            anchors.fill: parent
            source: root.theme ? '' : 'file://' + root.entry
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            mipmap: true
            sourceSize: Qt.size(320, 200)
        }
        Row {
            visible: root.theme && !root.bar
            anchors.horizontalCenter: parent.horizontalCenter
            y: 35
            spacing: 5
            Repeater {
                model: root.theme ? Style.themeSamples[root.entry] || [] : []
                Rectangle { required property string modelData; width: 14; height: 14; radius: 7; color: modelData; antialiasing: true }
            }
        }
        Rectangle {
            visible: root.bar
            x: 12; y: 10; width: parent.width - 24; height: 48
            radius: 8; color: Style.panel
            Row {
                visible: root.entry === 'Workspace'
                anchors.centerIn: parent
                spacing: 15
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Repeater {
                        model: 5
                        Rectangle {
                            required property int index
                            width: 4; height: index === 1 ? 11 : 6
                            radius: 2
                            color: Style.accent
                            opacity: index === 1 ? 1 : .55
                        }
                    }
                }
                Label { text: '12:30'; font.pixelSize: 12 }
                Icon { name: 'wifi'; width: 13; height: 13; color: Style.accent }
            }
            Row {
                visible: root.entry === 'Dock'
                anchors.centerIn: parent
                spacing: 8
                Rectangle { width: 18; height: 18; radius: 9; color: Style.bg }
                Rectangle {
                    width: 58; height: 20; radius: 10; color: Style.bg
                    Label { anchors.centerIn: parent; text: '12:30'; font.pixelSize: 9 }
                }
                Rectangle {
                    width: 18; height: 18; radius: 9; color: Style.bg
                    Icon { anchors.centerIn: parent; name: 'wifi'; width: 11; height: 11; color: Style.accent }
                }
            }
        }
        Label {
            visible: root.theme
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 9
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.entry
            color: root.bar ? Style.text : (Style.palettes[root.entry] || Style.palettes.ariadne)[3]
            opacity: root.selected ? 1 : .75
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }
    }
    Rectangle {
        x: body.x; y: body.y; width: body.width; height: body.height
        radius: body.radius
        color: 'transparent'
        border.width: root.selected ? 2 : root.theme ? 1 : 0
        border.color: root.selected ? Style.accent : Qt.rgba(1, 1, 1, .06)
        antialiasing: true
    }
    Rectangle {
        objectName: 'applied-dot-' + root.entry
        visible: root.applied
        x: body.x + body.width - width - 9
        y: body.y + 9
        width: root.theme ? 6 : 5
        height: width
        radius: width / 2
        color: Style.accent
        antialiasing: true
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.selectedByClick()
        onDoubleClicked: root.appliedByClick()
    }
}
