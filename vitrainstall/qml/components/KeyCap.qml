// a keyboard key with a label (no brand logos) - (c) 2026 34 & Claude
import QtQuick

Rectangle {
    property string label: "Super"
    property bool lit: false
    width: Math.max(64, t.implicitWidth + 28)
    height: 52
    radius: 10
    color: lit ? Qt.rgba(0.22, 0.77, 0.73, 0.25) : "#151c28"
    border.color: lit ? Theme.accent : "#2a3546"
    border.width: 1
    Rectangle { // key "height"
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 6; radius: 10; color: Qt.rgba(0, 0, 0, 0.35); z: -1
    }
    Text {
        id: t
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        text: parent.label
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 16
        font.weight: Font.DemiBold
    }
}
