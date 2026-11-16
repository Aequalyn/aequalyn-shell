// Optional coding agents, installed into this user's Aequalyn data directory.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "AI tools"
    sub: "Install command line coding agents for your own account. Each one stays optional."

    property var tools: []
    property string status: ""
    property string output: ""
    property string activeTool: ""
    property bool busy: false

    Component.onCompleted: refresh()

    function refresh() {
        if (busy) return;
        listProc.command = ["aequalyn-ai-tool", "list", "--json"];
        listProc.running = true;
    }

    function run(id, action) {
        if (busy) return;
        busy = true;
        activeTool = id;
        status = action === "install" ? "Installing…"
               : action === "update" ? "Updating…" : "Removing…";
        output = "";
        actionProc.command = ["aequalyn-ai-tool", action, id];
        actionProc.running = true;
    }

    function openStore() { Cc.go("store"); }

    function launch(command) {
        const q = "'" + String(command).replace(/'/g, "'\\''") + "'";
        const script = "if command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec " + q
            + "; elif command -v kitty >/dev/null 2>&1; then exec kitty sh -lc " + q
            + "; elif command -v foot >/dev/null 2>&1; then exec foot sh -lc " + q
            + "; elif command -v alacritty >/dev/null 2>&1; then exec alacritty -e sh -lc " + q
            + "; elif command -v gnome-terminal >/dev/null 2>&1; then exec gnome-terminal -- sh -lc " + q
            + "; else echo 'No terminal emulator found.'; fi";
        Quickshell.execDetached(["sh", "-c", script]);
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.tools = JSON.parse(text);
                    if (page.status === "Loading tools…") page.status = "";
                } catch (e) {
                    page.status = "Could not read the AI tool list.";
                }
            }
        }
        stderr: StdioCollector {}
        onStarted: page.status = page.tools.length === 0 ? "Loading tools…" : page.status
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && page.tools.length === 0)
                page.status = "Aequalyn's AI tool manager could not start. Reinstall or update Aequalyn first.";
        }
    }

    Process {
        id: actionProc
        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector { id: actionError }
        onExited: (exitCode, exitStatus) => {
            page.busy = false;
            page.output = actionOutput.text
                + (actionError.text !== "" ? (actionOutput.text !== "" ? "\n" : "") + actionError.text : "");
            page.status = exitCode === 0 ? "Finished." : "The action failed. See the output below.";
            page.refreshTimer.restart();
        }
    }

    Timer {
        id: refreshTimer
        interval: 250
        onTriggered: page.refresh()
    }

    CcSection {
        title: "Coding agents"
        hint: "Most tools use their publisher's npm package; Antigravity uses Google's official CLI installer. Sign-in stays with each provider."

        Repeater {
            model: page.tools
            delegate: CcRow {
                required property var modelData
                enabled: !page.busy
                icon: "\u{F06A9}"
                title: modelData.name
                sub: modelData.description + (modelData.package ? "  ·  npm: " + modelData.package : "  ·  Google's official installer")
                    + (modelData.installed ? "  ·  " + modelData.command + " " + modelData.version
                       : modelData.availableElsewhere ? "  ·  Already available at " + modelData.availablePath
                       : modelData.launcherConflict ? "  ·  A file already uses the " + modelData.command + " command"
                       : "  ·  " + modelData.command)
                busy: page.busy && page.activeTool === modelData.id
                clickable: modelData.installed || modelData.availableElsewhere
                action: modelData.installed ? "Update"
                      : modelData.availableElsewhere ? "Open"
                      : modelData.launcherConflict ? "In use" : "Install"
                action2: modelData.installed ? "Remove" : ""
                primary: !modelData.installed && !modelData.availableElsewhere && !modelData.launcherConflict
                onActivated: {
                    if (modelData.installed) page.run(modelData.id, "update");
                    else if (modelData.availableElsewhere) page.launch(modelData.command);
                    else if (!modelData.launcherConflict)
                        page.run(modelData.id, "install");
                }
                onActivated2: page.run(modelData.id, "remove")
                onClicked: page.launch(modelData.command)
            }
        }

        CcNote {
            visible: page.tools.length === 0
            text: page.status !== "" ? page.status : "Loading tools…"
            color: page.status.indexOf("could not") >= 0 ? Cc.theme.accentRed : Cc.theme.textMuted
        }
    }

    CcSection {
        title: "Programming tools"
        hint: "Aequalyn's optional Developer profile already includes mise, Git, GitHub CLI, Node.js, Python, Go, Rust and Docker."

        CcRow {
            icon: "\u{F034A}"
            title: "Install or browse packages"
            sub: "Open the Store to add runtimes, editors and other Arch or AUR packages. Search for nodejs and npm if an AI tool needs them."
            action: "Open Store"
            onActivated: page.openStore()
        }
        CcNote {
            text: "npm-based agents use your system Node.js/npm or mise's Node LTS. Install mise or nodejs/npm from the Store if neither is available. Antigravity uses a native installer."
        }
    }

    CcNote {
        visible: page.status !== "" && page.tools.length > 0
        text: page.status
        color: page.status.indexOf("failed") >= 0 ? Cc.theme.accentRed : Cc.theme.accentGreen
    }

    CcSection {
        title: "Install output"
        visible: page.output !== ""
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            radius: 10
            color: Cc.theme.bgBase
            border.color: Cc.theme.bgBorder
            border.width: 1
            clip: true

            Flickable {
                id: outputFlick
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: outputText.implicitWidth
                contentHeight: outputText.implicitHeight
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                Text {
                    id: outputText
                    width: outputFlick.width
                    text: page.output
                    color: Cc.theme.textPrimary
                    font.family: Cc.mono
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }
                onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
            }
        }
    }

    CcNote {
        text: "Aequalyn installs npm tools into its own data directory. Antigravity uses Google's official installer in your user account. Authentication happens when you launch a tool in a terminal."
    }
}
