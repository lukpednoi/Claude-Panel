pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Recent Claude rooms list with one-click Resume.
Flickable {
    id: pane

    required property var store
    property string activeSessionId: "s1"
    signal sessionResumed(var sessionObj)

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        width: pane.width
        spacing: 6

        Text {
            text: "RECENT SESSIONS · ALL FOLDERS"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.weight: Font.Medium
            font.letterSpacing: 0.6
            color: "#9E9388"
        }

        Repeater {
            model: pane.store.recentSessions
            delegate: Rectangle {
                id: sRow
                required property var modelData
                readonly property bool current: modelData.id === pane.activeSessionId
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 10
                color: current
                    ? "#20E2774A"
                    : (sMa.containsMouse ? "#16FFFFFF" : "#0DFFFFFF")
                border.width: 1
                border.color: current ? "#68E2774A" : (sMa.containsMouse ? "#28FFFFFF" : "transparent")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 8

                    Column {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            width: parent.width
                            text: sRow.modelData.title
                            font.family: "Google Sans"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: sRow.current ? "#FFF5EB" : "#EAE0D6"
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            // every folder's sessions are listed (like /resume's "all"): say where each one ran
                            text: [sRow.modelData.time, sRow.modelData.dir, sRow.modelData.model].filter(t => t).join("  ·  ")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: "#8E8379"
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: resLbl.implicitWidth + 14
                        Layout.preferredHeight: 24
                        radius: 8
                        color: sRow.current ? "#34E2774A" : (sMa.containsMouse ? "#E2774A" : "#1CFFFFFF")
                        Text {
                            id: resLbl
                            anchors.centerIn: parent
                            text: sRow.current ? "Active" : "Resume"
                            font.family: "Google Sans"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: sRow.current ? "#FFAA7A" : (sMa.containsMouse ? "#150D09" : "#E6DCD2")
                        }
                    }
                }

                MouseArea {
                    id: sMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pane.sessionResumed(sRow.modelData)
                }
            }
        }
    }
}
