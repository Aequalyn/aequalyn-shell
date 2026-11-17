// Network speed's quick panel: a click on the bar's network speed. In and out now,
// the last minute drawn, and everything since the computer started; last, Network
// speed in Plugins, and Wi-Fi.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/plugins/bar/quick"
import "root:/plugins/kit"

QuickPopup {
    id: q
    required property var bar
    readonly property var svc: KitHost.get("netSpeed")

    glyph: "\u{F06F3}"
    title: "Network speed"
    sub: svc ? "Right now, every two seconds" : "Turned off"
    settingsLabel: "Network speed settings"
    onSettingsClicked: { q.dismissed(); KitHost.openSettings("netSpeed") }

    RowLayout {
        visible: !!q.svc
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [
                { glyph: "\u{F0045}", name: "In", key: "down" },
                { glyph: "\u{F005D}", name: "Out", key: "up" }
            ]
            delegate: QuickCard {
                required property var modelData
                spacing: 2
                Text {
                    text: modelData.glyph + "  " + modelData.name
                    color: modelData.key === "down" ? Quick.theme.accentPrimary : Quick.theme.accentGreen
                    font.family: Quick.mono
                    font.pixelSize: 11
                }
                Text {
                    text: q.svc ? q.svc.human(q.svc[modelData.key]) : ""
                    color: Quick.theme.textPrimary
                    font.family: Quick.mono
                    font.pixelSize: 20
                    font.weight: Font.Medium
                }
            }
        }
    }

    // the last minute: in (accent) and out (green)
    QuickCard {
        visible: !!q.svc
        Canvas {
            id: graph
            Layout.fillWidth: true
            implicitHeight: 70
            readonly property var points: q.svc ? q.svc.history : []
            onPointsChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const pts = graph.points;
                if (pts.length < 2) return;
                let top = 1024;
                for (const p of pts) top = Math.max(top, p.d, p.u);
                const step = width / 29;
                const x0 = width - (pts.length - 1) * step;
                function line(key, color) {
                    ctx.beginPath();
                    for (let i = 0; i < pts.length; i++) {
                        const x = x0 + i * step, y = height - 2 - (pts[i][key] / top) * (height - 6);
                        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    }
                    ctx.strokeStyle = color;
                    ctx.lineWidth = 2;
                    ctx.stroke();
                }
                line("u", Quick.theme.accentGreen);
                line("d", Quick.theme.accentPrimary);
            }
        }
        Text {
            Layout.fillWidth: true
            text: "The last minute"
            color: Quick.theme.textMuted
            font.family: Quick.sans
            font.pixelSize: 10
        }
    }

    QuickCard {
        visible: !!q.svc
        Text {
            Layout.fillWidth: true
            text: q.svc ? "Since the computer started: " + q.svc.total(q.svc.received) + " in, " + q.svc.total(q.svc.sent) + " out" : ""
            color: Quick.theme.textSecondary
            font.family: Quick.sans
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }
    QuickWide {
        glyph: "\u{F05A9}"; label: "Wi-Fi"
        onClicked: { q.dismissed(); q.bar.openPage("wifi") }
    }
}
