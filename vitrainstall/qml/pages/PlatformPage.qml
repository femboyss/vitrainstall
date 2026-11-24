// page 1: Linux / Windows / Mac - (c) 2026 34 & Claude
import QtQuick
import "../components"

Item {
    property var app
    readonly property var options: [
        { k: "linux",   key: "Super", mouse: "two" },
        { k: "windows", key: "Win",   mouse: "two" },
        { k: "mac",     key: "Cmd",   mouse: "one" }
    ]
    property string hovered: ""
    readonly property string shown: hovered !== "" ? hovered : (app.platform !== "" ? app.platform : "linux")

    Column {
        anchors.centerIn: parent
        spacing: 22
        width: 980

        Text { text: app.t("platform_title"); color: Theme.text; font.family: Theme.font; font.pixelSize: 34; font.weight: Font.Bold }
        Text { width: parent.width; wrapMode: Text.WordWrap; text: app.t("platform_sub")
               color: Theme.muted; font.family: Theme.font; font.pixelSize: 15 }

        Row {
            spacing: 20
            Repeater {
                model: options
                GlassCard {
                    id: card
                    width: 313; height: 300; hoverable: true
                    selected: app.platform === modelData.k
                    onClicked: app.platform = modelData.k
                    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                                onEntered: hovered = modelData.k; onExited: if (hovered === modelData.k) hovered = "" }
                    Column {
                        anchors.fill: parent; anchors.margins: 22; spacing: 14
                        Text { text: app.t("p_" + modelData.k); color: Theme.text; font.family: Theme.font; font.pixelSize: 24; font.weight: Font.Bold }
                        Text { text: app.t("p_" + modelData.k + "_desc"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 13 }
                        Row {
                            spacing: 26
                            topPadding: 10
                            Column {
                                spacing: 8
                                Text { text: app.t("key_main"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                                KeyCap { label: modelData.key; lit: card.selected }
                            }
                            MouseIcon { style: modelData.mouse; lit: card.selected ? "right" : (hovered === modelData.k ? "left" : "") }
                        }
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap
                            text: modelData.mouse === "one" ? app.t("mac_click") + " / " + app.t("mac_secondary")
                                                            : app.t("left_click") + " / " + app.t("right_click")
                            color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                        }
                    }
                }
            }
        }

        GlassCard {
            width: parent.width; height: 56
            Text {
                anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20
                verticalAlignment: Text.AlignVCenter; wrapMode: Text.WordWrap
                text: app.t("hint_" + shown); color: Theme.text; font.family: Theme.font; font.pixelSize: 14
            }
        }
    }
}
