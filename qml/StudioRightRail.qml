pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Right Rail of ClaudeStudioView:
// - Top: Slide-down MODEL & EFFORT accordion controls
// - Middle: TOKEN (Current session + Current week) + single-bar CONTEXT USAGE overall summary
// - Bottom: Spacious expandable TASK CHECKLIST filling available rail height
Rectangle {
    id: rail

    property bool agentRunning: false
    property var modelOptions: []
    property var effortOptions: []
    property int modelIndex: 0
    property int effortIndex: 2
    property string modelLabel: ""
    property string effortLabel: ""

    // plan limits come from the session's statusLine once Claude has answered; rows stay hidden until then
    property bool sessionLimitKnown: false
    property bool weekLimitKnown: false
    property var checklist: []            // [{ id, text, status: pending | in_progress | completed }]
    readonly property int doneCount: checklist.filter(t => t.status === "completed").length
    property real sessionUsedPct: 0.00
    property string sessionResetText: "Resets 8:29am (Asia/Bangkok)"
    property real weekUsedPct: 0.99
    property string weekResetText: "Resets Nov 20, 9:59pm (Asia/Bangkok)"
    property real contextUsedPct: 0.03
    property real contextBufferPct: 0.033
    property string contextSummaryText: "28.4k / 1m tokens"
    property string contextFreeText: "938.6k free · 33k autocompact"

    signal modelPicked(int index)
    signal effortPicked(int index)

    radius: 16
    color: "#151210"
    border.color: "#24FFFFFF"
    border.width: 1
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Top: Model & Effort Slide-down Accordion
        StudioModelEffortAccordion {
            id: accordion
            Layout.fillWidth: true
            modelOptions: rail.modelOptions
            effortOptions: rail.effortOptions
            modelIndex: rail.modelIndex
            effortIndex: rail.effortIndex
            modelLabel: rail.modelLabel
            effortLabel: rail.effortLabel
            onModelPicked: function(idx) { rail.modelPicked(idx) }
            onEffortPicked: function(idx) { rail.effortPicked(idx) }
        }

        // Middle: Token & Context Usage card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: usageCol.implicitHeight + 22
            radius: 14
            color: "#11FFFFFF"
            border.width: 1
            border.color: "#1AFFFFFF"

            ColumnLayout {
                id: usageCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 11
                spacing: 9

                Text {
                    text: "TOKEN"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.letterSpacing: 0.6
                    color: "#9E9388"
                }

                Text {
                    visible: !rail.sessionLimitKnown && !rail.weekLimitKnown
                    Layout.fillWidth: true
                    text: "Plan limits show up after Claude's first answer"
                    font.family: "Google Sans"
                    font.pixelSize: 11
                    color: "#8E8379"
                    wrapMode: Text.WordWrap
                }

                // Current session
                ColumnLayout {
                    visible: rail.sessionLimitKnown
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Current session"
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: "#F4EDE5"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 10
                            radius: 3
                            color: "#444D62"
                            clip: true

                            Rectangle {
                                width: Math.round(parent.width * Math.max(0, Math.min(1, rail.sessionUsedPct)))
                                height: parent.height
                                radius: 3
                                color: "#B6C2FF"
                            }
                        }

                        Text {
                            text: Math.round(rail.sessionUsedPct * 100) + "% used"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: "#DDD6CE"
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: rail.sessionResetText
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: "#8E8379"
                        elide: Text.ElideRight
                    }
                }

                // Current week (all models)
                ColumnLayout {
                    visible: rail.weekLimitKnown
                    Layout.fillWidth: true
                    Layout.topMargin: 1
                    spacing: 4

                    Text {
                        text: "Current week (all models)"
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: "#F4EDE5"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 10
                            radius: 3
                            color: "#444D62"
                            clip: true

                            Rectangle {
                                width: Math.round(parent.width * Math.max(0, Math.min(1, rail.weekUsedPct)))
                                height: parent.height
                                radius: 3
                                color: "#B6C2FF"
                            }
                        }

                        Text {
                            text: Math.round(rail.weekUsedPct * 100) + "% used"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: "#DDD6CE"
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: rail.weekResetText
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: "#8E8379"
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 1
                    color: "#1BFFFFFF"
                }

                // Context Usage overall summary (single solid allocation bar ONLY)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "CONTEXT USAGE"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            font.letterSpacing: 0.6
                            color: "#9E9388"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Math.round(rail.contextUsedPct * 100) + "%"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: "#B6C2FF"
                        }
                    }

                    Text {
                        text: rail.contextSummaryText
                        font.family: "Google Sans"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: "#F4EDE5"
                    }

                    // Single overall allocation strip (used | free | autocompact buffer)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        radius: 3
                        color: "#262220"
                        border.width: 1
                        border.color: "#1CFFFFFF"
                        clip: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: rail.contextUsedPct > 0 ? Math.max(4, Math.round(parent.width * rail.contextUsedPct)) : 0
                            color: "#B6C2FF"
                        }

                        Rectangle {
                            visible: rail.contextBufferPct > 0
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(4, Math.round(parent.width * rail.contextBufferPct))
                            color: "#6A6058"
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: rail.contextFreeText
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: "#8E8379"
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Bottom: Spacious expandable Task Checklist filling remaining rail height cleanly
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 132
            radius: 14
            color: "#11FFFFFF"
            border.width: 1
            border.color: "#1AFFFFFF"
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "TASK CHECKLIST"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        font.letterSpacing: 0.6
                        color: "#9E9388"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: rail.agentRunning ? "● Active" : (rail.checklist.length ? rail.doneCount + " / " + rail.checklist.length + " done" : "")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: rail.agentRunning ? "#FFAA7A" : "#8E8379"
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: checkCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: checkCol
                        width: parent.width
                        spacing: 6

                        Text {
                            visible: rail.checklist.length === 0
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            text: rail.agentRunning ? "Claude is working…" : "Claude's task list shows up here"
                            font.family: "Google Sans"
                            font.pixelSize: 12
                            color: "#8E8379"
                            wrapMode: Text.WordWrap
                        }

                        Repeater {
                            model: rail.checklist.map(t => t.status === "completed"
                                ? { mark: "✓", label: t.text, col: "#92CF94", bg: "#187DD18A" }
                                : (t.status === "in_progress"
                                    ? { mark: "●", label: t.text, col: "#FFAA7A", bg: "#1AE2774A" }
                                    : { mark: "○", label: t.text, col: "#C8BEB4", bg: "#0DFFFFFF" }))
                            delegate: Rectangle {
                                id: chkRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                radius: 8
                                color: modelData.bg
                                border.width: 1
                                border.color: "#14FFFFFF"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8
                                    Text {
                                        text: chkRow.modelData.mark
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        color: chkRow.modelData.col
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: chkRow.modelData.label
                                        font.family: "Google Sans"
                                        font.pixelSize: 12
                                        color: chkRow.modelData.col
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
