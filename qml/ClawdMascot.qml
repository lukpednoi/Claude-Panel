import QtQuick

// Pixel Clawd mascot supporting:
// - Idle: standing on 4 legs completely still (0 active animations unless blinkEnabled).
// - Glasses stare (`glasses: true`): dark pixel eyewear with soft lens sheen, optional slow blink, and glint sweep.
// - Waving (`waveTwice()`): waves right arm twice warmly and emits `waveFinished()`.
// - Working (`typing: true`): seated behind a grounded desk + open glowing laptop facing forward.
Item {
    id: clawd

    property real unit: 5
    property color bodyColor: "#E2774A"
    property color eyeColor: "#120F0D"
    property bool autoWave: true
    property int initialDelay: 180
    property bool typing: false
    property bool glasses: false
    property bool blinkEnabled: false
    property bool glintActive: false
    property bool hideLegs: false
    signal waveFinished()

    implicitWidth: unit * 11.4
    implicitHeight: unit * 6.0

    property real eyeOpen: 1.0
    property real glintP: 0.0

    property real deskReveal: typing ? 1 : 0
    Behavior on deskReveal { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    onGlintActiveChanged: {
        if (glintActive && glasses) glintAnim.restart();
    }

    Timer {
        id: blinkTimer
        interval: 3400
        repeat: true
        running: clawd.blinkEnabled && clawd.visible && !clawd.typing
        onTriggered: blinkAnim.restart()
    }

    SequentialAnimation {
        id: blinkAnim
        NumberAnimation { target: clawd; property: "eyeOpen"; from: 1.0; to: 0.08; duration: 65; easing.type: Easing.InQuad }
        NumberAnimation { target: clawd; property: "eyeOpen"; from: 0.08; to: 1.0; duration: 95; easing.type: Easing.OutQuad }
    }

    NumberAnimation {
        id: glintAnim
        target: clawd
        property: "glintP"
        from: 0.0
        to: 1.0
        duration: 420
        easing.type: Easing.InOutCubic
    }

    // Continuous 0..1 phase while typing -> smooth seated bounce & alternating typing paws
    property real wiggleT: 0
    readonly property real wSin: typing ? Math.sin(wiggleT * Math.PI * 2) : 0
    readonly property real wBounce: typing ? Math.abs(wSin) : 0

    // Isolated wave properties so reactive typing bindings never get overwritten
    property real waveBodyY: 0
    property real waveArmY: clawd.unit * 1.85
    property real waveArmRot: 10

    NumberAnimation on wiggleT {
        from: 0
        to: 1
        duration: 320
        loops: Animation.Infinite
        running: clawd.typing
    }

    function resetPose() {
        waveAnim.stop();
        wiggleT = 0;
        waveBodyY = 0;
        waveArmRot = 10;
        waveArmY = clawd.unit * 1.85;
    }

    function waveTwice() {
        resetPose();
        waveAnim.restart();
    }

    onTypingChanged: {
        if (typing) {
            waveAnim.stop();
        } else {
            resetPose();
        }
    }

    Component.onCompleted: {
        if (autoWave && !typing) waveAnim.start();
    }

    // Warm screen glow spilling onto Clawd while typing
    Image {
        visible: clawd.deskReveal > 0.02
        opacity: clawd.deskReveal * (0.45 + 0.16 * clawd.wBounce)
        source: "assets/glow-orb.svg"
        sourceSize: Qt.size(64, 64)
        smooth: true
        width: clawd.unit * 12
        height: width
        x: clawd.unit * 5.7 - width * 0.5
        y: clawd.unit * 2.2 - height * 0.5
    }

    // =========================================================================
    // CLAWD BODY
    // =========================================================================
    Item {
        id: bodyRoot
        z: 3
        width: clawd.unit * 11.4
        height: clawd.unit * 6.0
        y: clawd.typing
            ? (-clawd.unit * 0.35 - clawd.wBounce * clawd.unit * 0.42)
            : clawd.waveBodyY
        transformOrigin: Item.Bottom
        rotation: clawd.typing ? (clawd.wSin * 2.8) : 0

        // Upper head cap
        Rectangle {
            x: clawd.unit * 1.9
            y: 0
            width: clawd.unit * 7.6
            height: clawd.unit * 1.4
            color: clawd.bodyColor
        }

        // Main chunky torso
        Rectangle {
            x: clawd.unit * 1.2
            y: clawd.unit * 1.1
            width: clawd.unit * 9.0
            height: clawd.unit * 3.4
            color: clawd.bodyColor
        }

        // Eyes (look slightly downward onto laptop when typing; blink + focused catchlight when wearing glasses)
        Rectangle {
            id: leftEye
            x: clawd.unit * 2.75
            y: clawd.unit * (1.75 + (clawd.typing ? 0.12 : 0))
            width: clawd.unit * 1.1
            height: clawd.unit * 1.45
            color: clawd.eyeColor
            transform: Scale {
                origin.x: leftEye.width * 0.5
                origin.y: leftEye.height * 0.5
                yScale: clawd.eyeOpen
            }

            Rectangle {
                visible: clawd.glasses && clawd.eyeOpen > 0.35
                x: clawd.unit * 0.65
                y: clawd.unit * 0.22
                width: Math.max(1.5, clawd.unit * 0.34)
                height: width
                color: "#FFF3E6"
            }
        }

        Rectangle {
            id: rightEye
            x: clawd.unit * 7.55
            y: clawd.unit * (1.75 + (clawd.typing ? 0.12 : 0))
            width: clawd.unit * 1.1
            height: clawd.unit * 1.45
            color: clawd.eyeColor
            transform: Scale {
                origin.x: rightEye.width * 0.5
                origin.y: rightEye.height * 0.5
                yScale: clawd.eyeOpen
            }

            Rectangle {
                visible: clawd.glasses && clawd.eyeOpen > 0.35
                x: clawd.unit * 0.65
                y: clawd.unit * 0.22
                width: Math.max(1.5, clawd.unit * 0.34)
                height: width
                color: "#FFF3E6"
            }
        }

        // Pixel glasses framing Clawd's eyes (optional, enabled on Login concepts)
        Item {
            id: pixelGlasses
            z: 8
            visible: clawd.glasses
            anchors.fill: parent

            // Left & right temple arms
            Rectangle { x: clawd.unit * 1.15; y: clawd.unit * 1.88; width: clawd.unit * 0.68; height: Math.max(1.5, clawd.unit * 0.40); color: "#1A1412" }
            Rectangle { x: clawd.unit * 9.57; y: clawd.unit * 1.88; width: clawd.unit * 0.68; height: Math.max(1.5, clawd.unit * 0.40); color: "#1A1412" }

            // Center bridge with top bevel highlight
            Rectangle {
                x: clawd.unit * 4.74
                y: clawd.unit * 1.86
                width: clawd.unit * 1.92
                height: Math.max(1.5, clawd.unit * 0.42)
                color: "#1A1412"
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(1, clawd.unit * 0.12)
                    color: "#6B5649"
                }
            }

            // Left lens frame + translucent glass + diagonal reflection
            Rectangle {
                x: clawd.unit * 1.76
                y: clawd.unit * 1.30
                width: clawd.unit * 3.08
                height: clawd.unit * 2.28
                radius: Math.max(1, clawd.unit * 0.22)
                color: "#2C120E0C"
                border.width: Math.max(1.5, clawd.unit * 0.32)
                border.color: "#1A1412"
                clip: true

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Math.max(1, clawd.unit * 0.18)
                    height: Math.max(1, clawd.unit * 0.12)
                    color: "#558C7263"
                }
                Rectangle {
                    x: clawd.unit * 0.25
                    y: -clawd.unit * 0.45
                    width: clawd.unit * 0.48
                    height: clawd.unit * 3.1
                    rotation: -28
                    color: "#22FFF5EC"
                }
                Rectangle {
                    visible: clawd.glintP > 0.01 && clawd.glintP < 0.99
                    x: (-0.8 + 4.4 * clawd.glintP) * clawd.unit
                    y: -clawd.unit * 0.6
                    width: clawd.unit * 0.72
                    height: clawd.unit * 3.4
                    rotation: -28
                    color: "#6CFFF6EA"
                }
            }

            // Right lens frame + translucent glass + diagonal reflection
            Rectangle {
                x: clawd.unit * 6.56
                y: clawd.unit * 1.30
                width: clawd.unit * 3.08
                height: clawd.unit * 2.28
                radius: Math.max(1, clawd.unit * 0.22)
                color: "#2C120E0C"
                border.width: Math.max(1.5, clawd.unit * 0.32)
                border.color: "#1A1412"
                clip: true

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Math.max(1, clawd.unit * 0.18)
                    height: Math.max(1, clawd.unit * 0.12)
                    color: "#558C7263"
                }
                Rectangle {
                    x: clawd.unit * 0.25
                    y: -clawd.unit * 0.45
                    width: clawd.unit * 0.48
                    height: clawd.unit * 3.1
                    rotation: -28
                    color: "#22FFF5EC"
                }
                Rectangle {
                    visible: clawd.glintP > 0.01 && clawd.glintP < 0.99
                    x: (-0.8 + 4.4 * clawd.glintP) * clawd.unit
                    y: -clawd.unit * 0.6
                    width: clawd.unit * 0.72
                    height: clawd.unit * 3.4
                    rotation: -28
                    color: "#6CFFF6EA"
                }
            }
        }

        // Standing 4 legs (shown ONLY when Idle or Greeting and not hidden behind a card!)
        Rectangle { visible: !clawd.typing && !clawd.hideLegs; x: clawd.unit * 1.8; y: clawd.unit * 4.4; width: clawd.unit * 1.05; height: clawd.unit * 1.55; color: clawd.bodyColor }
        Rectangle { visible: !clawd.typing && !clawd.hideLegs; x: clawd.unit * 3.55; y: clawd.unit * 4.4; width: clawd.unit * 1.05; height: clawd.unit * 1.55; color: clawd.bodyColor }
        Rectangle { visible: !clawd.typing && !clawd.hideLegs; x: clawd.unit * 6.8; y: clawd.unit * 4.4; width: clawd.unit * 1.05; height: clawd.unit * 1.55; color: clawd.bodyColor }
        Rectangle { visible: !clawd.typing && !clawd.hideLegs; x: clawd.unit * 8.55; y: clawd.unit * 4.4; width: clawd.unit * 1.05; height: clawd.unit * 1.55; color: clawd.bodyColor }

        // Left arm: resting on left when Idle, or drumming behind left side of laptop while typing
        Rectangle {
            id: leftArm
            z: 6
            x: clawd.typing ? clawd.unit * 0.35 : 0
            y: clawd.typing
                ? clawd.unit * (3.15 + (clawd.wSin < 0 ? 0.52 : -0.32))
                : clawd.unit * 1.85
            width: clawd.typing ? clawd.unit * 1.9 : clawd.unit * 1.4
            height: clawd.typing ? clawd.unit * 1.25 : clawd.unit * 1.35
            radius: clawd.typing ? Math.max(1, clawd.unit * 0.25) : 0
            color: clawd.bodyColor
            transformOrigin: clawd.typing ? Item.Right : Item.Left
            rotation: clawd.typing ? (-16 + clawd.wSin * 20) : 0
        }

        // Right arm: waves twice when Greeting, or drums opposite left arm while typing
        Rectangle {
            id: rightArm
            z: 7
            x: clawd.typing ? clawd.unit * 9.15 : clawd.unit * 9.8
            y: clawd.typing
                ? clawd.unit * (3.15 + (clawd.wSin > 0 ? 0.52 : -0.32))
                : clawd.waveArmY
            width: clawd.typing ? clawd.unit * 1.9 : clawd.unit * 1.6
            height: clawd.unit * 1.25
            radius: clawd.typing ? Math.max(1, clawd.unit * 0.25) : 0
            color: clawd.bodyColor
            transformOrigin: Item.Left
            rotation: clawd.typing ? (16 + clawd.wSin * 20) : clawd.waveArmRot
        }
    }

    // =========================================================================
    // Front-facing desk + open glowing laptop hiding lower body while typing
    // =========================================================================
    Item {
        id: frontLaptop
        z: 5
        visible: clawd.deskReveal > 0.02
        opacity: clawd.deskReveal
        anchors.fill: parent

        // Open laptop lid centered in front of Clawd (eyes peek cleanly above it!)
        Rectangle {
            x: clawd.unit * 2.3
            y: clawd.unit * 2.85
            width: clawd.unit * 6.8
            height: clawd.unit * 2.15
            radius: Math.max(1, clawd.unit * 0.35)
            color: "#2C2521"
            border.width: 1
            border.color: "#57483F"

            // Subtle Claude orange emblem glowing on back of laptop lid
            Rectangle {
                anchors.centerIn: parent
                width: clawd.unit * 1.25
                height: width
                radius: width * 0.5
                color: "#E2774A"
                opacity: 0.75 + 0.25 * clawd.wBounce
            }
        }

        // Laptop base / keyboard deck
        Rectangle {
            x: clawd.unit * 1.5
            y: clawd.unit * 4.85
            width: clawd.unit * 8.4
            height: clawd.unit * 0.35
            color: "#3F352F"
        }

        // Grounded foreground desk surface spanning front of Clawd
        Rectangle {
            x: -clawd.unit * 0.8
            y: clawd.unit * 5.05
            width: clawd.unit * 13.0
            height: clawd.unit * 0.95
            radius: Math.max(1, clawd.unit * 0.25)
            color: "#43362F"
            border.width: 1
            border.color: "#5E4D43"
        }
    }

    // Wave twice warmly after landing or folding into the corner
    SequentialAnimation {
        id: waveAnim
        PauseAnimation { duration: clawd.initialDelay }

        ParallelAnimation {
            NumberAnimation { target: clawd; property: "waveArmRot"; to: -54; duration: 145; easing.type: Easing.OutCubic }
            NumberAnimation { target: clawd; property: "waveArmY"; to: clawd.unit * 1.55; duration: 145; easing.type: Easing.OutCubic }
            NumberAnimation { target: clawd; property: "waveBodyY"; to: -clawd.unit * 0.42; duration: 145; easing.type: Easing.OutQuad }
        }

        NumberAnimation { target: clawd; property: "waveArmRot"; to: -18; duration: 125; easing.type: Easing.InOutSine }
        NumberAnimation { target: clawd; property: "waveArmRot"; to: -56; duration: 125; easing.type: Easing.InOutSine }

        NumberAnimation { target: clawd; property: "waveArmRot"; to: -18; duration: 125; easing.type: Easing.InOutSine }
        NumberAnimation { target: clawd; property: "waveArmRot"; to: -52; duration: 125; easing.type: Easing.InOutSine }

        ParallelAnimation {
            NumberAnimation { target: clawd; property: "waveArmRot"; to: 10; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: clawd; property: "waveArmY"; to: clawd.unit * 1.85; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: clawd; property: "waveBodyY"; to: 0; duration: 180; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: clawd.waveFinished() }
    }
}
