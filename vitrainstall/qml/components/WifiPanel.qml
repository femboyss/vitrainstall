// Wi-Fi picker for the live system (iwd) - (c) 2026 34 & Claude
import QtQuick
import QtQuick.Controls

Column {
    id: w
    property var app
    signal online()
    property var networks: []
    property bool searching: false
    property bool connecting: false
    property string chosen: ""
    property bool chosenSecure: true
    property string status: ""      // "" | error key | "ok"
    spacing: 10

    function search() { searching = true; status = ""; backend.wifiScan() }
    Component.onCompleted: search()

    Connections {
        target: backend
        function onWifiNetworks(list) { w.networks = list; w.searching = false }
        function onWifiResult(err) {
            w.connecting = false
            w.status = err === "" ? "ok" : err
            if (err === "") w.online()
        }
    }

    Item {
        width: parent.width; height: 34
        Text { anchors.verticalCenter: parent.verticalCenter; text: w.app.t("wifi_title"); color: Theme.text
               font.family: Theme.font; font.pixelSize: 16; font.weight: Font.Bold }
        Button2 { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; height: 34
                  kind: "ghost"; text: w.app.t("wifi_search"); enabled2: !w.searching && !w.connecting; onClicked: w.search() }
    }

    Text { visible: w.searching; text: w.app.t("wifi_searching"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 13 }
    Text { visible: !w.searching && w.networks.length === 0; width: parent.width; wrapMode: Text.WordWrap
           text: w.app.t("wifi_none"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 13 }

    ListView {
        visible: !w.searching && w.networks.length > 0
        width: parent.width; height: Math.min(3, w.networks.length) * 44
        clip: true; spacing: 4
        model: w.networks
        ScrollBar.vertical: ScrollBar {}
        delegate: Rectangle {
            id: net
            required property var modelData
            width: ListView.view.width; height: 40; radius: 10
            color: w.chosen === modelData.ssid ? Qt.rgba(0.22, 0.77, 0.73, 0.16) : (ma.containsMouse ? Theme.glassHi : Qt.rgba(0, 0, 0, 0.2))
            border.width: w.chosen === modelData.ssid ? 1 : 0; border.color: Theme.accent
            Row { // signal bars
                id: bars
                anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater { model: 4
                    Rectangle { width: 4; height: 5 + index * 3; radius: 1; anchors.bottom: parent.bottom
                                color: index < Math.max(1, net.modelData.signal) ? Theme.accent : Qt.rgba(1, 1, 1, 0.18) } }
            }
            Text { anchors.left: bars.right; anchors.leftMargin: 12; anchors.right: sec.left; anchors.rightMargin: 8
                   anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                   text: modelData.ssid; color: Theme.text; font.family: Theme.font; font.pixelSize: 14 }
            Text { id: sec; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                   text: modelData.secure ? w.app.t("wifi_secured") : w.app.t("wifi_open"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { w.chosen = modelData.ssid; w.chosenSecure = modelData.secure; w.status = ""; pw.text = "" } }
        }
    }

    Row {
        visible: w.chosen !== "" && w.status !== "ok"
        spacing: 10
        Field { id: pw; visible: w.chosenSecure; width: 300; label: w.app.t("wifi_password"); echoMode: TextInput.Password }
        Button2 {
            anchors.bottom: parent.bottom
            text: w.connecting ? w.app.t("wifi_connecting") : w.app.t("wifi_connect")
            enabled2: !w.connecting && (!w.chosenSecure || pw.text.length >= 8)
            onClicked: { w.connecting = true; w.status = ""; backend.wifiConnect(w.chosen, w.chosenSecure ? pw.text : "") }
        }
    }

    Text { visible: w.status !== ""; width: parent.width; wrapMode: Text.WordWrap
           text: w.status === "ok" ? w.app.t("wifi_connected") : w.app.t("err_" + w.status)
           color: w.status === "ok" ? Theme.accent : Theme.danger; font.family: Theme.font; font.pixelSize: 13 }
}
