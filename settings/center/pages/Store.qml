// Store: search and install software from the Arch repositories or the AUR.
// Search runs pacman/yay; install runs sudo with the password typed in this page.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "Store"
    sub: "Search the Arch repositories or the AUR and install a package."

    property string repo: "arch"          // "arch" | "aur"
    property string query: ""
    property var results: []
    property bool searching: false
    property bool installing: false
    property string status: ""
    property string lastPkg: ""
    property string password: ""
    property string installOutput: ""
    property string installError: ""

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function search() {
        const q = query.trim();
        if (q === "") return;
        searching = true;
        results = [];
        status = "";
        const bin = repo === "aur" ? "yay" : "pacman";
        searchProc.command = [bin, "-Ss", q];
        searchProc.running = true;
    }

    function parseSearch(text) {
        const lines = (text || "").split("\n");
        const out = [];
        let cur = null;
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.trim() === "") continue;
            if (/^\s/.test(line)) {
                if (cur) cur.description = line.trim();
            } else {
                const parts = line.trim().split(/\s+/);
                if (parts.length >= 2) {
                    const namePart = parts[0];
                    const version = parts[1];
                    const st = parts.slice(2).join(" ");
                    const repoName = namePart.indexOf("/") >= 0 ? namePart.split("/")[0] : "";
                    const name = namePart.indexOf("/") >= 0
                        ? namePart.split("/").slice(1).join("/") : namePart;
                    cur = { name: name, repository: repoName, version: version,
                            status: st, description: "" };
                    out.push(cur);
                }
            }
        }
        results = out;
        if (out.length === 0) status = "No results.";
    }

    function install(pkg) {
        console.log("install() called, password length=" + password.length);
        if (installing) return;
        if (password === "") {
            status = "Enter your sudo password first.";
            return;
        }
        installing = true;
        lastPkg = pkg;
        installOutput = "";
        installError = "";
        status = "Installing " + pkg + "…";
        const cmd = repo === "aur"
            ? "yay -S --noconfirm --sudoflags -S " + shellQuote(pkg)
            : "sudo -S pacman -S --noconfirm " + shellQuote(pkg);
        installProc.command = ["sh", "-c", cmd];
        installProc.stdinEnabled = true;
        installProc.running = true;
    }

    property Process searchProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                page.parseSearch(text);
                page.searching = false;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && page.results.length === 0 && page.status === "")
                page.status = "Search failed.";
        }
    }

    property Process installProc: Process {
        stdinEnabled: true
        stdout: StdioCollector { id: installStdout }
        stderr: StdioCollector { id: installStderr }
        onStarted: {
            installProc.write(page.password + "\n");
            installProc.stdinEnabled = false;
        }
        onExited: (exitCode, exitStatus) => {
            page.installing = false;
            if (exitCode === 0) page.status = "Installed " + page.lastPkg + ".";
            else {
                const msg = (installStderr.text || installStdout.text || "").trim();
                page.status = "Install failed (exit " + exitCode + "). " + msg.slice(0, 240);
            }
        }
    }

    // Authentication
    CcSection {
        title: "Authentication"
        hint: "Your sudo password, used only in this page."

        CcField {
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholder: "Sudo password"
            text: page.password
            onTextChanged: page.password = text
        }
    }

    // Source
    CcSection {
        title: "Source"
        hint: "Where to look for packages."

        CcChoice {
            options: [
                { key: "arch", label: "Arch repositories" },
                { key: "aur",  label: "AUR" }
            ]
            current: page.repo
            onChosen: key => {
                page.repo = key;
                page.results = [];
                page.status = "";
            }
        }
    }

    // Search
    CcSection {
        title: "Search"
        hint: "Type a package name and press Enter."

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            CcField {
                id: searchField
                Layout.fillWidth: true
                placeholder: "Package name, like firefox"
                text: page.query
                onTextChanged: page.query = text
                onAccepted: page.search()
            }
            CcButton {
                text: page.searching ? "Searching…" : "Search"
                primary: true
                enabled: !page.searching && !page.installing
                onClicked: page.search()
            }
        }
    }

    // Results
    CcSection {
        title: "Results"
        hint: page.results.length + " package" + (page.results.length !== 1 ? "s" : "")

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 320
            radius: 10
            color: Cc.theme.bgBase
            border.color: Cc.theme.bgBorder
            border.width: 1
            clip: true

            ListView {
                id: resultsList
                anchors.fill: parent
                anchors.margins: 6
                model: page.results
                clip: true
                spacing: 4

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: resultsList.width
                    height: 62
                    radius: 8
                    color: Cc.theme.bgSurface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: row.modelData.name
                                color: Cc.theme.textPrimary
                                font.family: Cc.sans
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: row.modelData.version
                                    + (row.modelData.status !== "" ? "  ·  " + row.modelData.status : "")
                                color: Cc.theme.textMuted
                                font.family: Cc.mono
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: row.modelData.description
                                color: Cc.theme.textMuted
                                font.family: Cc.sans
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: text !== ""
                            }
                        }

                        CcButton {
                            text: page.password === "" ? "Enter sudo" : "Install"
                            primary: page.password !== ""
                            warning: page.password === ""
                            enabled: !page.installing
                            onClicked: page.install(row.modelData.name)
                        }
                    }
                }

                // empty state
                Text {
                    anchors.centerIn: parent
                    visible: resultsList.count === 0 && !page.searching
                    text: page.status !== "" ? page.status : "Search for a package above."
                    color: Cc.theme.textMuted
                    font.family: Cc.sans
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width - 24
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // Output
    CcSection {
        title: "Output"
        hint: "Live output of the current install."

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            radius: 10
            color: Cc.theme.bgBase
            border.color: Cc.theme.bgBorder
            border.width: 1
            clip: true

            Flickable {
                id: outFlick
                anchors.fill: parent
                anchors.margins: 6
                contentWidth: outText.implicitWidth
                contentHeight: outText.implicitHeight
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: outText
                    width: outFlick.width
                    text: installStdout.text + (installStderr.text !== "" ? "\n" + installStderr.text : "")
                    color: Cc.theme.textPrimary
                    font.family: Cc.mono
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }

                onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
            }
        }
    }

    // Fuzzy finder (terminal)
    CcSection {
        title: "Fuzzy finder (terminal)"
        hint: "Browse every package with fzf if you don't know the exact name."

        CcRow {
            icon: "\u{F034A}"
            title: "Arch repositories (fzf)"
            sub: "Pick one or more packages from all repositories."
            action: "Open"
            onActivated: page.launchTerminal("aequalyn-pkg-install")
        }
        CcRow {
            icon: "\u{F034A}"
            title: "AUR (fzf)"
            sub: "Pick one or more packages from the AUR."
            action: "Open"
            onActivated: page.launchTerminal("aequalyn-pkg-aur-install")
        }
    }

    function launchTerminal(cmd) {
        const q = shellQuote(cmd);
        const script = "if command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec " + cmd
            + "; elif command -v kitty >/dev/null 2>&1; then exec kitty sh -c " + q
            + "; elif command -v foot >/dev/null 2>&1; then exec foot sh -c " + q
            + "; elif command -v alacritty >/dev/null 2>&1; then exec alacritty -e sh -c " + q
            + "; elif command -v gnome-terminal >/dev/null 2>&1; then exec gnome-terminal -- sh -c " + q
            + "; else echo 'No terminal emulator found.'; fi";
        Quickshell.execDetached(["sh", "-c", script]);
    }

    CcNote {
        visible: page.status !== "" && page.results.length > 0
        text: page.status
        color: page.status.indexOf("failed") >= 0 ? Cc.theme.accentRed
              : page.status.indexOf("Installed") >= 0 ? Cc.theme.accentGreen
              : Cc.theme.textMuted
    }

    CcNote {
        text: "Enter your sudo password above. Packages from the AUR are built locally with yay."
    }
}