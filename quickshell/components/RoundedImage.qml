import QtQuick
import QtQuick.Effects

Item {
    id: root
    property url source
    property real radius: Math.min(width, height) / 2
    property real blur: 0
    property int textureSize: 256
    readonly property alias status: artwork.status
    Image {
        id: artwork
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.textureSize, root.textureSize)
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        asynchronous: true
        visible: false
    }
    Rectangle {
        id: roundedMask
        anchors.fill: parent
        radius: root.radius
        color: 'white'
        antialiasing: true
        layer.smooth: true
        layer.enabled: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: artwork
        maskEnabled: true
        maskSource: roundedMask
        // Preserve the mask's antialiased coverage instead of thresholding it.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.5
        autoPaddingEnabled: false
        blurEnabled: root.blur > 0
        blur: root.blur
        blurMax: 32
    }
}
