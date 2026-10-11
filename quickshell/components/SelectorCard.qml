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
    height: theme ? 122 : 106
    RoundedPanel {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.selected ? 0 : root.theme ? 8 : 4
        width: root.theme ? 190 : root.selected ? 152 : 140
        height: root.theme ? 102 : root.selected ? 90 : 82
        radius: root.theme ? 14 : 11
        color: root.bar ? Style.panel : root.theme ? root.entry === 'ariadne' ? '#061310' : (Style.palettes[root.entry] || Style.palettes.ariadne)[1] : Style.card
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
            x: 14; y: 10; width: parent.width - 28; height: 57
            radius: 8; color: Style.card
            Rectangle {
                visible: root.entry === 'Dock'
                anchors.horizontalCenter: parent.horizontalCenter
                y: 9; width: 46; height: 16; radius: 8; color: Style.bg
            }
            NotchBackground {
                visible: root.entry === 'Notch'
                anchors.horizontalCenter: parent.horizontalCenter
                width: 94; height: 21; color: Style.bg; cornerRadius: 8
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.entry === 'Dock' ? 10 : 2
                text: '12:30'; font.pixelSize: 9
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
