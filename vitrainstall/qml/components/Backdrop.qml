// slowly moving soft colour glows behind everything - (c) 2026 34 & Claude
import QtQuick

Rectangle {
    color: Theme.bg
    clip: true
    Repeater {
        model: [
            { c: "57,197,187", s: 1.0, x: 0.10, y: 0.18, d: 26000 },
            { c: "225,40,133", s: 0.85, x: 0.82, y: 0.78, d: 31000 },
            { c: "59,91,219", s: 0.9, x: 0.66, y: 0.05, d: 37000 }
        ]
        delegate: Canvas {
            required property var modelData
            width: parent.width * modelData.s; height: width
            x: parent.width * modelData.x - width / 2
            y: parent.height * modelData.y - height / 2
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var g = ctx.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, width / 2);
                g.addColorStop(0, "rgba(" + modelData.c + ",0.30)");
                g.addColorStop(0.5, "rgba(" + modelData.c + ",0.10)");
                g.addColorStop(1, "rgba(" + modelData.c + ",0)");
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, width, height);
            }
            onWidthChanged: requestPaint()
            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation { to: x + 140; duration: modelData.d; easing.type: Easing.InOutSine }
                NumberAnimation { to: x - 80; duration: modelData.d; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on y {
                loops: Animation.Infinite
                NumberAnimation { to: y - 100; duration: modelData.d * 0.8; easing.type: Easing.InOutSine }
                NumberAnimation { to: y + 60; duration: modelData.d * 0.8; easing.type: Easing.InOutSine }
            }
        }
    }
}
