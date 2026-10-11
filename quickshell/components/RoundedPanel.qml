import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: root
    property color color: 'transparent'
    property real radius: 0

    Rectangle {
        anchors.fill: parent
        color: root.color
    }

    // Mask the completed panel once, including its children during the morph.
    // CurveRenderer keeps the circular edge smooth without polygon segments.
    layer.enabled: true
    layer.smooth: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.5
        autoPaddingEnabled: false
        maskSource: Shape {
            id: roundedMask
            parent: root
            width: root.width
            height: root.height
            readonly property real r: Math.max(0, Math.min(root.radius, width / 2, height / 2))
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
            ShapePath {
                strokeWidth: -1
                fillColor: 'white'
                startX: roundedMask.r
                startY: 0
                PathLine { x: roundedMask.width - roundedMask.r; y: 0 }
                PathArc { x: roundedMask.width; y: roundedMask.r; radiusX: roundedMask.r; radiusY: roundedMask.r }
                PathLine { x: roundedMask.width; y: roundedMask.height - roundedMask.r }
                PathArc { x: roundedMask.width - roundedMask.r; y: roundedMask.height; radiusX: roundedMask.r; radiusY: roundedMask.r }
                PathLine { x: roundedMask.r; y: roundedMask.height }
                PathArc { x: 0; y: roundedMask.height - roundedMask.r; radiusX: roundedMask.r; radiusY: roundedMask.r }
                PathLine { x: 0; y: roundedMask.r }
                PathArc { x: roundedMask.r; y: 0; radiusX: roundedMask.r; radiusY: roundedMask.r }
            }
        }
    }
}
