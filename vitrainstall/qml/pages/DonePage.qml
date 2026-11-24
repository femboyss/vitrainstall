// page 7: done or failed - (c) 2026 34 & Claude
import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: done
    property var app
    property string log: ""
    // refresh the log whenever we land here after a failed install
    onVisibleChanged: if (visible && !app.installOk) log = backend.failureLog()

    Column {
        anchors.centerIn: parent
        spacing: 16
        width: 760
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 84; height: 84; radius: 42
            color: app.installOk ? Qt.rgba(0.22, 0.77, 0.73, 0.18) : Qt.rgba(1, 0.36, 0.45, 0.18)
            border.color: app.installOk ? Theme.accent : Theme.danger; border.width: 2
            Text { anchors.centerIn: parent; text: app.installOk ? "OK" : "!"; color: app.installOk ? Theme.accent : Theme.danger
                   font.family: Theme.font; font.pixelSize: 30; font.weight: Font.Black }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.t(app.installOk ? "done_title" : "fail_title")
               color: Theme.text; font.family: Theme.font; font.pixelSize: 32; font.weight: Font.Bold }
        Text { visible: app.installOk; width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
               text: app.t("done_sub"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 16 }

        // ---- failed: what went wrong, in plain words + the end of the log
        Text { visible: !app.installOk && app.installError !== ""; width: parent.width
               horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
               text: app.t("err_" + app.installError); color: Theme.danger; font.family: Theme.font; font.pixelSize: 15 }
        Text { visible: !app.installOk && done.log !== ""; text: app.t("what_happened")
               color: Theme.muted; font.family: Theme.font; font.pixelSize: 13 }
        ScrollView {
            visible: !app.installOk && done.log !== ""
            width: parent.width; height: 210; clip: true
            TextArea { readOnly: true; text: done.log; wrapMode: TextEdit.WrapAnywhere
                       color: Theme.text; font.family: "monospace"; font.pixelSize: 11
                       background: Rectangle { color: Qt.rgba(0, 0, 0, 0.4); radius: 10; border.color: Theme.border } }
        }
        Text { visible: !app.installOk; anchors.horizontalCenter: parent.horizontalCenter
               text: app.t("fail_sub") + "  " + backend.logPath
               color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 14
            Button2 { visible: !app.installOk; text: app.t("try_again")
                      onClicked: { app.go(6); backend.install(app.choices()) } }
            Button2 { visible: !app.installOk; kind: "ghost"; text: app.t("back"); onClicked: app.go(5) }
            Button2 { visible: !app.installOk; kind: "ghost"; text: app.t("quit"); onClicked: backend.quit() }
            Button2 { visible: app.installOk; text: app.t("reboot"); onClicked: backend.reboot() }
        }
    }
}
