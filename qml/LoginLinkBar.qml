import QtQuick
import Quickshell
import QtQuick.Layouts

// Shared placeholder OAuth Login link slot with Copy + Open preview feedback.
// Emits hover/action signals so Clawd's glasses react with a subtle lens glint.
Item {
    id: bar

    property string loginUrl: ""         // from `claude auth login` (ClaudeStore), empty while it starts
    property bool capsuleStyle: false

    property bool copiedState: false
    property bool openState: false

    readonly property bool hovered: urlMa.containsMouse || copyMa.containsMouse || openMa.containsMouse
    readonly property real radiusPx: capsuleStyle ? 27 : 14

    signal sfxRequested(string file, real volume)
    signal openTriggered(string url)

    implicitWidth: 560
    implicitHeight: 54

    function triggerCopy() {
        if (bar.loginUrl === "") return;
        Quickshell.execDetached(["wl-copy", "--", bar.loginUrl]);
        copiedState = true;
        copyReset.restart();
        sfxRequested("claude/tick-2.wav", 0.36);
    }

    function triggerOpen() {
        if (bar.loginUrl === "") return;
        openState = true;
        openReset.restart();
        sfxRequested("claude/wave.wav", 0.34);
        openTriggered(bar.loginUrl);
    }

    Timer { id: copyReset; interval: 1800; onTriggered: bar.copiedState = false }
    Timer { id: openReset; interval: 2000; onTriggered: bar.openState = false }

    Rectangle {
        anchors.fill: parent
        radius: bar.radiusPx
        color: bar.hovered ? "#1A1411" : "#130F0D"
        border.width: 1
        border.color: bar.openState
            ? "#B0E2774A"
            : (bar.hovered ? "#80E2774A" : "#40E2774A")

        Behavior on border.color { ColorAnimation { duration: 160 } }
        Behavior on color { ColorAnimation { duration: 160 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: bar.capsuleStyle ? 18 : 14
            anchors.rightMargin: bar.capsuleStyle ? 8 : 7
            spacing: 8

            Text {
                text: "󰌷"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: "#E2774A"
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: bar.openState ? "Opened in your browser · finish signing in there" : (bar.loginUrl !== "" ? bar.loginUrl : "Getting a sign-in link…")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: bar.openState ? "#F7B58C" : "#DED3C8"
                    elide: Text.ElideMiddle
                }

                MouseArea {
                    id: urlMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.triggerCopy()
                }
            }

            // Copy button
            Rectangle {
                Layout.preferredWidth: copyRow.implicitWidth + 18
                Layout.preferredHeight: 36
                radius: bar.capsuleStyle ? 18 : 10
                color: bar.copiedState
                    ? "#327DD18A"
                    : (copyMa.containsMouse ? "#24FFFFFF" : "#12FFFFFF")
                border.width: 1
                border.color: bar.copiedState
                    ? "#807DD18A"
                    : (copyMa.containsMouse ? "#38FFFFFF" : "#1CFFFFFF")

                Row {
                    id: copyRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: bar.copiedState ? "✓" : "󰆏"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: bar.copiedState ? "#99E8A5" : "#D6C9BC"
                    }
                    Text {
                        text: bar.copiedState ? "Copied" : "Copy"
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: bar.copiedState ? "#C7F5CE" : "#ECE1D6"
                    }
                }

                MouseArea {
                    id: copyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.triggerCopy()
                }
            }

            // Primary Open button
            Rectangle {
                Layout.preferredWidth: openRow.implicitWidth + 22
                Layout.preferredHeight: 36
                radius: bar.capsuleStyle ? 18 : 10
                color: openMa.containsMouse ? "#ED8659" : "#E2774A"
                border.width: 1
                border.color: "#66FFD8BE"

                Row {
                    id: openRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: bar.openState ? "Opened" : "Open"
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: "#150D09"
                    }
                    Text {
                        text: "↗"
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: "#150D09"
                    }
                }

                MouseArea {
                    id: openMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.triggerOpen()
                }
            }
        }
    }
}
