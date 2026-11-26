// page 0: welcome + language - (c) 2026 34 & Claude
import QtQuick
import "../components"

Item {
    id: welcome
    property var app
    property bool online: true
    property bool hasWifi: backend.wifiDevice() !== ""
    Component.onCompleted: online = backend.hasInternet()

    Column {
        anchors.centerIn: parent
        spacing: online ? 26 : 16
        width: 640

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "../assets/vitra-logo.png"
            width: online ? 132 : 84; height: width
            sourceSize.width: 512; sourceSize.height: 512
            smooth: true; mipmap: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Vitra<font color='" + Theme.accent + "'>.</font>"
            textFormat: Text.StyledText
            color: Theme.text; font.family: Theme.font; font.pixelSize: online ? 96 : 56; font.weight: Font.Black
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: app.t("welcome_title"); color: Theme.text
            font.family: Theme.font; font.pixelSize: 30; font.weight: Font.DemiBold
        }
        Text {
            visible: online
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
            width: parent.width; height: offline.implicitHeight + 36
            border.color: Theme.danger
            Column {
                id: offline
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 18
                spacing: 12
                Text { width: parent.width; wrapMode: Text.WordWrap; text: app.t("no_internet")
                       color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
                WifiPanel {
                    visible: hasWifi
                    width: parent.width
                    app: welcome.app
                    onOnline: welcome.online = true
                }
                Row {
                    spacing: 12
                    Button2 { kind: "ghost"; text: app.t("retry"); height: 36; onClicked: online = backend.hasInternet() }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: app.t("no_cable_hint")
                           color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                }
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
