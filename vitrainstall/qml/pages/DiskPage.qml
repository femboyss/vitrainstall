// page 3: disk, file system, graphics driver - (c) 2026 34 & Claude
import QtQuick
import QtQuick.Controls
import "../components"

Item {
    property var app
    property var disks: []
    Component.onCompleted: disks = backend.disks()

    Column {
        anchors.centerIn: parent
        spacing: 16
        width: 860

        Text { text: app.t("disk_title"); color: Theme.text; font.family: Theme.font; font.pixelSize: 34; font.weight: Font.Bold }
        Text { text: app.t("disk_sub"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 15 }

        Text { visible: disks.length === 0; text: app.t("disk_none"); color: Theme.danger; font.family: Theme.font; font.pixelSize: 15 }
        Column {
            spacing: 10
            Repeater {
                model: disks
                GlassCard {
                    width: 860; height: 64; hoverable: true
                    selected: app.disk !== null && app.disk.path === modelData.path
                    onClicked: { app.disk = modelData; app.wipeConfirmed = false }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 20; spacing: 16
                        Rectangle { width: 36; height: 36; radius: 9; color: Qt.rgba(1, 1, 1, 0.08)
                                    Text { anchors.centerIn: parent; text: modelData.transport === "NVME" ? "NV" : (modelData.removable ? "USB" : "HD")
                                           color: Theme.accent; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Bold } }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelData.model; color: Theme.text; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Text { text: modelData.path + "  ·  " + modelData.transport; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                        }
                    }
                    Text { anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                           text: modelData.sizeText; color: Theme.text; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold }
                }
            }
        }

        Row {
            spacing: 16
            GlassCard {
                width: 422; height: 120
                Column {
                    anchors.fill: parent; anchors.margins: 16; spacing: 8
                    Text { text: app.t("fs"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 13 }
                    Repeater {
                        model: ["btrfs", "ext4"]
                        Row {
                            spacing: 10
                            Rectangle { width: 18; height: 18; radius: 9; anchors.verticalCenter: parent.verticalCenter
                                        color: "transparent"; border.color: app.filesystem === modelData ? Theme.accent : Theme.border; border.width: 2
                                        Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.accent; visible: app.filesystem === modelData } }
                            Text { text: app.t("fs_" + modelData); color: Theme.text; font.family: Theme.font; font.pixelSize: 14
                                   MouseArea { anchors.fill: parent; anchors.leftMargin: -30; cursorShape: Qt.PointingHandCursor; onClicked: app.filesystem = modelData } }
                        }
                    }
                }
            }
            GlassCard {
                width: 422; height: 120
                Column {
                    anchors.fill: parent; anchors.margins: 16; spacing: 8
                    Text { text: app.t("gpu") + "  (" + app.t("gpu_auto") + ")"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 13 }
                    ComboBox {
                        id: gfx
                        width: parent.width; height: 40
                        background: Rectangle { radius: 10; color: Qt.rgba(0, 0, 0, 0.25); border.color: gfx.activeFocus ? Theme.accent : Theme.border }
                        contentItem: Text { leftPadding: 12; text: gfx.displayText; color: Theme.text; font.family: Theme.font
                                            font.pixelSize: 13; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                        popup.background: Rectangle { radius: 10; color: "#111827"; border.color: Theme.border }
                        delegate: ItemDelegate {
                            required property string modelData
                            required property int index
                            width: gfx.width
                            contentItem: Text { text: modelData; color: index === gfx.currentIndex ? Theme.accent : Theme.text
                                                font.family: Theme.font; font.pixelSize: 13 }
                            background: Rectangle { color: hovered ? Theme.glassHi : "transparent" }
                        }
                        model: ["All open-source", "AMD / ATI (open-source)", "Intel (open-source)",
                                "Nvidia (open kernel module for newer GPUs, Turing+)", "Nvidia (open-source nouveau driver)", "VirtualBox (open-source)"]
                        currentIndex: model.indexOf(app.gfxDriver)
                        onActivated: function(i) { app.gfxDriver = model[i] }
                        font.family: Theme.font
                    }
                }
            }
        }

        GlassCard {
            visible: app.disk !== null
            width: 860; height: 96
            border.color: Theme.danger
            color: Qt.rgba(1, 0.36, 0.45, 0.08)
            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 10
                Text { text: app.t("wipe_warning"); color: Theme.danger; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.Bold }
                Row {
                    spacing: 10
                    Rectangle { width: 22; height: 22; radius: 6; anchors.verticalCenter: parent.verticalCenter
                                color: app.wipeConfirmed ? Theme.danger : "transparent"; border.color: Theme.danger; border.width: 2
                                Text { anchors.centerIn: parent; text: "x"; visible: app.wipeConfirmed; color: "#061014"; font.pixelSize: 14; font.bold: true } }
                    Text { text: app.disk ? app.tf("wipe_confirm", app.disk.path + " (" + app.disk.model + ")") : ""
                           color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
                }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.wipeConfirmed = !app.wipeConfirmed }
        }
    }
}
