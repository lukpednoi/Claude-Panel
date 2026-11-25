pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Studio Minimal (VS Code Activity Bar Edition — Design 1/3):
// - Left Rail (25%): 44px VS Code Activity Bar (Files [3] | Commands | Sessions | Settings) + full-height pane
//     * Files: EDITED BY CLAUDE w/ paths + WORKSPACE FILES
//     * Commands: Filter + Starred top group (230ms hold-drag reorder) + Unstarred below (no duplicate pinned bar)
//     * Sessions: Recent conversations w/ Resume button (hides from Activity Bar if turned off in Settings)
//     * Settings: Selectable panel visibility toggles
// - Center (50%): ClawdMascot + v2.1.326 + ~ + VS Code Tabbed Terminal / File Diff Viewer
// - Right Rail (25%): Model & Effort slide-down accordion + Token & single-bar Context + spacious Task Checklist
Item {
    id: studio

    property real stageWidth: 1380
    property real stageHeight: 770
    property bool showCloseButton: false
    property bool cursorActive: true
    property bool agentRunning: false
    property string activeSection: "files" // "files" | "commands" | "sessions" | "settings"

    required property var store              // ClaudeStore (live) — StudioMockData has the same shape for previews
    property var updater: null               // ClaudeUpdater (optional — standalone panel self-updater)
    property bool terminalAutoStart: false
    property string statusToast: ""
    property var openTabIds: []
    // tabs follow the store, so a file Claude edits again shows its newest diff
    readonly property var openTabs: openTabIds.map(id => store.fileById(id)).filter(f => f !== null)
    property string activeTabId: "terminal"
    readonly property var terminal: centerEditor.terminal

    signal foldRequested()
    signal closeRequested()
    signal toggleRunningRequested()

    function openFileTab(fileObj) {
        if (!fileObj) return;
        if (openTabIds.indexOf(fileObj.id) < 0) openTabIds = openTabIds.concat([fileObj.id]);
        activeTabId = fileObj.id;
    }

    function closeFileTab(tabId) {
        const list = openTabIds.filter(id => id !== tabId);
        openTabIds = list;
        if (activeTabId === tabId) activeTabId = list.length > 0 ? list[list.length - 1] : "terminal";
    }

    // Everything the panel does goes through the terminal, typed just as the user would type it.
    // Commands that need an argument are only typed; the rest run at once.
    readonly property var argCommands: ["/rename", "/export", "/memory", "/add-dir"]
    function typeIntoTerminal(text, run) {
        activeTabId = "terminal";
        if (!terminal) return;
        terminal.sendText(text + (run ? "\r" : ""));
        terminal.focusTerminal();
    }
    function runCommand(cmdName) {
        const builtin = store.builtinCommands.some(c => c.cmd === cmdName);
        typeIntoTerminal(builtin && argCommands.indexOf(cmdName) < 0 ? cmdName : cmdName + " ", builtin && argCommands.indexOf(cmdName) < 0);
    }
    // Claude Code resumes a session only in the folder it ran in: start the terminal again there with --resume
    function resumeSession(sessionObj) {
        if (!sessionObj || sessionObj.id === store.sessionId || !terminal) return;
        activeTabId = "terminal";
        store.launchArgs = ["--resume", sessionObj.id];
        if (sessionObj.cwd) store.cwd = sessionObj.cwd;
        terminal.restart();
        terminal.focusTerminal();
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        // LEFT RAIL (25%): 44px VS Code Vertical Activity Bar + Dedicated Active Pane
        Rectangle {
            Layout.preferredWidth: Math.round(studio.stageWidth * 0.25)
            Layout.fillHeight: true
            radius: 16
            color: "#151210"
            border.color: "#24FFFFFF"
            border.width: 1
            clip: true

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // Far-left 44px VS Code Activity Bar
                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.fillHeight: true
                    color: "#100D0B"

                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        width: 1
                        color: "#1DFFFFFF"
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 6

                        Repeater {
                            model: [
                                { id: "files", glyph: "󰉋", show: studio.store.showEditedFiles || studio.store.showWorkspaceFiles },
                                { id: "commands", glyph: "❯_", show: true },
                                { id: "sessions", glyph: "↺", show: studio.store.showSessions },
                                { id: "settings", glyph: "⚙", show: true }
                            ]
                            delegate: Item {
                                id: actBtn
                                required property var modelData
                                readonly property bool active: studio.activeSection === modelData.id
                                visible: modelData.show
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44

                                Rectangle {
                                    visible: actBtn.active
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 24
                                    radius: 1.5
                                    color: "#E2774A"
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 32
                                    height: 32
                                    radius: 9
                                    color: actBtn.active ? "#26E2774A" : (actMa.containsMouse ? "#15FFFFFF" : "transparent")
                                    Text {
                                        anchors.centerIn: parent
                                        text: actBtn.modelData.glyph
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 15
                                        color: actBtn.active ? "#FFA778" : (actMa.containsMouse ? "#EFE6DC" : "#8D8278")
                                    }
                                }

                                // Orange badge showing count of files edited by Claude
                                Rectangle {
                                    visible: actBtn.modelData.id === "files" && studio.store.showEditedFiles
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: 4
                                    anchors.bottomMargin: 4
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: "#E2774A"
                                    Text {
                                        anchors.centerIn: parent
                                        text: studio.store.editedFiles.length
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        color: "#150D09"
                                    }
                                }

                                // Orange dot on Settings when a panel update is available or waiting for restart
                                Rectangle {
                                    visible: actBtn.modelData.id === "settings"
                                        && studio.updater !== null
                                        && (studio.updater.updateAvailable || studio.updater.restartNeeded)
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.rightMargin: 6
                                    anchors.topMargin: 6
                                    width: 7
                                    height: 7
                                    radius: 3.5
                                    color: studio.updater && studio.updater.restartNeeded ? "#7DD18A" : "#E2774A"
                                    border.width: 1
                                    border.color: "#100D0B"
                                }

                                MouseArea {
                                    id: actMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: studio.activeSection = actBtn.modelData.id
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // Active Sidebar Body (full height next to Activity Bar)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Row {
                            spacing: 8
                            ClaudeLogo {
                                size: 16
                                color: "#E2774A"
                                glowOpacity: 0.35
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Claude Code"
                                font.family: "Google Sans"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: "#F8F2EA"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: studio.activeSection.toUpperCase()
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 9
                            font.letterSpacing: 0.6
                            color: "#8E8379"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#1BFFFFFF"
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        StudioFilesPane {
                            anchors.fill: parent
                            visible: studio.activeSection === "files"
                            store: studio.store
                            activeFileId: studio.activeTabId
                            onFileActivated: function(f) { studio.openFileTab(f) }
                        }

                        StudioCommandsPane {
                            anchors.fill: parent
                            visible: studio.activeSection === "commands"
                            store: studio.store
                            onCommandTriggered: function(c) { studio.runCommand(c) }
                        }

                        StudioSessionsPane {
                            anchors.fill: parent
                            visible: studio.activeSection === "sessions"
                            store: studio.store
                            activeSessionId: studio.store.sessionId
                            onSessionResumed: function(s) { studio.resumeSession(s) }
                        }

                        StudioFunctionsPane {
                            anchors.fill: parent
                            visible: studio.activeSection === "settings"
                            store: studio.store
                            updater: studio.updater
                        }
                    }
                }
            }
        }

        // CENTER (50%): Clean Clawd + v2.1.326 + ~ + VS Code Tabbed Terminal / File Diff Viewer
        StudioCenterEditor {
            id: centerEditor
            Layout.fillWidth: true
            Layout.fillHeight: true
            agentRunning: studio.agentRunning
            cursorActive: studio.cursorActive
            statusToast: studio.statusToast
            cliVersion: studio.store.cliVersion
            currentDir: studio.store.shortPath(studio.store.cwd)
            launchScript: studio.store.launchScript
            launchArgs: studio.store.launchArgs
            workDir: studio.store.cwd
            terminalAutoStart: studio.terminalAutoStart
            needsAttention: studio.store.needsAttention
            attentionText: studio.store.attentionText
            openTabs: studio.openTabs
            activeTabId: studio.activeTabId
            onSelectTab: function(id) { studio.activeTabId = id }
            onCloseTab: function(id) { studio.closeFileTab(id) }
            onFoldRequested: studio.foldRequested()
        }

        // RIGHT RAIL (25%): Model/Effort slide-down + Token & single-bar Context + spacious Task Checklist
        StudioRightRail {
            Layout.preferredWidth: Math.round(studio.stageWidth * 0.25)
            Layout.fillHeight: true
            agentRunning: studio.agentRunning
            modelOptions: studio.store.modelOptions
            effortOptions: studio.store.effortOptions
            modelIndex: studio.store.modelIndex
            effortIndex: studio.store.effortIndex
            modelLabel: studio.store.modelName
            effortLabel: studio.store.effortLevel
            sessionLimitKnown: studio.store.limitSession !== null
            weekLimitKnown: studio.store.limitWeek !== null
            sessionUsedPct: studio.store.limitSession ? studio.store.limitSession.pct : 0
            sessionResetText: studio.store.limitSession ? studio.store.limitSession.resetText : ""
            weekUsedPct: studio.store.limitWeek ? studio.store.limitWeek.pct : 0
            weekResetText: studio.store.limitWeek ? studio.store.limitWeek.resetText : ""
            contextUsedPct: studio.store.contextUsedPct
            contextBufferPct: 0
            contextSummaryText: studio.store.contextSummaryText
            contextFreeText: studio.store.contextFreeText
            checklist: studio.store.checklist
            onModelPicked: function(idx) { studio.typeIntoTerminal("/model " + studio.store.modelOptions[idx].slug, true) }
            onEffortPicked: function(idx) { studio.typeIntoTerminal("/effort " + studio.store.effortOptions[idx].slug, true) }
        }
    }
}
