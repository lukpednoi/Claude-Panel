pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Center Workspace shared across VS Code Studio concepts:
// - VS Code Tab bar: [ >_ Terminal ] | [ OpenedFile.qml × ]
// - Content slot: the real terminal (ClaudeTerminal) with a "Claude is waiting" banner
//   OR line-numbered VS Code File/Diff Preview showing exact path & what Claude wrote.
Rectangle {
    id: center

    property bool agentRunning: false
    property bool cursorActive: true
    property string cliVersion: ""
    property string currentDir: "~"
    property string statusToast: ""
    // the real terminal: launch.sh runs the panel's Claude Code session in it
    property string launchScript: ""
    property var launchArgs: []
    property string workDir: ""
    property bool terminalAutoStart: false
    property bool needsAttention: false
    property string attentionText: ""
    readonly property alias terminal: claudeTerm
    property var openTabs: []          // array of file objects from StudioMockData
    property string activeTabId: "terminal" // "terminal" | <file.id>

    signal selectTab(string tabId)
    signal closeTab(string tabId)
    signal foldRequested()

    readonly property var activeFile: {
        if (activeTabId === "terminal") return null;
        for (let i = 0; i < openTabs.length; i++) {
            if (openTabs[i].id === activeTabId) return openTabs[i];
        }
        return null;
    }

    radius: 16
    color: "#0C0A09"
    border.color: "#44E2774A"
    border.width: 1
    clip: true

    // Subtle warm top glow
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 96
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1CE2774A" }
            GradientStop { position: 1.0; color: "#00E2774A" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // VS Code Editor / Terminal Tab Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: "#110E0C"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: "#1AFFFFFF"
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#22FFFFFF"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 4

                // Pinned Terminal Tab
                Rectangle {
                    id: termTab
                    readonly property bool selected: center.activeTabId === "terminal"
                    Layout.preferredWidth: termRow.implicitWidth + 24
                    Layout.fillHeight: true
                    color: selected ? "#0C0A09" : (termTabMa.containsMouse ? "#15FFFFFF" : "transparent")

                    Rectangle {
                        visible: termTab.selected
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 2
                        color: "#E2774A"
                    }

                    Row {
                        id: termRow
                        anchors.centerIn: parent
                        spacing: 7
                        Text {
                            text: "❯_"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: termTab.selected ? "#E2774A" : "#8E8379"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Terminal"
                            font.family: "Google Sans"
                            font.pixelSize: 12
                            font.weight: termTab.selected ? Font.DemiBold : Font.Medium
                            color: termTab.selected ? "#FAF4EC" : "#B5ABA0"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: termTabMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { center.selectTab("terminal"); claudeTerm.focusTerminal(); }
                    }
                }

                // Dynamic File Preview Tabs
                Repeater {
                    model: center.openTabs
                    delegate: Rectangle {
                        id: fTab
                        required property var modelData
                        readonly property bool selected: center.activeTabId === fTab.modelData.id
                        Layout.preferredWidth: Math.min(200, fTabRow.implicitWidth + 20)
                        Layout.fillHeight: true
                        color: selected ? "#0C0A09" : (fTabMa.containsMouse ? "#15FFFFFF" : "transparent")

                        Rectangle {
                            visible: fTab.selected
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 2
                            color: "#E2774A"
                        }

                        MouseArea {
                            id: fTabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: center.selectTab(fTab.modelData.id)
                        }

                        Row {
                            id: fTabRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: fTab.modelData.badge
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: fTab.modelData.badge === "A" ? "#7DD18A" : (fTab.modelData.badge === "M" ? "#F0A472" : "#8E8379")
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: fTab.modelData.name
                                font.family: "Google Sans"
                                font.pixelSize: 12
                                font.weight: fTab.selected ? Font.DemiBold : Font.Medium
                                color: fTab.selected ? "#FAF4EC" : "#BEB4AA"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                color: fCloseMa.containsMouse ? "#32FFFFFF" : "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.pixelSize: 9
                                    color: fCloseMa.containsMouse ? "#FAF4EC" : "#8E8379"
                                }
                                MouseArea {
                                    id: fCloseMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: center.closeTab(fTab.modelData.id)
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // fold the panel into its corner dome (the session keeps running; SUPER + C does the same)
                Rectangle {
                    id: foldBtn
                    Layout.preferredWidth: foldRow.implicitWidth + 20
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    radius: 8
                    color: foldMa.containsMouse ? "#28E2774A" : "#14FFFFFF"
                    border.width: 1
                    border.color: foldMa.containsMouse ? "#68E2774A" : "#22FFFFFF"
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Row {
                        id: foldRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "↙"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: foldMa.containsMouse ? "#FFAA7A" : "#E2774A"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Fold"
                            font.family: "Google Sans"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: foldMa.containsMouse ? "#FAF4EC" : "#C9BEB3"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: foldMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: center.foldRequested()
                    }
                }
            }
        }

        // TAB BODY
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // VIEW 1: the real terminal (kept alive while a file tab is shown, so the session never stops)
            Item {
                anchors.fill: parent
                visible: center.activeFile === null

                ClaudeTerminal {
                    id: claudeTerm
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    anchors.topMargin: 10
                    anchors.bottomMargin: center.needsAttention ? 58 : 10
                    program: "bash"
                    args: [center.launchScript].concat(center.launchArgs)
                    workDir: center.workDir
                    colorScheme: "ClaudePanel"
                    autoStart: center.terminalAutoStart
                }

                // Claude is waiting for an answer (a permission prompt, a question): point at the terminal
                Rectangle {
                    visible: center.needsAttention
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    height: 38
                    radius: 10
                    color: "#161210"
                    border.width: 1
                    border.color: "#8CE2774A"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        Text {
                            text: "●"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: "#FFAA7A"
                        }
                        Text {
                            Layout.fillWidth: true
                            text: center.attentionText !== "" ? center.attentionText : "Claude is waiting for you in the terminal"
                            font.family: "Google Sans"
                            font.pixelSize: 12
                            color: "#EFE6DC"
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: claudeTerm.focusTerminal()
                    }
                }
            }

            // VIEW 2: VS Code File / Diff Preview (shows exact path & what Claude edited)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12
                visible: center.activeFile !== null

                // File Breadcrumb & Summary Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: 10
                    color: "#13100E"
                    border.width: 1
                    border.color: "#22FFFFFF"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                width: parent.width
                                text: center.activeFile ? center.activeFile.path : ""
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: "#F2A87C"
                                elide: Text.ElideMiddle
                            }
                            Text {
                                width: parent.width
                                text: center.activeFile ? center.activeFile.summary : ""
                                font.family: "Google Sans"
                                font.pixelSize: 11
                                color: "#9C9084"
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: backTermLbl.implicitWidth + 18
                            Layout.preferredHeight: 26
                            radius: 8
                            color: backTermMa.containsMouse ? "#28E2774A" : "#14FFFFFF"
                            border.width: 1
                            border.color: backTermMa.containsMouse ? "#68E2774A" : "#22FFFFFF"
                            Text {
                                id: backTermLbl
                                anchors.centerIn: parent
                                text: "Back to Terminal"
                                font.family: "Google Sans"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: "#EFE6DC"
                            }
                            MouseArea {
                                id: backTermMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: center.selectTab("terminal")
                            }
                        }
                    }
                }

                // Line-numbered Diff / Code Viewer
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: "#090706"
                    border.width: 1
                    border.color: "#1BFFFFFF"
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 10
                        contentHeight: codeCol.implicitHeight
                        clip: true

                        Column {
                            id: codeCol
                            width: parent.width
                            spacing: 3

                            Repeater {
                                model: center.activeFile ? center.activeFile.lines : []
                                delegate: Rectangle {
                                    id: lineRow
                                    required property var modelData
                                    width: codeCol.width
                                    height: 24
                                    radius: 4
                                    color: {
                                        if (modelData.kind === "add") return "#227DD18A";
                                        if (modelData.kind === "del") return "#24E06C62";
                                        return "transparent";
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 12

                                        Text {
                                            Layout.preferredWidth: 32
                                            text: lineRow.modelData.num
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            color: "#6A6058"
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: lineRow.modelData.code
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            color: {
                                                if (lineRow.modelData.kind === "add") return "#A8F0B4";
                                                if (lineRow.modelData.kind === "del") return "#F4A49B";
                                                return "#D8CEC4";
                                            }
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
