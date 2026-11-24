// labelled text field - (c) 2026 34 & Claude
import QtQuick
import QtQuick.Controls

Column {
    id: f
    property alias text: input.text
    property alias placeholder: input.placeholderText
    property alias echoMode: input.echoMode
    property alias validator: input.validator
    property string label: ""
    property string hint: ""
    property bool bad: false
    signal edited()
    spacing: 6
    width: 360
    Text { text: f.label; color: Theme.muted; font.family: Theme.font; font.pixelSize: 13 }
    TextField {
        id: input
        width: parent.width
        height: 44
        color: Theme.text
        placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
        font.family: Theme.font
        font.pixelSize: 15
        leftPadding: 14
        selectByMouse: true
        onTextEdited: f.edited()
        background: Rectangle {
            radius: 12
            color: Qt.rgba(0, 0, 0, 0.25)
            border.width: input.activeFocus ? 2 : 1
            border.color: f.bad ? Theme.danger : (input.activeFocus ? Theme.accent : Theme.border)
        }
    }
    Text {
        visible: f.hint !== ""
        text: f.hint
        color: f.bad ? Theme.danger : Theme.muted
        font.family: Theme.font
        font.pixelSize: 12
        width: parent.width
        wrapMode: Text.WordWrap
    }
}
