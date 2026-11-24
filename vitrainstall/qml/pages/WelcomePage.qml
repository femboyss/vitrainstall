// page 0: welcome + language - (c) 2026 34 & Claude
import QtQuick
import "../components"

Item {
    property var app
    property bool online: true
    Component.onCompleted: online = backend.hasInternet()

    Column {
        anchors.centerIn: parent
        spacing: 26
        width: 640

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Vitra<font color='" + Theme.accent + "'>.</font>"
            textFormat: Text.StyledText
            color: Theme.text; font.family: Theme.font; font.pixelSize: 96; font.weight: Font.Black
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: app.t("welcome_title"); color: Theme.text
            font.family: Theme.font; font.pixelSize: 30; font.weight: Font.DemiBold
        }
        Text {
            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            text: app.t("welcome_sub"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 17
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            Repeater {
                model: [{ k: "de", n: "Deutsch" }, { k: "en", n: "English" }]
                GlassCard {
                    width: 170; height: 54; hoverable: true
                    selected: app.language === modelData.k
                    onClicked: { app.language = modelData.k; app.keyboard = modelData.k === "de" ? "at" : "us" }
                    Text { anchors.centerIn: parent; text: modelData.n; color: Theme.text
                           font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                }
            }
        }
        GlassCard {
            visible: !online
            width: parent.width; height: warn.implicitHeight + 70
            border.color: Theme.danger
            Column {
                anchors.fill: parent; anchors.margins: 18; spacing: 10
                Text { id: warn; width: parent.width; wrapMode: Text.WordWrap; text: app.t("no_internet")
                       color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
                Button2 { kind: "ghost"; text: app.t("retry"); height: 36; onClicked: online = backend.hasInternet() }
            }
        }
        Button2 {
            anchors.horizontalCenter: parent.horizontalCenter
            text: app.t("start") + "  ->"
            enabled2: online
            onClicked: app.go(1)
        }
    }
}
