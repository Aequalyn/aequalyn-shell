import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "root:/settings"

Item {
    id: root
    property var theme: null

    property bool lockRequested: false
    property bool authenticatingPassword: false
    property string enteredPassword: ""
    property string failureMessage: ""
    property int failedAttempts: 0
    property string backgroundPath: AequalynSettings.wallpaperPath

    readonly property bool locked: lockRequested || sessionLock.locked || sessionLock.secure

    function beginLock() {
        if (lockRequested) return true
        enteredPassword = ""
        failureMessage = ""
        authenticatingPassword = false
        lockRequested = true
        sessionLock.locked = true
        return true
    }

    function finishUnlock() {
        lockRequested = false
        sessionLock.locked = false
        enteredPassword = ""
        failureMessage = ""
        authenticatingPassword = false
    }

    function submitPassword(value) {
        var password = String(value || "")
        if (!lockRequested || authenticatingPassword || password.length === 0) return
        authenticatingPassword = true
        enteredPassword = ""
        failureMessage = ""
        if (!passwordPam.start()) {
            authenticatingPassword = false
            failureMessage = "Authentication failed"
            failedAttempts += 1
            return
        }
        Qt.callLater(function() {
            if (passwordPam.active && passwordPam.responseRequired) passwordPam.respond(password)
        })
    }

    WlSessionLock {
        id: sessionLock
        locked: false
        WlSessionLockSurface {
            color: "black"
            Item {
                anchors.fill: parent

                Image {
                    anchors.fill: parent
                    source: root.backgroundPath ? "file://" + root.backgroundPath : ""
                    fillMode: Image.PreserveAspectCrop
                }
                Rectangle { anchors.fill: parent; color: Qt.rgba(0,0,0,0.35) }

                Column {
                    anchors.centerIn: parent
                    spacing: 24

                    Text {
                        text: Quickshell.env("USER")
                        color: "white"; font.pixelSize: 28; font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: Qt.formatTime(new Date(), "hh:mm")
                        color: "white"; font.pixelSize: 64; font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Rectangle {
                        width: 380; height: 60; radius: 12
                        color: Qt.rgba(1,1,1,0.12)
                        border.color: root.failureMessage.length > 0 ? "#ef6b73" : "#859dd2"
                        border.width: 2
                        anchors.horizontalCenter: parent.horizontalCenter

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent; anchors.margins: 12
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            enabled: root.lockRequested && !root.authenticatingPassword
                            readOnly: root.authenticatingPassword
                            color: "white"; font.pixelSize: 20
                            onTextChanged: { if (!root.authenticatingPassword) root.enteredPassword = text }
                            onAccepted: {
                                var submitted = root.enteredPassword
                                root.enteredPassword = ""
                                if (submitted.length > 0) root.submitPassword(submitted)
                            }
                            Component.onCompleted: forceActiveFocus()
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: passwordInput.text.length === 0
                            text: root.authenticatingPassword ? "Checking..." : (root.failureMessage.length > 0 ? root.failureMessage : "Password")
                            color: root.failureMessage.length > 0 ? "#ef6b73" : "#a9b1d6"
                            font.pixelSize: 20
                        }
                    }
                }
            }
        }
    }

    PamContext {
        id: passwordPam
        config: "hyprlock"
        user: Quickshell.env("USER") || Quickshell.env("LOGNAME")
        onCompleted: function(result) {
            root.authenticatingPassword = false
            root.enteredPassword = ""
            if (!root.lockRequested) return
            if (result === PamResult.Success) root.finishUnlock()
            else { root.failedAttempts += 1; root.failureMessage = "Authentication failed" }
        }
        onError: function(error) {
            root.authenticatingPassword = false
            root.failedAttempts += 1
            root.failureMessage = "Authentication failed"
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): string {
            if (!root.beginLock()) return "failed"
            return "ok"
        }
        function unlock(): void { root.finishUnlock() }
        function status(): string { return root.locked ? "locked" : "unlocked" }
    }
}