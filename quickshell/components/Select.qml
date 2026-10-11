import QtQuick
import QtQuick.Controls
import ".."

ComboBox {
    id: root
    property Item popupBoundary: null
    readonly property real spaceAbove: popupBoundary ? Math.max(0, mapToItem(popupBoundary, 0, 0).y - 8) : 240
    readonly property real spaceBelow: popupBoundary ? Math.max(0, popupBoundary.height - mapToItem(popupBoundary, 0, height).y - 8) : 240
    readonly property bool popupAbove: !!popupBoundary && spaceBelow < Math.min(240, popup.contentItem.implicitHeight + 8) && spaceAbove > spaceBelow
    font.family: Style.uiFont
    implicitHeight: 36
    leftPadding: 12
    rightPadding: 30
    contentItem: Label {
        font.family: Style.uiFont
        color: Style.text
        text: root.displayText
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: 12
    }
    indicator: Icon {
        x: root.width - width - 12
        anchors.verticalCenter: parent.verticalCenter
        name: 'chevron-right'
        width: 14; height: 14
        rotation: 90
        color: Style.muted
    }
    background: Rectangle {
        color: Style.panel
        radius: 12
        border.color: Style.card
    }
    delegate: ItemDelegate {
        id: choice
        required property var modelData
        required property int index
        width: root.width
        contentItem: Label {
            font.family: Style.uiFont
            color: Style.text
            text: String(modelData)
            font.pixelSize: 12
        }
        background: Rectangle {
            color: choice.highlighted ? Style.card : Style.panel
            radius: 8
        }
        highlighted: root.highlightedIndex === index
    }
    popup: Popup {
        y: root.popupAbove ? -height - 4 : root.height + 4
        width: root.width
        padding: 4
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 240, root.popupBoundary ? (root.popupAbove ? root.spaceAbove : root.spaceBelow) : 240)
        background: Rectangle {
            color: Style.panel
            radius: 12
            border.color: Style.card
        }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
    }
}
