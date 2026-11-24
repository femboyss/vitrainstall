// page 2: keyboard layout + time zone - (c) 2026 34 & Claude
import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: page
    property var app
    property var layouts: []
    property var zones: []
    Component.onCompleted: { layouts = backend.keyboardLayouts(); zones = backend.timezones() }

    component PickList: GlassCard {
        id: pl
        property var items: []
        property string current: ""
        property string title: ""
        property string searchHint: ""
        signal picked(string v)
        width: 470; height: 430
        readonly property var filtered: items.filter(function(x) { return search.text === "" || x.toLowerCase().indexOf(search.text.toLowerCase()) >= 0 })
        Column {
            anchors.fill: parent; anchors.margins: 18; spacing: 10
            Text { text: pl.title; color: Theme.text; font.family: Theme.font; font.pixelSize: 18; font.weight: Font.Bold }
            Field { id: search; width: parent.width; placeholder: pl.searchHint }
            ListView {
                id: lv
                width: parent.width; height: parent.height - 110
                clip: true
                model: pl.filtered
                ScrollBar.vertical: ScrollBar {}
                currentIndex: pl.filtered.indexOf(pl.current)
                Component.onCompleted: positionViewAtIndex(currentIndex, ListView.Center)
                delegate: Rectangle {
                    required property string modelData
                    width: lv.width - 10; height: 36; radius: 10
                    color: modelData === pl.current ? Qt.rgba(0.22, 0.77, 0.73, 0.2) : (ma.containsMouse ? Theme.glassHi : "transparent")
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 12
                           text: modelData; color: modelData === pl.current ? Theme.accent : Theme.text
                           font.family: Theme.font; font.pixelSize: 14 }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: pl.picked(modelData) }
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 20
        Text { text: app.t("kb_title"); color: Theme.text; font.family: Theme.font; font.pixelSize: 34; font.weight: Font.Bold }
        Row {
            spacing: 24
            Column {
                spacing: 14
                PickList {
                    title: app.t("kb_layout"); searchHint: app.t("kb_search")
                    items: page.layouts; current: app.keyboard
                    onPicked: function(v) { app.keyboard = backend.setKeyboard(v) }
                }
                Field { width: 470; placeholder: app.t("kb_test") }
            }
            PickList {
                title: app.t("tz") + ":  " + app.timezone; searchHint: app.t("tz_search")
                items: page.zones; current: app.timezone
                onPicked: function(v) { app.timezone = v }
            }
        }
    }
}
