pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Explorer pane showing files edited/created by Claude (with exact path & diff badge) + project files.
Flickable {
    id: pane

    required property var store
    property string activeFileId: ""

    signal fileActivated(var fileObj)

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        width: pane.width
        spacing: 8

        // EDITED BY CLAUDE section
        ColumnLayout {
            Layout.fillWidth: true
            visible: pane.store.showEditedFiles
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "EDITED BY CLAUDE"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.letterSpacing: 0.6
                    color: "#EB9B73"
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: cntLbl.implicitWidth + 10
                    Layout.preferredHeight: 16
                    radius: 8
                    color: "#28E2774A"
                    Text {
                        id: cntLbl
                        anchors.centerIn: parent
                        text: pane.store.editedFiles.length
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: "#FFAA7A"
                    }
                }
            }

            Repeater {
                model: pane.store.editedFiles
                delegate: Rectangle {
                    id: edRow
                    required property var modelData
                    readonly property bool selected: modelData.id === pane.activeFileId
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: 9
                    color: selected
                        ? "#2AE2774A"
                        : (edMa.containsMouse ? "#16FFFFFF" : "#0DFFFFFF")
                    border.width: 1
                    border.color: selected
                        ? "#78E2774A"
                        : (edMa.containsMouse ? "#28FFFFFF" : "transparent")

                    Rectangle {
                        visible: edRow.selected
                        width: 3
                        height: 22
                        radius: 1.5
                        color: "#E2774A"
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: edRow.selected ? 15 : 10
                        anchors.rightMargin: 10
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                Layout.fillWidth: true
                                text: edRow.modelData.name
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.weight: edRow.selected ? Font.DemiBold : Font.Normal
                                color: edRow.selected ? "#FFF6ED" : "#EAE0D6"
                                elide: Text.ElideMiddle
                            }
                            Text {
                                text: edRow.modelData.badge
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: edRow.modelData.badge === "A" ? "#7DD18A" : "#F0A472"
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: edRow.modelData.path
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 9
                            color: "#8D8278"
                            elide: Text.ElideLeft
                        }
                    }

                    MouseArea {
                        id: edMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pane.fileActivated(edRow.modelData)
                    }
                }
            }
        }

        // WORKSPACE FILES section
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: pane.store.showEditedFiles ? 4 : 0
            visible: pane.store.showWorkspaceFiles
            spacing: 5

            Text {
                text: "WORKSPACE FILES"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 0.6
                color: "#9E9388"
            }

            Repeater {
                model: pane.store.workspaceFiles
                delegate: Rectangle {
                    id: wsRow
                    required property var modelData
                    readonly property bool selected: modelData.id === pane.activeFileId
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 9
                    color: selected
                        ? "#24E2774A"
                        : (wsMa.containsMouse ? "#15FFFFFF" : "#0BFFFFFF")
                    border.width: 1
                    border.color: selected
                        ? "#68E2774A"
                        : (wsMa.containsMouse ? "#24FFFFFF" : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text: wsRow.modelData.name
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: wsRow.selected ? "#FAF4EC" : "#D4CBC1"
                            elide: Text.ElideMiddle
                        }
                        Text {
                            text: wsRow.modelData.badge
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: wsRow.selected ? "#E8926B" : "#8D8278"
                        }
                    }

                    MouseArea {
                        id: wsMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pane.fileActivated(wsRow.modelData)
                    }
                }
            }
        }
    }
}
