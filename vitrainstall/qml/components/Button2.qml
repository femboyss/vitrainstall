// button: kind = "primary" | "ghost" | "danger" - (c) 2026 34 & Claude
import QtQuick

Rectangle {
    id: b
    property string text: ""
    property string kind: "primary"
    property bool enabled2: true
    signal clicked()
    implicitWidth: Math.max(140, label.implicitWidth + 48)
    implicitHeight: 46
    radius: 23
    opacity: enabled2 ? 1 : 0.4
    color: kind === "primary" ? (ma.pressed ? Qt.darker(Theme.accent, 1.2) : Theme.accent)
         : kind === "danger" ? (ma.pressed ? Qt.darker(Theme.danger, 1.2) : Theme.danger)
         : (ma.containsMouse ? Theme.glassHi : "transparent")
    border.width: kind === "ghost" ? 1 : 0
    border.color: Theme.border
    scale: ma.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
    Text {
        id: label
        anchors.centerIn: parent
        text: b.text
        color: b.kind === "ghost" ? Theme.text : "#061014"
        font.family: Theme.font
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: b.enabled2 ? Qt.PointingHandCursor : Qt.ForbiddenCursor
        onClicked: if (b.enabled2) b.clicked()
    }
}
