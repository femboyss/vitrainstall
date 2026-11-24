// neutral mouse drawing: style "two" (left/right + wheel) or "one" (single surface) - (c) 2026 34 & Claude
import QtQuick

Item {
    id: m
    property string style: "two"
    property string lit: ""      // "left" | "right" | ""
    width: 70; height: 104
    onLitChanged: c.requestPaint()
    onStyleChanged: c.requestPaint()
    Canvas {
        id: c
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var w = width, h = height, r = w / 2;
            function body() {
                ctx.beginPath();
                ctx.moveTo(2, r);
                ctx.arc(r, r, r - 2, Math.PI, 0);
                ctx.lineTo(w - 2, h - r);
                ctx.arc(r, h - r, r - 2, 0, Math.PI);
                ctx.closePath();
            }
            body();
            ctx.fillStyle = "#151c28"; ctx.fill();
            ctx.lineWidth = 2; ctx.strokeStyle = "#3a4a60"; ctx.stroke();
            var hl = "rgba(57,197,187,0.55)";
            if (m.style === "two") {
                if (m.lit === "left" || m.lit === "right") {
                    ctx.save(); body(); ctx.clip();
                    ctx.fillStyle = hl;
                    if (m.lit === "left") ctx.fillRect(0, 0, r, h * 0.42); else ctx.fillRect(r, 0, r, h * 0.42);
                    ctx.restore();
                }
                ctx.beginPath(); ctx.moveTo(r, 4); ctx.lineTo(r, h * 0.42);
                ctx.moveTo(4, h * 0.42); ctx.lineTo(w - 4, h * 0.42);
                ctx.strokeStyle = "#3a4a60"; ctx.stroke();
                ctx.beginPath(); ctx.roundedRect(r - 4, 16, 8, 18, 4, 4);
                ctx.fillStyle = "#5b6b80"; ctx.fill();
            } else {
                if (m.lit !== "") {
                    ctx.save(); body(); ctx.clip();
                    ctx.fillStyle = hl;
                    if (m.lit === "left") ctx.fillRect(0, 0, w, h * 0.5);
                    else { ctx.fillRect(r, 0, r, h * 0.5); }
                    ctx.restore();
                }
                ctx.beginPath(); ctx.moveTo(r - 10, 10); ctx.lineTo(r + 10, 10);
                ctx.strokeStyle = "#3a4a60"; ctx.stroke();
            }
        }
    }
}
