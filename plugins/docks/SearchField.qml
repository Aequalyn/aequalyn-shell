import QtQuick
import Quickshell.Io

// search field for the add-app popup.
//
// not a TextInput on purpose: QQuickTextInput hooks the clipboard in its constructor
// and re-reads it on every change (for canPaste), no limit, can't turn it off. the popup
// stays alive while hidden, so every dock would keep doing that in the background.
// this one is a Text + own key handling, so no clipboard connection at all.
// paste only on explicit ctrl+v / shift+insert, via a fixed command, capped at
// pasteMaxBytes and 2 seconds. no IME, copy/cut or mouse selection (by design)
Item {
  id: field

  property string text: ""
  property color color: "white"
  property color selectionColor: "#557aa2f7"
  property string fontFamily: ""
  property real fontPixelSize: 14
  property int maxChars: 128
  property int pasteMaxBytes: 512
  property int cursorPosition: 0
  property bool selectAll: false

  activeFocusOnTab: true
  clip: true

  function clear() { text = ""; cursorPosition = 0; selectAll = false; }

  function clampCursor() {
    cursorPosition = Math.max(0, Math.min(text.length, cursorPosition));
  }

  // insert plain single-line text at pos (replaces everything after select-all)
  function insert(pos, str) {
    let t = String(str === null || str === undefined ? "" : str)
      .split(/\r?\n/)[0]
      .replace(/[\u0000-\u001f\u007f]/g, "");
    if (t === "") return;
    let base = text;
    if (selectAll) { base = ""; pos = 0; selectAll = false; }
    const room = maxChars - base.length;
    if (room <= 0) return;
    t = t.substring(0, room);
    pos = Math.max(0, Math.min(base.length, pos));
    text = base.substring(0, pos) + t + base.substring(pos);
    cursorPosition = pos + t.length;
  }

  function removeBack() {
    if (selectAll) { clear(); return; }
    if (cursorPosition <= 0) return;
    text = text.substring(0, cursorPosition - 1) + text.substring(cursorPosition);
    cursorPosition -= 1;
  }

  function removeForward() {
    if (selectAll) { clear(); return; }
    if (cursorPosition >= text.length) return;
    text = text.substring(0, cursorPosition) + text.substring(cursorPosition + 1);
  }

  onTextChanged: clampCursor()
  onActiveFocusChanged: {
    if (activeFocus) { cursorPosition = text.length; blink.restart(); }
    else selectAll = false;
  }

  // keep the caret visible on long text
  readonly property real caretX: fm.advanceWidth(text.substring(0, cursorPosition))
  readonly property real shift: Math.max(0, caretX - width + 2)

  // bounded paste, explicit only, one at a time
  Process {
    id: pasteProc
    running: false
    command: ["sh", "-c", "timeout 2 wl-paste --no-newline 2>/dev/null | head -c \"$1\"",
      "sh", String(Math.max(0, field.pasteMaxBytes))]
    stdout: StdioCollector {
      id: pasteOut
      onStreamFinished: if (field.activeFocus) field.insert(field.cursorPosition, pasteOut.text)
    }
  }

  FontMetrics {
    id: fm
    font.family: field.fontFamily
    font.pixelSize: field.fontPixelSize
  }

  Rectangle {   // select-all highlight
    visible: field.selectAll && field.text !== ""
    x: -field.shift
    width: shown.implicitWidth
    height: shown.implicitHeight
    anchors.verticalCenter: parent.verticalCenter
    color: field.selectionColor
  }

  Text {
    id: shown
    textFormat: Text.PlainText
    x: -field.shift
    anchors.verticalCenter: parent.verticalCenter
    text: field.text
    color: field.color
    font.family: field.fontFamily
    font.pixelSize: field.fontPixelSize
  }

  Rectangle {   // caret
    visible: field.activeFocus && blink.on
    width: 1
    height: shown.implicitHeight
    anchors.verticalCenter: parent.verticalCenter
    x: field.caretX - field.shift
    color: field.color
  }

  Timer {
    id: blink
    property bool on: true
    interval: 530
    repeat: true
    running: field.activeFocus
    onTriggered: on = !on
    onRunningChanged: if (running) on = true
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton   // middle / right: ignored, nothing pastes
    cursorShape: Qt.IBeamCursor
    onPressed: m => {
      field.forceActiveFocus();
      field.selectAll = false;
      const px = m.x + field.shift;
      let best = field.text.length;
      for (let i = 0; i <= field.text.length; i++) {
        if (fm.advanceWidth(field.text.substring(0, i)) >= px) { best = i; break; }
      }
      field.cursorPosition = best;
      blink.on = true;
    }
  }

  Keys.onPressed: e => {
    const mods = e.modifiers;
    const ctrl = (mods & Qt.ControlModifier) !== 0;
    blink.on = true;
    if (e.matches(StandardKey.Paste) || (e.key === Qt.Key_Insert && (mods & Qt.ShiftModifier))) {
      e.accepted = true;
      if (!pasteProc.running) pasteProc.running = true;
      return;
    }
    if (ctrl && e.key === Qt.Key_A) { selectAll = text !== ""; e.accepted = true; return; }
    switch (e.key) {
    case Qt.Key_Backspace: removeBack(); e.accepted = true; return;
    case Qt.Key_Delete: removeForward(); e.accepted = true; return;
    case Qt.Key_Left: selectAll = false; cursorPosition -= 1; clampCursor(); e.accepted = true; return;
    case Qt.Key_Right: selectAll = false; cursorPosition += 1; clampCursor(); e.accepted = true; return;
    case Qt.Key_Home: selectAll = false; cursorPosition = 0; e.accepted = true; return;
    case Qt.Key_End: selectAll = false; cursorPosition = text.length; e.accepted = true; return;
    default: break;
    }
    // printable chars only, shortcuts (esc, enter...) go to the popup
    if (!ctrl && !(mods & Qt.AltModifier) && !(mods & Qt.MetaModifier)
        && e.text.length > 0 && e.text.charCodeAt(0) >= 32 && e.text.charCodeAt(0) !== 127) {
      insert(cursorPosition, e.text);
      e.accepted = true;
    }
  }
}
