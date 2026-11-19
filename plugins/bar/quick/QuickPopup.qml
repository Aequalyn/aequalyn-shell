// A quick panel: what a bar widget opens under it, on the click you choose for it. Every one looks the
// same: a header (its icon, name and a line of state, and round buttons on the right),
// what it shows and does, and, last, a button to its settings in the control center.
//
//   QuickPopup {
//       anchorItem: widget
//       open: ...                  // the owner says when (Bar.qml: widgetPopup)
//       onDismissed: ...           // a click outside or Esc: the owner closes it
//       glyph: "\u{F051B}"; title: "Timer"; sub: "Ends at 14:30"
//       settingsLabel: "Timer settings"; onSettingsClicked: ...
//       actions: [ QuickRound { ... } ]
//       QuickWide { ... }          // the body, top to bottom
//   }
//
// Its parts are in this folder (QuickRound, QuickTile, QuickLevel, QuickWide, QuickCard,
// QuickLabel), the same the gear's quick panel is made of.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"

PopupWindow {
    id: pop
    required property Item anchorItem
    property bool open: false
    signal dismissed()

    property string glyph: ""
    property string title: ""
    property string sub: ""
    property string settingsLabel: ""
    signal settingsClicked()
    property alias actions: actionsRow.data
    default property alias content: body.data
    property int panelWidth: 360

    implicitWidth: panelWidth
    implicitHeight: column.implicitHeight + 32
    color: "transparent"
    grabFocus: !Quick.byKey
    visible: open
    // closed from outside (a click elsewhere): the owner is told, and `visible` follows
    // `open` again
    onVisibleChanged: if (!visible && open) { pop.dismissed(); pop.visible = Qt.binding(() => pop.open) }

    anchor.item: anchorItem
    // on the windows' side of the widget: under it on a top bar, over it on a bottom bar,
    // beside it on a side bar, 8 px off
    readonly property string barSide: ["bottom", "left", "right"].indexOf(AequalynSettings.barPosition) >= 0
                                      ? AequalynSettings.barPosition : "top"
    readonly property bool sideways: barSide === "left" || barSide === "right"
    readonly property int openEdge: barSide === "bottom" ? Edges.Top : barSide === "left" ? Edges.Right
                                  : barSide === "right" ? Edges.Left : Edges.Bottom
    anchor.rect.x: barSide === "right" ? -8 : 0
    anchor.rect.y: barSide === "bottom" ? -8 : 0
    anchor.rect.width: anchorItem ? anchorItem.width + (sideways ? 8 : 0) : 0
    anchor.rect.height: anchorItem ? anchorItem.height + (sideways ? 0 : 8) : 0
    anchor.edges: openEdge
    anchor.gravity: openEdge
    anchor.adjustment: PopupAdjustment.Slide

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Quick.theme.bgBase
        border.color: Quick.theme.bgBorder
        border.width: 1
        focus: true
        Keys.onEscapePressed: pop.dismissed()

        ColumnLayout {
            id: column
            x: 16; y: 16
            width: parent.width - 32
            spacing: 12

            // ---- its header ------------------------------------------------------------
            RowLayout {
                visible: pop.title !== ""
                Layout.fillWidth: true
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: (pop.glyph !== "" ? pop.glyph + "  " : "") + pop.title
                        color: Quick.theme.accentPrimary
                        font.family: Quick.mono
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: pop.sub !== ""
                        Layout.fillWidth: true
                        text: pop.sub
                        color: Quick.theme.textMuted
                        font.family: Quick.sans
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
                RowLayout {
                    id: actionsRow
                    spacing: 6
                }
            }

            // ---- what it shows ----------------------------------------------------------
            ColumnLayout {
                id: body
                Layout.fillWidth: true
                spacing: 12
            }

            // ---- its settings -----------------------------------------------------------
            QuickWide {
                visible: pop.settingsLabel !== ""
                Layout.fillWidth: true
                accent: true
                label: pop.settingsLabel
                onClicked: pop.settingsClicked()
            }
        }
    }
}
