// The keys, laid out like a graphing calculator's: five across, the functions over the
// digits, Enter at the bottom right. 2nd turns every key to the one written small above
// it (in the accent), for one press, as on a TI-84. A key either puts text in the line
// (`ins`, with the cursor going to `back` characters from its end: inside the brackets)
// or does something (`act`), which the calculator answers through `acted`.
import QtQuick
import QtQuick.Layouts

Item {
    id: pad
    required property var kp          // the panel, for its colours
    property bool second: false
    property bool deg: false
    signal typed(string text, int back)
    signal acted(string act)

    // { l: label, ins | act, back, s: { the same, for 2nd }, kind: num | op | fn | ctl | go }
    readonly property var keys: [
        { l: "2nd", act: "second", kind: "ctl", tip: "The next key does what is written above it" },
        { l: pad.deg ? "DEG" : "RAD", act: "angle", kind: "ctl", tip: "Angles in degrees or radians" },
        { l: "◀", act: "left", kind: "ctl", s: { l: "⇤", act: "home" } },
        { l: "▶", act: "right", kind: "ctl", s: { l: "⇥", act: "end" } },
        { l: "DEL", act: "del", kind: "ctl", s: { l: "CLR", act: "clear" } },

        { l: "sin", ins: "sin(", back: 0, kind: "fn", s: { l: "sin⁻¹", ins: "asin(" } },
        { l: "cos", ins: "cos(", kind: "fn", s: { l: "cos⁻¹", ins: "acos(" } },
        { l: "tan", ins: "tan(", kind: "fn", s: { l: "tan⁻¹", ins: "atan(" } },
        { l: "ln", ins: "ln(", kind: "fn", s: { l: "eˣ", ins: "e^(" } },
        { l: "log", ins: "log(", kind: "fn", s: { l: "10ˣ", ins: "10^(" } },

        { l: "x²", ins: "²", kind: "fn", s: { l: "x³", ins: "³" } },
        { l: "√", ins: "√(", kind: "fn", s: { l: "∛", ins: "∛(" } },
        { l: "^", ins: "^", kind: "fn", s: { l: "ˣ√", ins: "root(, )", back: 3 } },
        { l: "x⁻¹", ins: "⁻¹", kind: "fn", s: { l: "!", ins: "!" } },
        { l: "π", ins: "π", kind: "fn", s: { l: "e", ins: "e" } },

        { l: "d/dx", ins: "deriv(, x, )", back: 6, kind: "fn", tip: "deriv(f, x, at): the slope of f at a point", s: { l: "Σ", ins: "sum(, k, 1, )", back: 9 } },
        { l: "∫", ins: "integral(, x, , )", back: 8, kind: "fn", tip: "integral(f, x, from, to)", s: { l: "∏", ins: "prod(, k, 1, )", back: 9 } },
        { l: "solve", ins: "solve(, x)", back: 4, kind: "fn", tip: "solve(f, x): where f is 0 (or type an equation with =)", s: { l: "round", ins: "round(" } },
        { l: "nCr", ins: "ncr(", kind: "fn", s: { l: "nPr", ins: "npr(" } },
        { l: "abs", ins: "abs(", kind: "fn", s: { l: "gcd", ins: "gcd(" } },

        { l: "(", ins: "(", kind: "op", s: { l: "mean", ins: "mean(" } },
        { l: ")", ins: ")", kind: "op", s: { l: "med", ins: "median(" } },
        { l: ",", ins: ", ", kind: "op", s: { l: "=", ins: " = " } },
        { l: "STO→", ins: " → ", kind: "op", tip: "Store the answer in a letter: 5 → a", s: { l: "rcl", act: "vars" } },
        { l: "x", ins: "x", kind: "fn", s: { l: "y", ins: "y" } },

        { l: "7", ins: "7", kind: "num" },
        { l: "8", ins: "8", kind: "num" },
        { l: "9", ins: "9", kind: "num" },
        { l: "÷", ins: "÷", kind: "op", s: { l: "mod", ins: "mod(" } },
        { l: "%", ins: "%", kind: "op", s: { l: "rand", ins: "rand" } },

        { l: "4", ins: "4", kind: "num" },
        { l: "5", ins: "5", kind: "num" },
        { l: "6", ins: "6", kind: "num" },
        { l: "×", ins: "×", kind: "op", s: { l: "lcm", ins: "lcm(" } },
        { l: "=", ins: " = ", kind: "op", tip: "An equation: Enter solves it" },

        { l: "1", ins: "1", kind: "num" },
        { l: "2", ins: "2", kind: "num" },
        { l: "3", ins: "3", kind: "num" },
        { l: "−", ins: "−", kind: "op" },
        { l: "ans", ins: "ans", kind: "fn", tip: "The last answer" },

        { l: "0", ins: "0", kind: "num" },
        { l: ".", ins: ".", kind: "num", s: { l: "ᴇ", ins: "×10^(" } },
        { l: "(−)", ins: "−", kind: "num", tip: "A negative number" },
        { l: "+", ins: "+", kind: "op" },
        { l: "ENTER", act: "enter", kind: "go", s: { l: "COPY", act: "copy" } }
    ]

    function press(k) {
        const use = pad.second && k.s ? k.s : k
        if (k.act === "second") { pad.second = !pad.second; return }
        pad.second = false
        if (use.act) pad.acted(use.act)
        else pad.typed(use.ins, use.back || 0)
    }

    GridLayout {
        anchors.fill: parent
        columns: 5
        rowSpacing: 6
        columnSpacing: 6
        Repeater {
            model: pad.keys
            delegate: Rectangle {
                id: key
                required property var modelData
                readonly property var k: modelData
                readonly property bool lit: k.act === "second" && pad.second
                readonly property color face: k.kind === "num" ? pad.kp.c_surface
                    : k.kind === "go" ? pad.kp.c_accent
                    : k.kind === "ctl" ? pad.kp.c_bg
                    : k.kind === "op" ? pad.kp.tint(pad.kp.c_accent, 0.10) : pad.kp.c_hover
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                radius: 9
                color: lit ? pad.kp.c_selected : area.pressed ? Qt.darker(face, 1.25) : area.containsMouse ? Qt.lighter(face, 1.18) : face
                border.width: 1
                border.color: lit ? pad.kp.c_accent : k.kind === "go" ? pad.kp.c_accent : pad.kp.c_border
                scale: area.pressed ? 0.96 : 1
                Behavior on scale { NumberAnimation { duration: 70 } }
                Accessible.role: Accessible.Button
                Accessible.name: k.tip ? k.l + ": " + k.tip : k.l
                // what 2nd makes of it, small above its own label
                Text {
                    visible: !!key.k.s
                    anchors.top: parent.top
                    anchors.topMargin: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: key.k.s ? key.k.s.l : ""
                    textFormat: Text.PlainText
                    color: pad.second ? pad.kp.c_accent : pad.kp.tint(pad.kp.c_accent, 0.6)
                    font.family: pad.kp.font
                    font.pixelSize: 10
                    font.bold: pad.second
                }
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: key.k.s ? 5 : 0
                    text: key.k.l
                    textFormat: Text.PlainText
                    opacity: pad.second && key.k.s ? 0.45 : 1
                    color: key.k.kind === "go" ? pad.kp.c_bg
                         : key.lit ? pad.kp.c_accent
                         : key.k.kind === "num" ? pad.kp.c_text
                         : key.k.kind === "op" ? pad.kp.c_accent : pad.kp.c_text2
                    font.family: pad.kp.font
                    font.pixelSize: key.k.kind === "num" ? 16 : key.k.l.length > 4 ? 10 : 13
                    font.bold: key.k.kind === "num" || key.k.kind === "go"
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pad.press(key.k)
                }
            }
        }
    }
}
