// page 7: done or failed - (c) 2026 34 & Claude
import QtQuick
import "../components"

Item {
    property var app
    Column {
        anchors.centerIn: parent
        spacing: 20
        width: 680
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96; height: 96; radius: 48
            color: app.installOk ? Qt.rgba(0.22, 0.77, 0.73, 0.18) : Qt.rgba(1, 0.36, 0.45, 0.18)
            border.color: app.installOk ? Theme.accent : Theme.danger; border.width: 2
            Text { anchors.centerIn: parent; text: app.installOk ? "OK" : "!"; color: app.installOk ? Theme.accent : Theme.danger
                   font.family: Theme.font; font.pixelSize: 34; font.weight: Font.Black }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.t(app.installOk ? "done_title" : "fail_title")
               color: Theme.text; font.family: Theme.font; font.pixelSize: 34; font.weight: Font.Bold }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
               text: app.t(app.installOk ? "done_sub" : "fail_sub"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 16 }
        Text { visible: !app.installOk; anchors.horizontalCenter: parent.horizontalCenter; text: backend.logPath
               color: Theme.text; font.family: "monospace"; font.pixelSize: 13 }
        Text { visible: !app.installOk && app.installError !== ""; anchors.horizontalCenter: parent.horizontalCenter
               text: app.t("err_" + app.installError); color: Theme.danger; font.family: Theme.font; font.pixelSize: 14 }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 14
            Button2 { visible: !app.installOk; kind: "ghost"; text: app.t("back"); onClicked: app.go(5) }
            Button2 { visible: !app.installOk; kind: "ghost"; text: app.t("quit"); onClicked: backend.quit() }
            Button2 { visible: app.installOk; text: app.t("reboot"); onClicked: backend.reboot() }
        }
    }
}
