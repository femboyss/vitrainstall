// preview of the bar the chosen platform gets (no brand logos) - (c) 2026 34 & Claude
import QtQuick

Item {
    id: bar
    property string platform: "linux"
    property string clock: Qt.formatTime(new Date(), "hh:mm")
    Timer { interval: 10000; running: true; repeat: true; onTriggered: bar.clock = Qt.formatTime(new Date(), "hh:mm") }

    // Linux: floating glassy bar at the top
    Rectangle {
        visible: bar.platform === "linux"
        anchors.top: parent.top; anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 24; height: 38; radius: 19
        color: Qt.rgba(1, 1, 1, 0.07); border.color: Theme.border
        Text { anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter
               text: "Vitra."; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Bold }
        Row {
            anchors.centerIn: parent; spacing: 8
            Repeater { model: 5; Rectangle { width: index === 0 ? 22 : 8; height: 8; radius: 4
                       color: index === 0 ? Theme.accent : Qt.rgba(1, 1, 1, 0.3) } }
        }
        Text { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
               text: bar.clock; color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
    }

    // Windows: taskbar at the bottom
    Rectangle {
        visible: bar.platform === "windows"
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 46
        color: Qt.rgba(0.05, 0.07, 0.11, 0.85)
        Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
        Row {
            anchors.centerIn: parent; spacing: 10
            Rectangle { width: 34; height: 34; radius: 8; color: Qt.rgba(0.22, 0.77, 0.73, 0.25)
                        Text { anchors.centerIn: parent; text: "V"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold } }
            Repeater { model: 4; Rectangle { width: 34; height: 34; radius: 8; color: Qt.rgba(1, 1, 1, 0.07) } }
        }
        Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
               text: bar.clock; color: Theme.text; font.family: Theme.font; font.pixelSize: 13 }
    }

    // Mac: thin menu bar at the top
    Rectangle {
        visible: bar.platform === "mac"
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 28
        color: Qt.rgba(0.05, 0.07, 0.11, 0.7)
        Row {
            anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 18
            Text { text: "Vitra"; color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Bold }
            Repeater { model: ["File", "Edit", "View", "Window"]; Text { text: modelData; color: Theme.muted; font.family: Theme.font; font.pixelSize: 13 } }
        }
        Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
               text: bar.clock; color: Theme.text; font.family: Theme.font; font.pixelSize: 13 }
    }
}
