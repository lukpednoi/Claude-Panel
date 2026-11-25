pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Settings pane allowing the user to enable/disable Claude Studio sections, UI options, and check/apply panel updates.
Flickable {
    id: pane

    required property var store
    property var updater: null

    contentHeight: col.implicitHeight + 8
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

        // ---------- PANEL UPDATES ----------
        Rectangle {
            visible: pane.updater !== null
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 8
            Layout.bottomMargin: 4
            color: "#1BFFFFFF"
        }

        RowLayout {
            visible: pane.updater !== null
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "UPDATES"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 0.6
                color: "#9E9388"
            }

            Item { Layout.fillWidth: true }

            Text {
                text: pane.updater && pane.updater.localVersion ? ("v" + pane.updater.localVersion) : ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                color: pane.updater && pane.updater.updateAvailable ? "#FFAA7A" : "#8E8379"
            }
        }

        Rectangle {
            id: updateCard
            visible: pane.updater !== null
            Layout.fillWidth: true
            Layout.preferredHeight: updateCol.implicitHeight + 20
            radius: 10
            color: "#0DFFFFFF"
            border.width: 1
            border.color: {
                if (!pane.updater) return "transparent";
                if (pane.updater.restartNeeded) return "#557DD18A";
                if (pane.updater.updateAvailable) return "#58E2774A";
                return "#18FFFFFF";
            }

            readonly property bool busy: pane.updater !== null && (pane.updater.checking || pane.updater.updating)
            readonly property bool hasUpdate: pane.updater !== null && pane.updater.updateAvailable
            readonly property bool needsRestart: pane.updater !== null && pane.updater.restartNeeded

            ColumnLayout {
                id: updateCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        font.weight: (updateCard.hasUpdate || updateCard.needsRestart) ? Font.DemiBold : Font.Medium
                        wrapMode: Text.WordWrap
                        color: {
                            if (!pane.updater) return "#F4EDE5";
                            if (pane.updater.lastError !== "") return "#F28B82";
                            if (pane.updater.restartNeeded) return "#7DD18A";
                            if (pane.updater.updateAvailable) return "#FFD7BE";
                            return "#F4EDE5";
                        }
                        text: {
                            if (!pane.updater) return "";
                            if (pane.updater.updating) return "Updating panel…";
                            if (pane.updater.checking) return "Checking for updates…";
                            if (pane.updater.lastError !== "") return pane.updater.lastError;
                            if (pane.updater.restartNeeded) {
                                const ver = pane.updater.updatedToVersion || pane.updater.localVersion;
                                return ver ? ("Updated to v" + ver) : "Updated";
                            }
                            if (pane.updater.updateAvailable) return "Update available · v" + pane.updater.remoteVersion;
                            return "Up to date";
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: "#8E8379"
                        elide: Text.ElideRight
                        text: {
                            if (!pane.updater) return "";
                            if (pane.updater.restartNeeded) return "Restart panel to apply";
                            return pane.updater.lastCheckText !== ""
                                ? ("Every 6h · " + pane.updater.lastCheckText)
                                : "Auto-checks every 6h";
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // Check button
                    Rectangle {
                        Layout.preferredWidth: 74
                        Layout.preferredHeight: 30
                        radius: 8
                        opacity: updateCard.busy ? 0.5 : 1.0
                        color: checkMa.containsMouse && !updateCard.busy ? "#20FFFFFF" : "#12FFFFFF"
                        border.width: 1
                        border.color: checkMa.containsMouse && !updateCard.busy ? "#32FFFFFF" : "#1EFFFFFF"
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: pane.updater && pane.updater.checking ? "…" : "Check"
                            font.family: "Google Sans"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: "#D8CEC4"
                        }

                        MouseArea {
                            id: checkMa
                            anchors.fill: parent
                            enabled: !updateCard.busy && pane.updater !== null
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: pane.updater.check(true)
                        }
                    }

                    // Update / Restart button
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 8
                        opacity: updateCard.busy ? 0.55 : 1.0
                        color: {
                            if (updateCard.needsRestart)
                                return updMa.containsMouse ? "#387DD18A" : "#227DD18A";
                            if (updateCard.hasUpdate)
                                return updMa.containsMouse ? "#F08558" : "#E2774A";
                            return updMa.containsMouse && !updateCard.busy ? "#2CE2774A" : "#1AE2774A";
                        }
                        border.width: 1
                        border.color: {
                            if (updateCard.needsRestart) return "#707DD18A";
                            if (updateCard.hasUpdate) return "#FFAA7A";
                            return "#44E2774A";
                        }
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (!pane.updater) return "Update";
                                if (pane.updater.updating) return "Updating…";
                                if (pane.updater.restartNeeded) return "Restart panel";
                                if (pane.updater.updateAvailable) return "Update to v" + pane.updater.remoteVersion;
                                return "Update";
                            }
                            font.family: "Google Sans"
                            font.pixelSize: 12
                            font.weight: (updateCard.hasUpdate || updateCard.needsRestart) ? Font.DemiBold : Font.Medium
                            color: updateCard.hasUpdate ? "#150D09" : (updateCard.needsRestart ? "#B9F0C0" : "#FFD7BE")
                        }

                        MouseArea {
                            id: updMa
                            anchors.fill: parent
                            enabled: !updateCard.busy && pane.updater !== null
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (pane.updater.restartNeeded) pane.updater.restartPanel();
                                else pane.updater.applyUpdate();
                            }
                        }
                    }
                }
            }
        }
    }
}
