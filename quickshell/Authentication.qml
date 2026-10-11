import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import "components"

Scope {
    id: root
    PolkitAgent {
        id: agent
    }
    PanelWindow {
        visible: agent.isActive
        anchors.top: true
        margins.top: Style.settings.edgeGap
        implicitWidth: 460
        implicitHeight: 300
        color: 'transparent'
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: 'island-authentication'
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        Rectangle {
            anchors.fill: parent
            radius: Style.settings.expandedRadius
            color: Style.bg
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12
                RowLayout {
                    Icon {
                        name: 'lock'
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        color: Style.accent
                    }
                    Label {
                        text: 'Authentication required'
                        font.pixelSize: 18
                        Layout.fillWidth: true
                    }
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: agent.flow ? agent.flow.message : ''
                }
                Label {
                    Layout.fillWidth: true
                    text: agent.flow ? agent.flow.actionId : ''
                    font.pixelSize: 11
                    color: Style.muted
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    visible: !!text
                    text: agent.flow ? agent.flow.supplementaryMessage : ''
                    color: agent.flow && agent.flow.supplementaryIsError ? '#f48771' : Style.muted
                    font.pixelSize: 12
                }
                Field {
                    id: password
                    Layout.fillWidth: true
                    enabled: !!agent.flow && agent.flow.isResponseRequired
                    placeholderText: agent.flow ? agent.flow.inputPrompt : 'Password'
                    echoMode: agent.flow && agent.flow.responseVisible ? TextInput.Normal : TextInput.Password
                    onAccepted: submit()
                    function submit() {
                        if (agent.flow && agent.flow.isResponseRequired) {
                            agent.flow.submit(text);
                            text = '';
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                }
                RowLayout {
                    Item {
                        Layout.fillWidth: true
                    }
                    Chip {
                        text: 'Cancel'
                        onClicked: {
                            password.text = '';
                            if (agent.flow)
                                agent.flow.cancelAuthenticationRequest();
                        }
                    }
                    Chip {
                        text: 'Authenticate'
                        active: true
                        enabled: password.enabled
                        onClicked: password.submit()
                    }
                }
            }
        }
        onVisibleChanged: if (visible) {
            password.text = '';
            Qt.callLater(() => password.forceActiveFocus());
        }
    }
}
