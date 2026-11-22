// Glance's quick panel: daemon state, enrollment, lock-screen wiring, last scan,
// and arm/disarm/test-scan actions.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "root:/settings"
import "root:/plugins/bar/quick"
import "GlanceLogic.js" as GlanceLogic

QuickPopup {
    id: q
    required property var bar
    property var backend

    readonly property var status: backend ? backend.status : null
    readonly property string stateLabel: GlanceLogic.stateLabel(status)
    readonly property var nextAction: backend && backend.binaryOk ? backend.nextAction : null

    property double nowMs: Date.now()
    property string passphrase: ""

    Timer {
        interval: 1000
        running: q.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: q.nowMs = Date.now()
    }

    onVisibleChanged: {
        if (visible) {
            q.nowMs = Date.now()
            if (backend) backend.refresh()
            if (q.backend && q.backend.canArm) Qt.callLater(function() { passField.forceActiveFocus() })
        } else {
            q.passphrase = ""
        }
    }

    glyph: "\u{F0431}"
    // Actually set glyph via property after? QuickPopup glyph string.
    // We'll override by setting property in component:
    // (cannot have duplicate). Use title only.
    title: "Glance"
    sub: q.stateLabel
    settingsLabel: ""
    panelWidth: 380

    // Header count detail not in QuickPopup; add as sub maybe.
    // We'll append identities count to sub when armed.
    // Recompute sub:
    // (QuickPopup sub binding already; override below impossible). Instead set sub in onVisible? 
    // Use a property and binding via `sub` property assignment in component is fine; but we want dynamic.
    // We'll leave sub as stateLabel; details in body.

    function severityColor(severity) {
        if (severity === "good") return Quick.theme.accentGreen
        if (severity === "bad") return Quick.theme.accentRed
        return Quick.theme.textPrimary
    }

    function submitArm(remember) {
        if (!q.backend || !q.backend.canArm || q.passphrase === "" || q.backend.actionBusy) return
        q.backend.arm(q.passphrase, remember)
        q.passphrase = ""
    }

    // --- body ---
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 12

        // next action
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: q.nextAction !== null && !(q.backend && q.backend.binaryMissing) && (q.backend ? q.backend.fetchError === "" : true)

            Text {
                Layout.fillWidth: true
                text: q.nextAction ? q.nextAction.explain : ""
                color: Quick.theme.textPrimary
                wrapMode: Text.WordWrap
                font.family: Quick.sans
                font.pixelSize: 12
            }

            QuickWide {
                visible: q.nextAction !== null && q.nextAction.command !== null
                glyph: q.nextAction ? q.nextAction.icon : ""
                label: q.nextAction ? q.nextAction.label : ""
                onClicked: { if (q.backend) q.backend.runNextAction() }
            }

            Text {
                Layout.fillWidth: true
                visible: !(q.backend && q.backend.canArm)
                text: q.nextAction ? q.nextAction.hint : ""
                color: Quick.theme.textMuted
                wrapMode: Text.WrapAnywhere
                font.family: Quick.mono
                font.pixelSize: 10
            }

            Text {
                Layout.fillWidth: true
                visible: q.backend && q.backend.launchError !== ""
                text: q.backend ? q.backend.launchError : ""
                color: Quick.theme.accentRed
                wrapMode: Text.WordWrap
                font.family: Quick.sans
                font.pixelSize: 10
            }
        }

        // arming inline
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: q.backend && q.backend.canArm

            TextField {
                id: passField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Passphrase"
                text: q.passphrase
                enabled: !(q.backend && q.backend.actionBusy)
                onTextChanged: if (text !== q.passphrase) q.passphrase = text
                onAccepted: q.submitArm(false)
                Keys.onEscapePressed: q.dismissed()
            }

            RowLayout {
                spacing: 8
                Button {
                    text: "Arm"
                    enabled: q.passphrase !== "" && !(q.backend && q.backend.actionBusy)
                    onClicked: q.submitArm(false)
                }
                Button {
                    text: "Arm and remember"
                    enabled: q.passphrase !== "" && !(q.backend && q.backend.actionBusy)
                    onClicked: q.submitArm(true)
                }
            }
        }

        // identities
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: q.status && q.status.armed && q.status.identities.length > 0

            Text {
                text: "Enrolled"
                color: Quick.theme.accentPrimary
                font.family: Quick.mono
                font.pixelSize: 12
                font.bold: true
            }
            Repeater {
                model: q.status ? q.status.identities : []
                delegate: Text {
                    required property var modelData
                    Layout.fillWidth: true
                    text: GlanceLogic.identityLine(modelData)
                    color: modelData.enabled === false ? Quick.theme.textMuted : Quick.theme.textPrimary
                    elide: Text.ElideRight
                    font.family: Quick.sans
                    font.pixelSize: 12
                }
            }
            Text {
                Layout.fillWidth: true
                text: {
                    if (!q.status) return ""
                    var parts = []
                    if (q.status.camera !== "") parts.push(q.status.camera)
                    parts.push(q.status.remembered ? "passphrase remembered" : "arm again after login")
                    return parts.join(" · ")
                }
                color: Quick.theme.textMuted
                elide: Text.ElideRight
                font.family: Quick.sans
                font.pixelSize: 10
            }
        }

        // lock screen
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: GlanceLogic.lockLabel(q.status) !== ""

            Text {
                text: "Lock screen"
                color: Quick.theme.accentPrimary
                font.family: Quick.mono
                font.pixelSize: 12
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: GlanceLogic.lockLabel(q.status)
                color: q.status && q.status.pam && q.status.pam.wired === true ? Quick.theme.textPrimary : Quick.theme.textMuted
                wrapMode: Text.WordWrap
                font.family: Quick.sans
                font.pixelSize: 12
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: GlanceLogic.indicatorLabel(q.status)
                color: q.status && q.status.lock && q.status.lock.patched === true ? Quick.theme.textPrimary : Quick.theme.textMuted
                wrapMode: Text.WordWrap
                font.family: Quick.sans
                font.pixelSize: 12
            }
        }

        // last scan
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: q.status && q.status.lastScan !== null

            Text {
                text: "Last scan"
                color: Quick.theme.accentPrimary
                font.family: Quick.mono
                font.pixelSize: 12
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: GlanceLogic.lastScanText(q.status, q.nowMs)
                color: q.severityColor(GlanceLogic.outcomeSeverity(q.status && q.status.lastScan ? q.status.lastScan.outcome : ""))
                wrapMode: Text.WordWrap
                font.family: Quick.sans
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: GlanceLogic.lastScanReason(q.status)
                color: Quick.theme.textMuted
                wrapMode: Text.WordWrap
                font.family: Quick.sans
                font.pixelSize: 10
            }
        }

        // action feedback
        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: {
                if (!q.backend) return ""
                if (q.backend.actionName === "authenticate") return "Scanning — look at the camera..."
                if (q.backend.actionName !== "") return "Running " + q.backend.actionName + "..."
                if (q.backend.actionResult && q.backend.actionResult.error !== "") return q.backend.actionResult.error
                return ""
            }
            color: q.backend && q.backend.actionBusy ? Quick.theme.textPrimary : Quick.theme.accentRed
            wrapMode: Text.WordWrap
            font.family: Quick.sans
            font.pixelSize: 12
        }

        // binary missing
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: q.backend && q.backend.binaryMissing

            Text {
                Layout.fillWidth: true
                text: "glancectl is not usable"
                color: Quick.theme.accentRed
                wrapMode: Text.WordWrap
                font.family: Quick.sans
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            Text {
                Layout.fillWidth: true
                visible: q.backend && q.backend.binaryProblem !== ""
                text: q.backend ? q.backend.binaryProblem : ""
                color: Quick.theme.textPrimary
                wrapMode: Text.WrapAnywhere
                font.family: Quick.mono
                font.pixelSize: 10
            }
            Text {
                Layout.fillWidth: true
                text: "Install the glanced package, or set 'glancectl path' in settings."
                color: Quick.theme.textMuted
                wrapMode: Text.WordWrap
                font.family: Quick.sans
                font.pixelSize: 10
            }

            QuickWide {
                Layout.fillWidth: true
                glyph: "\u{F0193}"
                label: "Install glanced"
                onClicked: {
                    const cmd = "lock=\"$HOME/.config/quickshell/plugins/bar/widgets/glanced-0.4.0.lock\"; "
                        + "[ -f \"$lock\" ] || lock=\"$HOME/Projects/aequalyn-shell/plugins/bar/widgets/glanced-0.4.0.lock\"; "
                        + "python -m venv ~/.local/share/glance && "
                        + "~/.local/share/glance/bin/pip install --require-hashes -r \"$lock\" && "
                        + "~/.local/share/glance/bin/glancectl setup"
                    Quickshell.execDetached(["/usr/bin/xdg-terminal-exec", "sh", "-c", cmd])
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: q.backend && !q.backend.binaryMissing && q.backend.fetchError !== ""
            text: q.backend ? q.backend.fetchError : ""
            color: Quick.theme.accentRed
            wrapMode: Text.WordWrap
            font.family: Quick.sans
            font.pixelSize: 12
        }

        // footer
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                color: Quick.theme.textMuted
                font.family: Quick.sans
                font.pixelSize: 10
                text: {
                    if (!q.backend) return ""
                    if (q.backend.loading && q.backend.lastSuccessAt <= 0) return "Checking..."
                    if (q.backend.lastSuccessAt <= 0) return "Not checked yet"
                    return "Updated " + GlanceLogic.elapsed(q.backend.lastSuccessAt, q.nowMs)
                }
            }

            QuickWide {
                visible: q.backend && q.backend.status && q.backend.status.reachable && q.backend.status.armed
                glyph: "\u{F0146}" // no, use disarm icon
                // We'll just use text label via QuickWide? QuickWide uses glyph+label. Use label.
                label: "Disarm"
                onClicked: { if (q.backend) q.backend.disarm() }
            }
            QuickWide {
                glyph: "\u{F018D}"
                label: "Scan"
                enabled: q.backend ? q.backend.canScan : false
                onClicked: { if (q.backend && q.backend.canScan) q.backend.testScan() }
            }
            QuickWide {
                glyph: "\u{F018D}" // refresh icon? use sync
                label: "Refresh"
                onClicked: { if (q.backend) q.backend.refresh() }
            }
        }
    }
}
