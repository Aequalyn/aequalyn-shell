// Keyboard shortcuts (plugins/keybinds): every key Hyprland uses, as Aequalyn
// ships it in ~/.config/hypr/keybinds.lua. Click a row, press your own keys;
// delete a row and its key does nothing; make a key of your own, for a command
// of your choosing. Every change is written into the file at once, Hyprland
// reloads, and if it refuses the change the file is put back as it was and the
// page says so. The universal clipboard, the window layouts, the switcher and
// the web apps keep their own keys; the fold at the end lists them, and a key
// one of them uses is refused with its name.
import QtQuick
import QtQuick.Layouts
import "root:/settings"
import "root:/plugins/keybinds"
import ".."

CcPage {
    id: page
    title: "Keyboard shortcuts"
    plugin: "keybinds"
    readonly property var svc: KeybindsHost.svc

    // what is being given a new key right now: a shipped bind's id, a made
    // bind's key, or the add form
    property string query: ""
    property string editing: ""
    property string editingCustom: ""
    property bool formPicking: false
    // the add form
    property string newName: ""
    property string newCommand: ""
    property string formNote: ""

    function cancelEdit() {
        page.editing = "";
        page.editingCustom = "";
        page.formPicking = false;
    }

    sub: {
        const s = page.svc;
        if (!s) return "The keys of the whole desktop, made yours.";
        if (!s.binds || s.binds.length === 0)
            return "Aequalyn's Hyprland config is not here, so there is nothing to change.";
        let moved = 0;
        if (s.state) { for (const k in s.state.changed) moved++; moved += s.state.custom.length; }
        const gone = s.state ? s.state.removed.length : 0;
        let out = moved > 0 ? (moved === 1 ? "One key of yours" : moved + " keys of yours") : "Every key as Aequalyn ships it";
        if (gone > 0) out += ", " + (gone === 1 ? "one deleted" : gone + " deleted");
        if (s.status.error) out += ". \u26a0 " + s.status.error;
        else if (s.status.active === "false") out += ". Hyprland is not using them right now: see ~/.local/state/aequalyn/keybinds/binds-check.txt";
        else out += moved > 0 || gone > 0 ? ", live." : ".";
        if (s.status.skipped && s.status.skipped.length > 0)
            out += " Not written: " + s.status.skipped[0] + ".";
        return out;
    }

    // what the search shows: a bind's name, or either of its keys
    function shows(bind) {
        const q = page.query.trim().toLowerCase();
        if (q === "" || !page.svc) return true;
        const t = (bind.label + " " + page.svc.chordText(page.svc.currentKey(bind))
                   + " " + page.svc.chordText(bind.id)).toLowerCase();
        return t.indexOf(q) >= 0;
    }
    function showsCustom(c) {
        const q = page.query.trim().toLowerCase();
        if (q === "" || !page.svc) return true;
        const t = (page.svc.customLabel(c) + " " + c.command + " "
                   + page.svc.chordText(c.keys)).toLowerCase();
        return t.indexOf(q) >= 0;
    }

    // the groups as the page shows them: only those with a match, and the
    // workspace keys folded into their own part
    readonly property var shownGroups: {
        const out = [];
        if (!page.svc) return out;
        const groups = page.svc.groups || [];
        for (let g = 0; g < groups.length; g++) {
            const items = groups[g].binds.filter(page.shows);
            if (items.length > 0)
                out.push({ key: groups[g].key, title: groups[g].title, hint: groups[g].hint, binds: items });
        }
        return out;
    }
    readonly property var shownCustom: {
        if (!page.svc || !page.svc.state) return [];
        return page.svc.state.custom.filter(page.showsCustom);
    }
    readonly property int shownCount: {
        let n = page.shownCustom.length;
        for (let g = 0; g < page.shownGroups.length; g++) n += page.shownGroups[g].binds.length;
        return n;
    }
    function isWs(bind) { return /^SUPER( \+ SHIFT)? \+ \d$/.test(bind.id) }

    // one press, checked: "" when only modifiers are held; null when the key
    // cannot be named; "modifier" when a bare key would be taken from every
    // app; otherwise the name of whoever holds it. The caller says what to do
    // with a free chord.
    function pressChord(event, except, apply) {
        if (page.svc.isModifierKey(event.key)) return "";
        const chord = page.svc.chordFromEvent(event);
        if (chord === "") return "That key has no name to bind. Try another.";
        const who = page.svc.conflictFor(chord, except);
        if (who === "modifier")
            return "Add Super, Ctrl, Alt or Shift: a key alone would be taken from every app.";
        if (who !== null && who !== "") return "That's " + who + ".";
        apply(chord);
        return null;
    }

    CcNote {
        visible: !page.svc
        text: "Keyboard shortcuts is turned off. Turn it on above to change keys; the ones already written stay as they are."
    }
    CcNote {
        visible: !!page.svc && page.svc.binds.length > 0 && page.svc.warnings.length > 0
        text: "Some binds in keybinds.lua are not listed: a shape this page does not know yet."
    }

    // ---- find ------------------------------------------------------------------------
    RowLayout {
        visible: !!page.svc
        Layout.fillWidth: true
        spacing: 10
        CcField {
            Layout.fillWidth: true
            placeholder: "Find a shortcut"
            text: page.query
            onTextChanged: page.query = text
        }
        Text {
            visible: page.query.trim() !== ""
            text: page.shownCount + (page.shownCount === 1 ? " match" : " matches")
            color: Cc.theme.textMuted
            font.family: Cc.sans
            font.pixelSize: 12
        }
    }

    // ---- the keys you made -----------------------------------------------------------
    CcSection {
        visible: !!page.svc
        title: "Your own keys"
        hint: "Keys for commands of your choosing. Pick the key after you have said what it should do."

        Repeater {
            model: page.shownCustom
            delegate: RowLayout {
                id: crow
                required property var modelData
                readonly property var bind: modelData
                readonly property bool editing: page.editingCustom === bind.keys
                property bool confirming: false
                property string err: ""
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(58, ctexts.implicitHeight + 22)
                    radius: 8
                    color: cArea.containsMouse ? Cc.theme.bgHover : "transparent"
                    border.width: crow.editing ? 1 : 0
                    border.color: Cc.theme.accentPrimary
                    MouseArea {
                        id: cArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            page.editing = "";
                            page.formPicking = false;
                            crow.err = "";
                            if (crow.editing) { page.editingCustom = ""; return }
                            page.editingCustom = crow.bind.keys;
                            ccap.forceActiveFocus();
                        }
                    }
                    RowLayout {
                        id: ctexts
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: page.svc.customLabel(crow.bind)
                                color: crow.editing ? Cc.theme.accentPrimary : Cc.theme.textPrimary
                                font.family: Cc.sans
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: crow.editing ? "Press the keys for it. Esc cancels."
                                    : crow.confirming ? "Remove this key? The command is gone with it."
                                    : crow.bind.command
                                color: crow.confirming ? Cc.theme.accentRed : Cc.theme.textMuted
                                font.family: Cc.sans
                                font.pixelSize: 11
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: crow.err !== "" && !crow.confirming
                                text: crow.err
                                color: Cc.theme.accentRed
                                font.family: Cc.sans
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: cchip.implicitWidth + 16
                            implicitHeight: 24
                            radius: 6
                            color: Cc.theme.bgBase
                            border.width: 1
                            border.color: crow.editing ? Cc.theme.accentPrimary : Cc.theme.bgBorder
                            Text {
                                id: cchip
                                anchors.centerIn: parent
                                text: page.svc.chordText(crow.bind.keys)
                                color: Cc.theme.accentPrimary
                                font.family: Cc.mono
                                font.pixelSize: 11
                            }
                        }
                        CcButton {
                            visible: crow.confirming
                            text: "Keep"
                            onClicked: crow.confirming = false
                        }
                        CcButton {
                            visible: crow.confirming
                            text: "Remove"
                            danger: true
                            onClicked: { page.svc.removeCustom(crow.bind.keys); crow.confirming = false }
                        }
                        CcButton {
                            visible: !crow.confirming
                            icon: "\u{F01B4}"
                            onClicked: { crow.err = ""; crow.confirming = true }
                        }
                    }
                    // while the row is highlighted, every key press is the new chord
                    Item {
                        id: ccap
                        anchors.fill: parent
                        focus: crow.editing
                        Keys.onPressed: (event) => {
                            if (!crow.editing) return;
                            event.accepted = true;
                            if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) { page.cancelEdit(); return }
                            if (event.key === Qt.Key_Backspace && event.modifiers === Qt.NoModifier) {
                                page.svc.removeCustom(crow.bind.keys);
                                page.cancelEdit();
                                return;
                            }
                            const note = page.pressChord(event, { custom: crow.bind.keys }, chord => {
                                page.svc.setCustomKey(crow.bind.keys, chord);
                            });
                            if (note !== null) { crow.err = note; return }
                            page.cancelEdit();
                        }
                    }
                }
            }
        }

        // the add form: name and command, then the key is pressed
        ColumnLayout {
            visible: !page.formPicking
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                CcField {
                    Layout.preferredWidth: 150
                    placeholder: "A name (optional)"
                    text: page.newName
                    onTextChanged: page.newName = text
                }
                CcField {
                    Layout.fillWidth: true
                    placeholder: "What it runs (a command)"
                    text: page.newCommand
                    onTextChanged: page.newCommand = text
                }
                CcButton {
                    text: "Add a keybind"
                    icon: "\u{F01B4}"
                    primary: true
                    onClicked: {
                        if (!page.svc) return;
                        if (page.newCommand.trim() === "") { page.formNote = "Say what the key should run."; return }
                        page.editing = "";
                        page.editingCustom = "";
                        page.formNote = "Press the keys for it. Esc cancels.";
                        page.formPicking = true;
                        formcap.forceActiveFocus();
                    }
                }
            }
            Text {
                visible: page.formNote !== "" && !page.formPicking
                text: page.formNote
                color: Cc.theme.accentRed
                font.family: Cc.sans
                font.pixelSize: 11
                Layout.leftMargin: 12
                Layout.bottomMargin: 2
            }
        }
        Rectangle {
            id: picker
            visible: page.formPicking
            Layout.fillWidth: true
            implicitHeight: 46
            radius: 8
            color: Cc.theme.bgBase
            border.width: 1
            border.color: Cc.theme.accentPrimary
            Text {
                anchors.centerIn: parent
                text: page.formNote !== "" && page.formPicking ? page.formNote : "Press the keys for your keybind. Esc cancels."
                color: Cc.theme.textPrimary
                font.family: Cc.sans
                font.pixelSize: 12
            }
            Item {
                id: formcap
                anchors.fill: parent
                focus: page.formPicking
                Keys.onPressed: (event) => {
                    if (!page.formPicking) return;
                    event.accepted = true;
                    if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                        page.formPicking = false; page.formNote = ""; return;
                    }
                    const note = page.pressChord(event, null, chord => {
                        const why = page.svc.addCustom(page.newName, page.newCommand, chord);
                        if (why !== "") { page.formNote = why; return }
                        page.newName = "";
                        page.newCommand = "";
                        page.formPicking = false;
                        page.formNote = "";
                    });
                    if (note !== null) page.formNote = note;
                }
            }
        }
    }

    // ---- one shipped bind -------------------------------------------------------------
    component BindRow: Rectangle {
        id: row
        required property var modelData
        readonly property var bind: modelData
        readonly property bool mine: !!page.svc && page.svc.state !== null && page.svc.state.changed[bind.id] !== undefined
        readonly property bool deleted: !!page.svc && page.svc.state !== null && page.svc.state.removed.indexOf(bind.id) >= 0
        readonly property bool editing: page.editing === bind.id
        readonly property string keys: deleted ? "" : (page.svc ? page.svc.chordText(page.svc.currentKey(bind)) : "")
        readonly property bool clickable: !!page.svc && bind && bind.editable && !deleted
        property string err: ""

        Layout.fillWidth: true
        implicitHeight: Math.max(58, texts.implicitHeight + 22)
        radius: grouped ? 8 : 12
        color: clickable && area.containsMouse ? Cc.theme.bgHover : (grouped ? "transparent" : Cc.theme.bgSurface)
        border.width: editing ? 1 : (grouped ? 0 : 1)
        border.color: editing ? Cc.theme.accentPrimary : Cc.theme.bgBorder

        // the pattern (Cc.qml): a row of its section's group, or a group of its own
        property var section: null
        readonly property bool grouped: !!section
        readonly property bool firstRow: Cc.firstShown(parent) === row
        Component.onCompleted: { row.section = Cc.sectionOf(row); if (row.section) row.section.rows++ }
        Component.onDestruction: { try { if (row.section) row.section.rows-- } catch (e) {} }
        Rectangle {
            visible: row.grouped && !row.firstRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 1
            color: Cc.theme.bgBorder
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: row.clickable
            enabled: row.clickable
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                page.editingCustom = "";
                page.formPicking = false;
                row.err = "";
                if (row.editing) { page.editing = ""; return }
                page.editing = row.bind.id;
                cap.forceActiveFocus();
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 12
            ColumnLayout {
                id: texts
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: row.bind ? row.bind.label : ""
                    color: row.editing ? Cc.theme.accentPrimary
                        : row.deleted ? Cc.theme.textMuted : Cc.theme.textPrimary
                    font.family: Cc.sans
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: !row.editing && !row.deleted && (row.mine || (row.bind && row.bind.hardware))
                    text: row.mine ? "Aequalyn's own: " + (page.svc ? page.svc.chordText(row.bind.id) : "")
                        : "A key on the keyboard itself; press it to change"
                    color: Cc.theme.textMuted
                    font.family: Cc.sans
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: row.deleted
                    text: "Deleted: the key does nothing. The button brings it back."
                    color: Cc.theme.textMuted
                    font.family: Cc.sans
                    font.pixelSize: 11
                    Layout.fillWidth: true
                }
                Text {
                    visible: row.editing
                    text: "Press the keys for it. Esc cancels; Backspace resets."
                    color: Cc.theme.textMuted
                    font.family: Cc.sans
                    font.pixelSize: 11
                    Layout.fillWidth: true
                }
                Text {
                    visible: (row.editing || row.deleted) && row.err !== ""
                    text: row.err
                    color: Cc.theme.accentRed
                    font.family: Cc.sans
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
            // the key itself, as a chip
            Rectangle {
                visible: !!row.bind
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: chipText.implicitWidth + 16
                implicitHeight: 24
                radius: 6
                color: Cc.theme.bgBase
                border.width: 1
                border.color: row.editing ? Cc.theme.accentPrimary
                    : row.deleted ? Cc.theme.bgBorder
                    : row.mine ? Cc.alpha(Cc.theme.accentPrimary, 0.4) : Cc.theme.bgBorder
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: row.deleted ? "deleted" : row.keys
                    color: row.deleted ? Cc.theme.textMuted
                        : row.mine ? Cc.theme.accentPrimary : Cc.theme.textSecondary
                    font.family: Cc.mono
                    font.pixelSize: 11
                }
            }
            // take back: Aequalyn's own key, or a delete
            CcButton {
                visible: !row.editing && (row.mine || row.deleted)
                icon: "\u{F0450}"
                onClicked: {
                    row.err = "";
                    if (row.deleted) {
                        const why = page.svc.restoreBind(row.bind.id);
                        if (why !== "") row.err = "Cannot bring it back: that's " + why + ".";
                    } else {
                        page.svc.resetBind(row.bind.id);
                    }
                }
            }
            CcButton {
                visible: !row.editing && !row.deleted
                icon: "\u{F01B4}"
                onClicked: { row.err = ""; page.svc.removeBind(row.bind.id) }
            }
            CcButton {
                visible: row.editing
                text: "Cancel"
                onClicked: page.cancelEdit()
            }
        }

        // while the row is highlighted, every key press is the new chord
        Item {
            id: cap
            anchors.fill: parent
            focus: row.editing
            Keys.onPressed: (event) => {
                if (!row.editing) return;
                event.accepted = true;
                if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) { page.cancelEdit(); return }
                if (event.key === Qt.Key_Backspace && event.modifiers === Qt.NoModifier) {
                    page.svc.resetBind(row.bind.id);
                    page.cancelEdit();
                    return;
                }
                const note = page.pressChord(event, { id: row.bind.id }, chord => {
                    page.svc.moveKey(row.bind.id, chord);
                });
                if (note !== null) { row.err = note; return }
                page.cancelEdit();
            }
        }
    }

    // ---- the groups ------------------------------------------------------------------
    Repeater {
        model: page.shownGroups
        delegate: CcSection {
            id: section
            required property var modelData
            title: modelData.title
            hint: modelData.hint
            Repeater {
                model: section.modelData.binds.filter(b => !page.isWs(b))
                delegate: BindRow {}
            }
            // the twenty workspace keys, folded: Super 1..0 and their Shift twins
            CcMore {
                visible: section.modelData.key === "workspaces"
                    && section.modelData.binds.filter(b => page.isWs(b)).length > 0
                title: "The workspace keys"
                Repeater {
                    model: section.modelData.binds.filter(page.isWs)
                    delegate: BindRow {}
                }
            }
        }
    }

    // ---- what is not on the page -----------------------------------------------------
    CcMore {
        visible: !!page.svc && page.svc.reservedRows.length > 0
        title: "Keys that live elsewhere"
        CcNote {
            text: "These are not changed here: each belongs to what uses it. A key one of them has is refused above, with its name."
        }
        Repeater {
            model: page.svc ? page.svc.reservedRows : []
            delegate: RowLayout {
                id: held
                required property var modelData
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: held.modelData.keys
                    color: Cc.theme.textSecondary
                    font.family: Cc.mono
                    font.pixelSize: 11
                    Layout.preferredWidth: 190
                    elide: Text.ElideRight
                }
                Text {
                    text: held.modelData.what
                    color: Cc.theme.textMuted
                    font.family: Cc.sans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // ---- start over ------------------------------------------------------------------
    CcMore {
        visible: !!page.svc && page.svc.differences > 0
        title: "Start over"
        CcNote { text: "Every key back to how Aequalyn ships it, and the keys you made here gone." }
        CcButton {
            text: "Take every key back"
            icon: "\u{F0450}"
            danger: true
            onClicked: page.svc.resetAll()
        }
    }
}
