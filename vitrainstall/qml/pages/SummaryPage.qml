// page 5: summary + install button - (c) 2026 34 & Claude
import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: sp
    property var app
    property bool confirm: false
    property bool details: false

    readonly property var rows: [
        ["sum_lang", app.language === "de" ? "Deutsch" : "English"],
        ["sum_platform", app.platform !== "" ? app.t("p_" + app.platform) : "-"],
        ["sum_keyboard", app.keyboard],
        ["sum_tz", app.timezone],
        ["sum_disk", app.disk ? app.disk.path + "  (" + app.disk.model + ", " + app.disk.sizeText + ")" : "-"],
        ["sum_fs", app.filesystem],
        ["sum_gpu", app.gfxDriver],
        ["sum_user", app.fullname !== "" ? app.fullname + "  (" + app.username + ")" : app.username],
        ["sum_host", app.hostname]
    ]

    Column {
        anchors.centerIn: parent
        spacing: 16
        width: 760
        Text { text: app.t("sum_title"); color: Theme.text; font.family: Theme.font; font.pixelSize: 34; font.weight: Font.Bold }
        Text { text: app.t("sum_sub"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 15 }
        GlassCard {
            width: parent.width; height: col.implicitHeight + 32
            Column {
                id: col
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16
                spacing: 9
                Repeater {
                    model: sp.rows
                    Row {
                        spacing: 16
                        Text { width: 190; text: app.t(modelData[0]); color: Theme.muted; font.family: Theme.font; font.pixelSize: 14 }
                        Text { text: modelData[1]; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                    }
                }
            }
        }
        Text {
            text: (details ? "v  " : ">  ") + app.t("sum_details"); color: Theme.accent; font.family: Theme.font; font.pixelSize: 13
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: details = !details }
        }
        ScrollView {
            visible: details; width: parent.width; height: 170; clip: true
            TextArea { readOnly: true; text: details ? backend.summary(app.choices()) : ""; color: Theme.muted
                       font.family: "monospace"; font.pixelSize: 11; background: Rectangle { color: Qt.rgba(0, 0, 0, 0.3); radius: 10 } }
        }
        Row {
            spacing: 14
            visible: !confirm
            Button2 { kind: "ghost"; text: app.t("back"); onClicked: app.go(4) }
            Button2 { kind: "danger"; text: app.t("install"); onClicked: confirm = true }
        }
        GlassCard {
            visible: confirm; width: parent.width; height: 110; border.color: Theme.danger
            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 12
                Text { text: app.tf("install_confirm", app.disk ? app.disk.path : ""); color: Theme.text
                       font.family: Theme.font; font.pixelSize: 16; font.weight: Font.Bold }
                Row {
                    spacing: 12
                    Button2 { kind: "ghost"; text: app.t("cancel"); onClicked: confirm = false }
                    Button2 { kind: "danger"; text: app.t("yes_install")
                              onClicked: { confirm = false; app.go(6); backend.install(app.choices()) } }
                }
            }
        }
    }
}
