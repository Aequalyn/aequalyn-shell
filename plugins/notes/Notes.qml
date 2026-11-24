// Quick notes (Super + Alt + N): one page to jot things down, there whenever you call
// it, saved as you type to ~/Documents/Notes.md, a plain file any editor opens.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"
import "root:/settings"

Scope {
    id: root
    property var theme: null
    readonly property string path: (Quickshell.env("HOME") || "") + "/Documents/Notes.md"
    property string text: ""
    property bool loaded: false

    Process { id: mkdir; command: ["mkdir", "-p", (Quickshell.env("HOME") || "") + "/Documents"]; onExited: file.reload() }
    Component.onCompleted: { mkdir.running = true; KitHost.register("notes", root) }
    Component.onDestruction: { if (saveTimer.running) file.setText(root.text); KitHost.unregister("notes", root) }
    FileView {
        id: file
        path: root.path
        printErrors: false
        onLoaded: { root.text = text(); root.loaded = true }
        onLoadFailed: root.loaded = true
    }
    Timer { id: saveTimer; interval: 600; onTriggered: file.setText(root.text) }
    // never before the file is read: that would write over what is in it
    function save(t) { if (!root.loaded) return; root.text = t; saveTimer.restart() }

    KitPanel {
        id: panel
        theme: root.theme
        name: "notes"
        icon: "\u{F0219}"
        title: "Notes"
        input: false
        multiline: true
        panelWidth: 760
        panelHeight: 560
        status: "Saved as you type, in ~/Documents/Notes.md"
        hints: [["Esc", "close"], ["Ctrl + S", "save now"]]
        body: Component {
            Rectangle {
                radius: 10
                color: panel.c_surface
                border.width: 1
                border.color: edit.activeFocus ? panel.c_accent : panel.c_border
                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 12
                    contentWidth: width
                    contentHeight: edit.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    function follow(r) {
                        if (contentY >= r.y) contentY = r.y
                        else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
                    }
                    TextEdit {
                        id: edit
                        width: flick.width
                        wrapMode: TextEdit.Wrap
                        color: panel.c_text
                        selectionColor: panel.tint(panel.c_accent, 0.4)
                        font.family: AequalynSettings.monoFont
                        font.pixelSize: 13
                        text: root.text
                        readOnly: !root.loaded
                        focus: true
                        onCursorRectangleChanged: flick.follow(cursorRectangle)
                        onTextChanged: if (text !== root.text) root.save(text)
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) { panel.open = false; event.accepted = true }
                            else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) { saveTimer.stop(); file.setText(root.text); panel.status = "Saved"; event.accepted = true }
                        }
                        Component.onCompleted: { forceActiveFocus(); cursorPosition = length }
                    }
                }
            }
        }
    }
    IpcHandler {
        target: "notes"
        function toggle(): void { panel.toggle() }
        function add(line: string): void { root.save((root.text === "" || root.text.endsWith("\n") ? root.text : root.text + "\n") + line + "\n") }
    }
}
