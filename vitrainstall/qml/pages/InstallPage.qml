// page 6: progress - (c) 2026 34 & Claude
import QtQuick
import QtQuick.Controls
import "../components"

Item {
    property var app
    property bool showLog: false
    property string lines: ""
    property string lastLine: ""
    Connections {
        target: backend
        function onLogLine(l) { lines += l + "\n"; lastLine = l.trim() }
        function onFinished(ok, err) { app.installOk = ok; app.installError = err; app.go(7) }
    }

    Column {
        anchors.centerIn: parent
        spacing: 22
        width: 720
        Text { text: app.t("inst_title"); color: Theme.text; font.family: Theme.font; font.pixelSize: 34; font.weight: Font.Bold }
        Text { text: app.t("inst_sub"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 15 }
        Rectangle {
            id: bar
            width: parent.width; height: 14; radius: 7; color: Qt.rgba(1, 1, 1, 0.08); clip: true
            Rectangle {
                width: parent.width * backend.progress / 100; height: parent.height; radius: 7
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.accent } GradientStop { position: 1; color: Theme.accent2 } }
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
            // a light that keeps moving: the installer is alive even when a step takes long
            Rectangle {
                visible: backend.running; width: 90; height: parent.height; radius: 7
                color: Qt.rgba(1, 1, 1, 0.22)
                NumberAnimation on x { from: -90; to: bar.width; duration: 1800; loops: Animation.Infinite; running: backend.running }
            }
        }
        Item {
            width: parent.width; height: 24
            Text { anchors.left: parent.left; text: app.t("step_" + backend.step); color: Theme.text; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.DemiBold }
            Text { anchors.right: parent.right; text: backend.progress + " %"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold }
        }
        // what is happening right now (last line of the log)
        Text {
            width: parent.width; text: lastLine; elide: Text.ElideRight; visible: lastLine !== ""
            color: Theme.muted; font.family: "monospace"; font.pixelSize: 12
        }
        Text {
            text: showLog ? app.t("hide_log") : app.t("show_log"); color: Theme.accent; font.family: Theme.font; font.pixelSize: 13
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showLog = !showLog }
        }
        ScrollView {
            visible: showLog; width: parent.width; height: 260; clip: true
            TextArea { readOnly: true; text: lines; color: Theme.muted; font.family: "monospace"; font.pixelSize: 11
                       background: Rectangle { color: Qt.rgba(0, 0, 0, 0.35); radius: 10 }
                       onTextChanged: cursorPosition = length }
        }
    }
}
