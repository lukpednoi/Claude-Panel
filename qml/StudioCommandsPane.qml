pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Command browser pane: search filter + Starred top group (230ms hold-drag reorder) + Unstarred group below.
ColumnLayout {
    id: pane

    required property var store
    signal commandTriggered(string cmd)

    // Reorder state stored cleanly outside Repeater delegates
    property int cmdDragStartIdx: -1
    property int cmdDragTargetIdx: -1
    property real cmdDragDeltaY: 0

    readonly property int rowH: store.showCommandDesc ? 42 : 30
    readonly property int rowGap: 4
    readonly property int rowStride: rowH + rowGap

    readonly property var starredRows: store.starredCommandObjects(store.commandFilter, store.pinnedCommands)
    readonly property var unstarredRows: store.unstarredCommandObjects(store.commandFilter, store.pinnedCommands)
    readonly property bool canReorderStarred: store.commandFilter.trim() === "" && starredRows.length > 1

    spacing: 8

    // Filter box
    Rectangle {
        visible: pane.store.showCommandSearch
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 9
        color: "#0F0C0B"
        border.width: 1
        border.color: searchInput.activeFocus ? "#68E2774A" : "#22FFFFFF"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 6

            Text {
                text: "⌕"
                font.pixelSize: 13
                color: "#8E8379"
            }

            TextInput {
                id: searchInput
                Layout.fillWidth: true
                text: pane.store.commandFilter
                onTextChanged: pane.store.commandFilter = text
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: "#FAF4EC"
                clip: true

                Text {
                    anchors.fill: parent
                    visible: searchInput.text === ""
                    text: "Filter /commands..."
                    font: searchInput.font
                    color: "#6E645C"
                }
            }

            Rectangle {
                visible: searchInput.text !== ""
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                radius: 8
                color: "#22FFFFFF"
                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 9; color: "#DED3C8" }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: searchInput.text = ""
                }
            }
        }
    }

    // Starred helper header (only shown when starred items exist)
    RowLayout {
        visible: pane.starredRows.length > 0
        Layout.fillWidth: true
        Text {
            text: "STARRED (" + pane.starredRows.length + ")"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.weight: Font.Medium
            font.letterSpacing: 0.6
            color: "#EB9B73"
        }
        Item { Layout.fillWidth: true }
        Text {
            visible: pane.canReorderStarred
            text: "Hold ★ to reorder"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 9
            color: "#7E7268"
        }
    }

    // Unified scrollable Starred (top) + Unstarred (bottom) commands list
    Flickable {
        id: cmdFlick
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: listCol.implicitHeight
        interactive: pane.cmdDragStartIdx < 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: listCol
            width: cmdFlick.width
            spacing: 6

            // Starred top group (long-press >= 230ms + drag to reorder)
            Item {
                id: starredArea
                visible: pane.starredRows.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(0, pane.starredRows.length * pane.rowStride - pane.rowGap)

                Repeater {
                    model: pane.starredRows
                    delegate: Rectangle {
                        id: stRow
                        required property int index
                        required property var modelData

                        readonly property bool isDragging: pane.cmdDragStartIdx === index
                        readonly property real slotShift: {
                            const s = pane.cmdDragStartIdx;
                            const t = pane.cmdDragTargetIdx;
                            if (s < 0 || t < 0 || index === s) return 0;
                            if (index > s && index <= t) return -pane.rowStride;
                            if (index < s && index >= t) return pane.rowStride;
                            return 0;
                        }
                        property real animShiftY: slotShift
                        Behavior on animShiftY {
                            enabled: pane.cmdDragStartIdx >= 0
                            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                        }

                        width: starredArea.width
                        height: pane.rowH
                        x: 0
                        y: index * pane.rowStride + (isDragging ? pane.cmdDragDeltaY : animShiftY)
                        z: isDragging ? 30 : 1
                        scale: isDragging ? 1.02 : 1.0
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                        radius: 9
                        color: isDragging
                            ? "#34E2774A"
                            : (stRowMa.containsMouse ? "#24E2774A" : "#18E2774A")
                        border.width: 1
                        border.color: isDragging
                            ? "#BAE2774A"
                            : (stRowMa.containsMouse ? "#72E2774A" : "#40E2774A")

                        Timer {
                            id: holdTimer
                            interval: 230
                            onTriggered: {
                                if (!pane.canReorderStarred || !stRowMa.pressed) return;
                                pane.cmdDragStartIdx = stRow.index;
                                pane.cmdDragTargetIdx = stRow.index;
                                pane.cmdDragDeltaY = 0;
                            }
                        }

                        MouseArea {
                            id: stRowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: pane.cmdDragStartIdx === stRow.index
                            cursorShape: pane.cmdDragStartIdx === stRow.index ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            property real pressStartY: 0
                            property real pressAreaY: 0

                            onPressed: function(mouse) {
                                pressStartY = mouse.y;
                                pressAreaY = mapToItem(starredArea, mouse.x, mouse.y).y;
                                if (pane.canReorderStarred) holdTimer.restart();
                            }

                            onPositionChanged: function(mouse) {
                                const curY = mapToItem(starredArea, mouse.x, mouse.y).y;
                                if (pane.cmdDragStartIdx === stRow.index) {
                                    const rawDelta = curY - pressAreaY;
                                    const minDelta = -stRow.index * pane.rowStride;
                                    const maxDelta = (pane.starredRows.length - 1 - stRow.index) * pane.rowStride;
                                    pane.cmdDragDeltaY = Math.max(minDelta, Math.min(maxDelta, rawDelta));
                                    pane.cmdDragTargetIdx = Math.max(0, Math.min(pane.starredRows.length - 1,
                                        Math.round(stRow.index + pane.cmdDragDeltaY / pane.rowStride)));
                                } else if (holdTimer.running && Math.abs(mouse.y - pressStartY) > 6) {
                                    holdTimer.stop();
                                }
                            }

                            onReleased: {
                                holdTimer.stop();
                                if (pane.cmdDragStartIdx === stRow.index) {
                                    const fromIdx = pane.cmdDragStartIdx;
                                    const toIdx = pane.cmdDragTargetIdx;
                                    pane.cmdDragStartIdx = -1;
                                    pane.cmdDragTargetIdx = -1;
                                    pane.cmdDragDeltaY = 0;
                                    pane.store.reorderPinnedCommand(fromIdx, toIdx);
                                } else {
                                    pane.commandTriggered(stRow.modelData.cmd);
                                }
                            }

                            onCanceled: {
                                holdTimer.stop();
                                if (pane.cmdDragStartIdx === stRow.index) {
                                    pane.cmdDragStartIdx = -1;
                                    pane.cmdDragTargetIdx = -1;
                                    pane.cmdDragDeltaY = 0;
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 7
                            spacing: 7

                            Text {
                                text: "⋮⋮"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: stRow.isDragging ? "#FFCAA7" : "#7D6A5C"
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 1
                                Row {
                                    spacing: 6
                                    Text {
                                        text: stRow.modelData.cmd
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: "#FFEBD9"
                                    }
                                    Text {
                                        text: stRow.modelData.cat
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                        color: "#B49B8A"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Text {
                                    visible: pane.store.showCommandDesc
                                    width: parent.width
                                    text: stRow.modelData.desc
                                    font.family: "Google Sans"
                                    font.pixelSize: 11
                                    color: "#B9A598"
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                radius: 6
                                color: unstarMa.containsMouse ? "#28FFFFFF" : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "★"
                                    font.pixelSize: 12
                                    color: "#E2774A"
                                }
                                MouseArea {
                                    id: unstarMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: pane.store.togglePin(stRow.modelData.cmd)
                                }
                            }
                        }
                    }
                }
            }

            // Divider separating Starred above from Unstarred below
            Rectangle {
                visible: pane.starredRows.length > 0 && pane.unstarredRows.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#2BE2774A"
            }

            // Unstarred commands below
            ColumnLayout {
                visible: pane.unstarredRows.length > 0
                Layout.fillWidth: true
                spacing: pane.rowGap

                Repeater {
                    model: pane.unstarredRows
                    delegate: Rectangle {
                        id: unRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: pane.rowH
                        radius: 9
                        color: unRowMa.containsMouse ? "#17FFFFFF" : "#0DFFFFFF"
                        border.width: 1
                        border.color: unRowMa.containsMouse ? "#30FFFFFF" : "transparent"

                        MouseArea {
                            id: unRowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pane.commandTriggered(unRow.modelData.cmd)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 7
                            spacing: 6

                            Column {
                                Layout.fillWidth: true
                                spacing: 1
                                Row {
                                    spacing: 6
                                    Text {
                                        text: unRow.modelData.cmd
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: "#F2E8DE"
                                    }
                                    Text {
                                        text: unRow.modelData.cat
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                        color: "#8E8379"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Text {
                                    visible: pane.store.showCommandDesc
                                    width: parent.width
                                    text: unRow.modelData.desc
                                    font.family: "Google Sans"
                                    font.pixelSize: 11
                                    color: "#9C9084"
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                radius: 6
                                color: starMa.containsMouse ? "#24FFFFFF" : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "☆"
                                    font.pixelSize: 12
                                    color: starMa.containsMouse ? "#E2774A" : "#6A6058"
                                }
                                MouseArea {
                                    id: starMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: pane.store.togglePin(unRow.modelData.cmd)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
