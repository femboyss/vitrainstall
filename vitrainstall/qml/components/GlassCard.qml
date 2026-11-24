// a frosted card - (c) 2026 34 & Claude
import QtQuick

Rectangle {
    id: card
    property bool selected: false
    property bool hoverable: false
    signal clicked()
    radius: Theme.radius
    color: selected ? Qt.rgba(0.22, 0.77, 0.73, 0.14) : (ma.containsMouse && hoverable ? Theme.glassHi : Theme.glass)
    border.width: selected ? 2 : 1
    border.color: selected ? Theme.accent : Theme.border
    Behavior on color { enabled: !Theme.lite; ColorAnimation { duration: 150 } }
    Behavior on border.color { enabled: !Theme.lite; ColorAnimation { duration: 150 } }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: card.hoverable
        enabled: card.hoverable
        cursorShape: card.hoverable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: card.clicked()
    }
}
