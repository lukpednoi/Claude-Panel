import QtQuick

// Holds the panel's terminal. ClaudeTerminalView.qml imports qmltermwidget; when that module is missing the Loader
// fails alone and this shows how to install it, so the rest of the panel still works.
Item {
    id: root

    property string program: "bash"
    property var args: []
    property string workDir: ""
    property string colorScheme: ""
    property bool autoStart: false
    readonly property bool available: loader.status === Loader.Ready && loader.item !== null
    readonly property bool started: available && loader.item.started
    readonly property int shellPid: available ? loader.item.shellPid : 0
    property bool ended: false            // the session ran and exited (/exit, a crash): offer a new one

    signal finished()

    function start() { if (available) { ended = false; loader.item.start(); } }
    // a fresh terminal (the old one's program has exited) running a new session
    function restart() {
        ended = false;
        loader.active = false;
        Qt.callLater(() => { loader.active = true; Qt.callLater(root.start); });
    }
    function sendText(text) { if (available) loader.item.sendText(text); }
    function focusTerminal() { if (available) loader.item.focusTerminal(); }
    function historyText() { return available ? loader.item.historyText() : ""; }
    function pressKey(key, modifiers) { if (available) loader.item.pressKey(key, modifiers); }

    onAutoStartChanged: if (autoStart && available) start()

    Loader {
        id: loader
        anchors.fill: parent
        source: "ClaudeTerminalView.qml"
        onLoaded: {
            item.program = Qt.binding(() => root.program);
            item.args = Qt.binding(() => root.args);
            item.workDir = Qt.binding(() => root.workDir);
            item.colorScheme = Qt.binding(() => root.colorScheme);
            item.finished.connect(() => { root.ended = true; root.finished(); });
            if (root.autoStart) Qt.callLater(root.start);
        }
    }

    // the session ended: a quiet card over the old screen with a way to start again
    Rectangle {
        visible: root.ended
        anchors.centerIn: parent
        width: endCol.implicitWidth + 40
        height: endCol.implicitHeight + 28
        radius: 14
        color: "#EE161210"
        border.width: 1
        border.color: "#4CE2774A"
        Column {
            id: endCol
            anchors.centerIn: parent
            spacing: 10
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "The Claude session ended"
                font.family: "Google Sans"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: "#FAF4EC"
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: newLbl.implicitWidth + 28
                height: 32
                radius: 9
                color: newMa.containsMouse ? "#3AE2774A" : "#22E2774A"
                border.width: 1
                border.color: "#80E2774A"
                Text {
                    id: newLbl
                    anchors.centerIn: parent
                    text: "Start a new session"
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: "#FFD7BE"
                }
                MouseArea {
                    id: newMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.restart()
                }
            }
        }
    }

    Column {
        visible: loader.status === Loader.Error
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 420)
        spacing: 10
        Text {
            width: parent.width
            text: "The terminal needs qmltermwidget"
            font.family: "Google Sans"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: "#FAF4EC"
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            width: parent.width
            text: "Install Qt6 qmltermwidget (see README), then reopen Claude:"
            font.family: "Google Sans"
            font.pixelSize: 12
            color: "#A99E93"
            horizontalAlignment: Text.AlignHCenter
        }
        Rectangle {
            width: parent.width
            height: 34
            radius: 9
            color: "#161210"
            border.width: 1
            border.color: "#4CE2774A"
            Text {
                anchors.centerIn: parent
                text: "Arch: pacman -S qmltermwidget  ·  Fedora: build Qt6 qmltermwidget"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: "#F2A87C"
            }
        }
    }
}
