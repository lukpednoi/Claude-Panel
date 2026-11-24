import QtQuick
import QtQuick.Layouts

// Unauthenticated Claude Auth Gate view (chosen Design 2/3):
// Centered dark glass card with pixel-glasses Clawd peering over the top edge.
Item {
    id: view

    property bool active: true
    property string loginUrl: ""
    property bool waiting: false         // the sign-in runs; Claude Code is waiting for the browser
    property bool showCloseButton: false
    signal closeRequested()
    signal openLoginRequested(string url)
    signal sfxRequested(string file, real volume)

    Item {
        anchors.centerIn: parent
        width: 610
        height: gateCard.height + 54

        // Soft warm aura behind card + Clawd
        Image {
            anchors.centerIn: gateCard
            source: "assets/glow-orb.svg"
            sourceSize: Qt.size(128, 128)
            smooth: true
            width: 560
            height: 460
            opacity: linkBar.hovered ? 0.52 : 0.34
            Behavior on opacity { NumberAnimation { duration: 240 } }
        }

        // Clawd resting behind top edge of the card looking down at us through glasses
        ClawdMascot {
            id: peekingClawd
            z: 1
            anchors.horizontalCenter: gateCard.horizontalCenter
            y: gateCard.y - unit * 3.92
            unit: 7.8
            autoWave: false
            glasses: true
            hideLegs: true
            blinkEnabled: view.active
            glintActive: linkBar.hovered || linkBar.openState
        }

        // Auth Gate Card
        Rectangle {
            id: gateCard
            z: 2
            y: 42
            width: parent.width
            height: cardCol.implicitHeight + 60
            radius: 22
            color: "#15110F"
            border.width: 1
            border.color: linkBar.hovered ? "#7AE2774A" : "#4CE2774A"
            Behavior on border.color { ColorAnimation { duration: 200 } }

            ColumnLayout {
                id: cardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 30
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true

                    Row {
                        spacing: 8
                        ClaudeLogo {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 20
                            color: "#E2774A"
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Claude Code"
                            font.family: "Noto Serif"
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            color: "#F3EAE0"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: reqLbl.implicitWidth + 20
                        Layout.preferredHeight: 24
                        radius: 12
                        color: "#22E2774A"
                        border.width: 1
                        border.color: "#4CE2774A"
                        Text {
                            id: reqLbl
                            anchors.centerIn: parent
                            text: "Sign-in Required"
                            font.family: "Google Sans"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: "#EE946A"
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 6

                    Text {
                        text: "Login"
                        font.family: "Noto Serif"
                        font.pixelSize: 40
                        font.weight: Font.Medium
                        color: "#FAF4EC"
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Sign in to unlock Claude Code."
                        font.family: "Google Sans"
                        font.pixelSize: 14
                        color: "#B2A599"
                        wrapMode: Text.WordWrap
                    }
                }

                LoginLinkBar {
                    id: linkBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    Layout.topMargin: 6
                    capsuleStyle: false
                    loginUrl: view.loginUrl
                    onSfxRequested: function(file, vol) { view.sfxRequested(file, vol) }
                    onOpenTriggered: function(url) { view.openLoginRequested(url) }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 4
                    color: "#1BFFFFFF"
                }

                Text {
                    Layout.fillWidth: true
                    text: view.waiting && view.loginUrl !== "" ? "●  Waiting for you to sign in in the browser…" : "○  Not signed in"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: linkBar.openState ? "#EC9E78" : "#9C9084"
                }
            }
        }
    }

    // Subtle top-right close button (matching Studio; no fold button while unauthenticated)
    Rectangle {
        visible: view.showCloseButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 28
        anchors.rightMargin: 24
        width: 26
        height: 26
        radius: 13
        color: closeMa.containsMouse ? "#40E07A68" : "#18FFFFFF"
        border.width: 1
        border.color: closeMa.containsMouse ? "#80E07A68" : "#22FFFFFF"
        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 11; color: "#F5ECE3" }
        MouseArea {
            id: closeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.closeRequested()
        }
    }
}
