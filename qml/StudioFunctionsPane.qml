pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Settings pane allowing the user to enable/disable Claude Studio sections & UI options.
Flickable {
    id: pane

    required property var store

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        width: pane.width
        spacing: 6

        Text {
            text: "PANEL SETTINGS"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.weight: Font.Medium
            font.letterSpacing: 0.6
            color: "#9E9388"
        }

        Repeater {
            model: [
                { key: "edited", label: "Edited by Claude files", checked: pane.store.showEditedFiles },
                { key: "ws", label: "Workspace project files", checked: pane.store.showWorkspaceFiles },
                { key: "search", label: "Command search filter", checked: pane.store.showCommandSearch },
                { key: "desc", label: "Command descriptions", checked: pane.store.showCommandDesc },
                { key: "sess", label: "Sessions tab in Activity Bar", checked: pane.store.showSessions }
            ]
            delegate: Rectangle {
                id: tRow
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 9
                color: tMa.containsMouse ? "#16FFFFFF" : "#0DFFFFFF"
                border.width: 1
                border.color: tRow.modelData.checked ? "#38E2774A" : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        radius: 4
                        color: tRow.modelData.checked ? "#E2774A" : "#18FFFFFF"
                        border.width: 1
                        border.color: tRow.modelData.checked ? "#FFAA7A" : "#34FFFFFF"
                        Text {
                            visible: tRow.modelData.checked
                            anchors.centerIn: parent
                            text: "✓"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: "#150D09"
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: tRow.modelData.label
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        color: tRow.modelData.checked ? "#F4EDE5" : "#9E9388"
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: tMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const k = tRow.modelData.key;
                        if (k === "edited") pane.store.showEditedFiles = !pane.store.showEditedFiles;
                        else if (k === "ws") pane.store.showWorkspaceFiles = !pane.store.showWorkspaceFiles;
                        else if (k === "search") pane.store.showCommandSearch = !pane.store.showCommandSearch;
                        else if (k === "desc") pane.store.showCommandDesc = !pane.store.showCommandDesc;
                        else if (k === "sess") pane.store.showSessions = !pane.store.showSessions;
                    }
                }
            }
        }
    }
}
