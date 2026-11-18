// Keyboard shortcuts (plugins/keybinds): every key Hyprland uses, as Aequalyn
// ships it in ~/.config/hypr/keybinds.lua. Click a row, press your own keys:
// the service writes the change into the file at once and Hyprland starts
// using it. The universal clipboard, the window layouts, the switcher and the
// web apps keep their own keys; the fold at the end lists them, and a key one
// of them uses is refused with its name.
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

    // what is being given a new key, and why the last press was refused
    property string query: ""
    property string editing: ""
    property string note: ""

    sub: {
        const s = page.svc;
        if (!s) return "The keys of the whole desktop, made yours.";
        if (!s.binds || s.binds.length === 0)
            return "Aequalyn's Hyprland config is not here, so there is nothing to change.";
        const n = s.status.count || 0;
        let out = n > 0 ? (n === 1 ? "One key of yours" : n + " keys of yours") : "Every key as Aequalyn ships it";
        if (s.status.error) out += ". \u26a0 " + s.status.error;
        else if (s.status.active === "false") out += ". Hyprland is not using them right now: see ~/.local/state/aequalyn/keybinds/binds-check.txt";
        else out += n > 0 ? ", live." : ".";
        if (s.status.skipped && s.status.skipped.length > 0)
            out += " Not written: " + s.status.skipped[0] + ".";
        return out;
    }

    function cancelEdit() { page.editing = ""; page.note = "" }

    // what the search shows: a bind's name, or either of its keys
    function shows(bind) {
        const q = page.query.trim().toLowerCase();
        if (q === "" || !page.svc) return true;
        const t = (bind.label + " " + page.svc.chordText(page.svc.currentKey(bind))
                   + " " + page.svc.chordText(bind.id)).toLowerCase();
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
    readonly property int shownCount: {
        let n = 0;
        for (let g = 0; g < page.shownGroups.length; g++) n += page.shownGroups[g].binds.length;
        return n;
    }
    function isWs(bind) { return /^SUPER( \+ SHIFT)? \+ \d$/.test(bind.id) }

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

    // ---- one bind --------------------------------------------------------------------
    component BindRow: Rectangle {
        id: row
        required property var modelData
        readonly property var bind: modelData
        readonly property bool mine: !!page.svc && page.svc.overrides[bind.id] !== undefined
        readonly property bool editing: page.editing === bind.id
        readonly property string keys: page.svc ? page.svc.chordText(page.svc.currentKey(bind)) : ""
        readonly property bool clickable: !!page.svc && bind && bind.editable

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
            onClicked: { page.editing = row.bind.id; page.note = ""; cap.forceActiveFocus() }
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
                    color: row.editing ? Cc.theme.accentPrimary : Cc.theme.textPrimary
                    font.family: Cc.sans
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: row.editing || (row.mine && !row.editing)
                    text: row.editing ? "Press the keys for it. Esc cancels; Backspace resets."
                        : "Aequalyn's own: " + (page.svc ? page.svc.chordText(row.bind.id) : "")
                    color: Cc.theme.textMuted
                    font.family: Cc.sans
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: row.editing && page.note !== ""
                    text: page.note
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
                    : row.mine ? Cc.alpha(Cc.theme.accentPrimary, 0.4) : Cc.theme.bgBorder
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: row.keys
                    color: row.mine ? Cc.theme.accentPrimary : Cc.theme.textSecondary
                    font.family: Cc.mono
                    font.pixelSize: 11
                }
            }
            CcButton {
                visible: row.mine && !row.editing
                icon: "\u{F0450}"
                onClicked: { page.svc.resetBind(row.bind.id); page.note = "" }
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
                // a modifier alone is half a chord: wait for the key
                if (page.svc.isModifierKey(event.key)) return;
                const chord = page.svc.chordFromEvent(event);
                if (chord === "") { page.note = "That key has no name to bind. Try another."; return }
                const who = page.svc.conflictFor(chord, row.bind.id);
                if (who === "modifier") {
                    page.note = "Add Super, Ctrl, Alt or Shift: a key alone would be taken from every app.";
                    return;
                }
                if (who !== null && who !== "") { page.note = "That's " + who + "."; return }
                page.svc.setBind(row.bind.id, chord);
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
        visible: !!page.svc && page.svc.status.count > 0
        title: "Start over"
        CcNote { text: "Every key back to how Aequalyn ships it." }
        CcButton {
            text: "Take every key back"
            icon: "\u{F0450}"
            danger: true
            onClicked: page.svc.resetAll()
        }
    }
}
