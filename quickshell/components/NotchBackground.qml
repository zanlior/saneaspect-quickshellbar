import QtQuick
import QtQuick.Shapes

Shape {
    id: root
    property color color: 'black'
    property real cornerRadius: 14
    readonly property real shoulder: Math.min(12, height / 3, width / 6)
    readonly property real bottomRadius: Math.min(cornerRadius, height / 2, (width - 2 * shoulder) / 2)
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true
    ShapePath {
        strokeWidth: -1
        fillColor: root.color
        startX: 0; startY: 0
        PathLine { x: root.width; y: 0 }
        PathQuad { x: root.width - root.shoulder; y: root.shoulder; controlX: root.width - root.shoulder; controlY: 0 }
        PathLine { x: root.width - root.shoulder; y: root.height - root.bottomRadius }
        PathQuad { x: root.width - root.shoulder - root.bottomRadius; y: root.height; controlX: root.width - root.shoulder; controlY: root.height }
        PathLine { x: root.shoulder + root.bottomRadius; y: root.height }
        PathQuad { x: root.shoulder; y: root.height - root.bottomRadius; controlX: root.shoulder; controlY: root.height }
        PathLine { x: root.shoulder; y: root.shoulder }
        PathQuad { x: 0; y: 0; controlX: root.shoulder; controlY: 0 }
    }
}
