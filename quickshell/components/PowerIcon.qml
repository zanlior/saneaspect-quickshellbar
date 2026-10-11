import QtQuick
import QtQuick.Effects
import ".."

Image {
    id: root
    property string name: 'lock'
    property color color: Style.text
    property string iconName: name
    source: iconName ? Qt.resolvedUrl('../assets/icons/' + iconName + '.svg') : ''
    sourceSize: Qt.size(width * 2, height * 2)
    smooth: true
    mipmap: true
    layer.enabled: true
    layer.effect: MultiEffect {
        colorization: 1
        colorizationColor: root.color
    }
}
