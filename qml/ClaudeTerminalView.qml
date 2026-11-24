import QtQuick
import QMLTermWidget 2.0

// The real terminal (qmltermwidget) running the panel's Claude Code session through launch.sh.
// Loaded by ClaudeTerminal.qml so a machine without qmltermwidget still opens the panel.
Item {
    id: root

    property string program: "bash"
    property var args: []
    property string workDir: ""
    property string colorScheme: ""
    property string fontFamily: "JetBrainsMono Nerd Font"
    property real fontPointSize: 10
    property bool started: false

    signal finished()

    function start() {
        if (started) return;
        started = true;
        session.startShellProgram();
    }
    function sendText(text) { if (started) session.sendText(text); }
    function focusTerminal() { term.forceActiveFocus(); }
    function copySelection() { term.copyClipboard(); }
    function paste() { term.pasteClipboard(); }
    function historyText() { return session.history; }
    // a real key press (arrows, Escape, Tab…), which typed text cannot carry
    function pressKey(key, modifiers) {
        term.simulateKeyPress(key, modifiers || 0, true, 0, "");
        term.simulateKeyPress(key, modifiers || 0, false, 0, "");
    }
    readonly property int shellPid: started ? session.getShellPID() : 0

    // the panel's own background and text over a bundled scheme (only when its own scheme is not available)
    function tint() {
        if (term.colorScheme === "ClaudePanel") return;
        term.setBackgroundColor("#0C0A09");
        term.setForegroundColor("#EFE6DC");
    }
    Component.onCompleted: Qt.callLater(tint)

    QMLTermWidget {
        id: term
        anchors.fill: parent
        anchors.rightMargin: 10
        font.family: root.fontFamily
        font.pointSize: root.fontPointSize
        // a scheme from $COLORSCHEMES_DIR when given (ClaudePanel), else a bundled dark one tinted to the panel below
        colorScheme: root.colorScheme !== "" && availableColorSchemes.indexOf(root.colorScheme) >= 0
            ? root.colorScheme : "DarkPastels"
        onColorSchemeChanged: Qt.callLater(root.tint)
        enableBold: true
        blinkingCursor: true
        session: QMLTermSession {
            id: session
            initialWorkingDirectory: root.workDir
            shellProgram: root.program
            shellProgramArgs: root.args
            onFinished: { root.started = false; root.finished(); }
        }

        // Ctrl+Shift+C / Ctrl+Shift+V copy and paste, as in other Linux terminals
        Keys.onPressed: function(event) {
            if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
                if (event.key === Qt.Key_C) { term.copyClipboard(); event.accepted = true; }
                else if (event.key === Qt.Key_V) { term.pasteClipboard(); event.accepted = true; }
            }
        }
    }

    QMLTermScrollbar {
        terminal: term
        anchors.right: parent.right
        width: 8
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: width / 2
            color: "#E2774A"
            opacity: 0.45
        }
    }
}
