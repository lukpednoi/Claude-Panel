pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Slide-down Model & Effort controls at the top of the Left Rail.
// Clicking either header expands its inline list downward, smoothly pushing content below it.
ColumnLayout {
    id: root

    property var modelOptions: []
    property var effortOptions: []
    property int modelIndex: 0
    property int effortIndex: 2
    property string modelLabel: ""     // shown when the session's model is not one of modelOptions (or not known yet)
    property string effortLabel: ""
    property bool modelExpanded: false
    property bool effortExpanded: false

    property real modelOpenP: modelExpanded ? 1.0 : 0.0
    property real effortOpenP: effortExpanded ? 1.0 : 0.0

    signal modelPicked(int index)
    signal effortPicked(int index)

    Behavior on modelOpenP { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
    Behavior on effortOpenP { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }

    spacing: 6

    // MODEL HEADER
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: 10
        color: root.modelExpanded
            ? "#24E2774A"
            : (modelHdrMa.containsMouse ? "#1D1815" : "#120F0D")
        border.width: 1
        border.color: root.modelExpanded
            ? "#78E2774A"
            : (modelHdrMa.containsMouse ? "#4AE2774A" : "#22FFFFFF")

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 10
            spacing: 7

            Text {
                text: "MODEL"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 0.5
                color: "#9E9388"
            }

            Text {
                Layout.fillWidth: true
                text: root.modelIndex >= 0 && root.modelIndex < root.modelOptions.length ? root.modelOptions[root.modelIndex].name : (root.modelLabel || "—")
                font.family: "Google Sans"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: "#FAF4EC"
                elide: Text.ElideRight
            }

            Text {
                text: "▾"
                font.pixelSize: 12
                color: "#E2774A"
                rotation: root.modelOpenP * 180
            }
        }

        MouseArea {
            id: modelHdrMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.modelExpanded = !root.modelExpanded;
                if (root.modelExpanded) root.effortExpanded = false;
            }
        }
    }

    // MODEL SLIDE-DOWN DRAWER
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(modelListCol.implicitHeight * root.modelOpenP)
        visible: root.modelOpenP > 0.01
        opacity: root.modelOpenP
        clip: true

        ColumnLayout {
            id: modelListCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 4

            Repeater {
                model: root.modelOptions
                delegate: Rectangle {
                    id: mOpt
                    required property int index
                    required property var modelData
                    readonly property bool selected: index === root.modelIndex
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 8
                    color: selected
                        ? "#2CE2774A"
                        : (mOptMa.containsMouse ? "#18FFFFFF" : "#0DFFFFFF")
                    border.width: 1
                    border.color: selected ? "#70E2774A" : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6

                        Rectangle {
                            Layout.preferredWidth: 6
                            Layout.preferredHeight: 6
                            radius: 3
                            color: mOpt.selected ? "#E2774A" : "#44FFFFFF"
                        }

                        Text {
                            text: mOpt.modelData.name
                            font.family: "Google Sans"
                            font.pixelSize: 12
                            font.weight: mOpt.selected ? Font.DemiBold : Font.Medium
                            color: mOpt.selected ? "#FAF4EC" : "#D6CDC3"
                        }

                        Text {
                            Layout.fillWidth: true
                            text: mOpt.modelData.note
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: "#8E8379"
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    MouseArea {
                        id: mOptMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.modelPicked(mOpt.index);
                            root.modelExpanded = false;
                        }
                    }
                }
            }
        }
    }

    // EFFORT HEADER
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: 10
        color: root.effortExpanded
            ? "#24E2774A"
            : (effortHdrMa.containsMouse ? "#1D1815" : "#120F0D")
        border.width: 1
        border.color: root.effortExpanded
            ? "#78E2774A"
            : (effortHdrMa.containsMouse ? "#4AE2774A" : "#22FFFFFF")

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 10
            spacing: 7

            Text {
                text: "EFFORT"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 0.5
                color: "#9E9388"
            }

            Text {
                Layout.fillWidth: true
                text: root.effortIndex >= 0 && root.effortIndex < root.effortOptions.length ? root.effortOptions[root.effortIndex].name : (root.effortLabel || "—")
                font.family: "Google Sans"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: "#FFAA7A"
                elide: Text.ElideRight
            }

            Row {
                spacing: 2
                Repeater {
                    model: root.effortOptions.length
                    delegate: Rectangle {
                        required property int index
                        width: 4
                        height: 4 + index * 2
                        radius: 1
                        anchors.bottom: parent.bottom
                        color: index <= root.effortIndex ? "#E2774A" : "#352E2A"
                    }
                }
            }

            Text {
                text: "▾"
                font.pixelSize: 12
                color: "#E2774A"
                rotation: root.effortOpenP * 180
            }
        }

        MouseArea {
            id: effortHdrMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.effortExpanded = !root.effortExpanded;
                if (root.effortExpanded) root.modelExpanded = false;
            }
        }
    }

    // EFFORT SLIDE-DOWN DRAWER
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(effortListCol.implicitHeight * root.effortOpenP)
        visible: root.effortOpenP > 0.01
        opacity: root.effortOpenP
        clip: true

        ColumnLayout {
            id: effortListCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 4

            Repeater {
                model: root.effortOptions
                delegate: Rectangle {
                    id: eOpt
                    required property int index
                    required property var modelData
                    readonly property bool selected: index === root.effortIndex
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8
                    color: selected
                        ? "#2CE2774A"
                        : (eOptMa.containsMouse ? "#18FFFFFF" : "#0DFFFFFF")
                    border.width: 1
                    border.color: selected ? "#70E2774A" : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6

                        Row {
                            spacing: 2
                            Repeater {
                                model: root.effortOptions.length
                                delegate: Rectangle {
                                    required property int index
                                    width: 4
                                    height: 5 + index * 2
                                    radius: 1
                                    anchors.bottom: parent.bottom
                                    color: index <= eOpt.index ? "#E2774A" : "#332C28"
                                }
                            }
                        }

                        Text {
                            text: eOpt.modelData.name
                            font.family: "Google Sans"
                            font.pixelSize: 12
                            font.weight: eOpt.selected ? Font.DemiBold : Font.Medium
                            color: eOpt.selected ? "#FAF4EC" : "#D6CDC3"
                        }

                        Text {
                            Layout.fillWidth: true
                            text: eOpt.modelData.note
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: "#8E8379"
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    MouseArea {
                        id: eOptMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.effortPicked(eOpt.index);
                            root.effortExpanded = false;
                        }
                    }
                }
            }
        }
    }
}
