import QtQuick

// Rich dark Claude obsidian backdrop with reactive warm center/horizon glow,
// soft drifting aurora sheen, subtle ember motes, and a crisp glass rim.
Item {
    id: bg
    anchors.fill: parent

    property real ambient: 1.0
    property real flare: 0.0         // 0..1 reactive surge during ignition / spark arcs
    property real horizonGlow: 0.0   // 0..1 warm horizon highlight during Studio entrance
    property real cardRadius: 22
    property real topRightRadius: cardRadius
    property bool animate: true

    // Deep obsidian base with warm subtle center vignette
    Rectangle {
        anchors.fill: parent
        topLeftRadius: bg.cardRadius
        bottomLeftRadius: bg.cardRadius
        bottomRightRadius: bg.cardRadius
        topRightRadius: bg.topRightRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#120E0C" }
            GradientStop { position: 0.48; color: "#0B0908" }
            GradientStop { position: 1.0; color: "#060505" }
        }
    }

    // Soft ambient warm aura left-top
    Image {
        id: orb1
        source: "assets/glow-orb-soft.svg"
        sourceSize: Qt.size(128, 128)
        smooth: true
        width: Math.max(520, bg.width * 0.62)
        height: width
        x: bg.width * 0.24 - width * 0.5
        y: bg.height * 0.42 - height * 0.5
        opacity: (0.45 + 0.15 * bg.flare) * bg.ambient
        SequentialAnimation on x {
            loops: Animation.Infinite
            running: bg.animate
            NumberAnimation { to: bg.width * 0.34 - orb1.width * 0.5; duration: 20000; easing.type: Easing.InOutSine }
            NumberAnimation { to: bg.width * 0.24 - orb1.width * 0.5; duration: 20000; easing.type: Easing.InOutSine }
        }
    }

    // Soft counter-drifting warm plum-terracotta aura right-bottom
    Image {
        id: orb2
        source: "assets/glow-orb-soft.svg"
        sourceSize: Qt.size(128, 128)
        smooth: true
        width: Math.max(540, bg.width * 0.66)
        height: width
        x: bg.width * 0.76 - width * 0.5
        y: bg.height * 0.62 - height * 0.5
        opacity: 0.48 * bg.ambient
        SequentialAnimation on x {
            loops: Animation.Infinite
            running: bg.animate
            NumberAnimation { to: bg.width * 0.66 - orb2.width * 0.5; duration: 23000; easing.type: Easing.InOutSine }
            NumberAnimation { to: bg.width * 0.76 - orb2.width * 0.5; duration: 23000; easing.type: Easing.InOutSine }
        }
    }

    // Reactive central orange aura behind Hero logo & greeting
    Image {
        anchors.centerIn: parent
        source: "assets/glow-orb.svg"
        sourceSize: Qt.size(128, 128)
        smooth: true
        width: Math.max(460, bg.width * (0.44 + 0.22 * bg.flare))
        height: width
        opacity: (0.28 + 0.45 * bg.flare) * bg.ambient
    }

    // Warm horizon rim glow that rises gently during Welcome -> Studio transition
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.48
        radius: bg.cardRadius
        opacity: bg.horizonGlow * 0.85
        visible: opacity > 0.005
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00E47849" }
            GradientStop { position: 0.55; color: "#1CE47849" }
            GradientStop { position: 1.0; color: "#3CFF9860" }
        }
    }

    // Calm floating warm ember motes (subtle depth without visual noise)
    Repeater {
        model: [
            { xf: 0.14, yf: 0.80, sz: 2.5, dur: 16000, del: 0,    op: 0.30, col: "#E47849" },
            { xf: 0.22, yf: 0.66, sz: 2.0, dur: 18500, del: 1100, op: 0.22, col: "#FFE5CE" },
            { xf: 0.31, yf: 0.88, sz: 3.0, dur: 17000, del: 2200, op: 0.28, col: "#FF9860" },
            { xf: 0.42, yf: 0.74, sz: 2.0, dur: 19500, del: 700,  op: 0.20, col: "#FFE5CE" },
            { xf: 0.52, yf: 0.86, sz: 2.5, dur: 15500, del: 2900, op: 0.26, col: "#E47849" },
            { xf: 0.63, yf: 0.70, sz: 2.0, dur: 18000, del: 1600, op: 0.22, col: "#FF9860" },
            { xf: 0.74, yf: 0.84, sz: 3.0, dur: 17500, del: 400,  op: 0.28, col: "#E47849" },
            { xf: 0.85, yf: 0.74, sz: 2.0, dur: 16500, del: 2500, op: 0.21, col: "#FFE5CE" },
            { xf: 0.19, yf: 0.38, sz: 2.0, dur: 20000, del: 3300, op: 0.16, col: "#FFE5CE" },
            { xf: 0.79, yf: 0.36, sz: 2.0, dur: 17000, del: 900,  op: 0.18, col: "#FF9860" }
        ]
        delegate: Rectangle {
            required property var modelData
            width: modelData.sz
            height: modelData.sz
            radius: width * 0.5
            color: modelData.col
            x: bg.width * modelData.xf
            y: bg.height * modelData.yf
            opacity: 0
            SequentialAnimation on y {
                loops: Animation.Infinite
                running: bg.animate
                PauseAnimation { duration: modelData.del }
                NumberAnimation { from: bg.height * modelData.yf; to: bg.height * (modelData.yf - 0.30); duration: modelData.dur; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: bg.animate
                PauseAnimation { duration: modelData.del }
                NumberAnimation { to: modelData.op * bg.ambient; duration: modelData.dur * 0.35; easing.type: Easing.InOutSine }
                NumberAnimation { to: modelData.op * 0.75 * bg.ambient; duration: modelData.dur * 0.35; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: modelData.dur * 0.30; easing.type: Easing.InOutSine }
            }
        }
    }

    // Crisp subtle inner glass rim highlight
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        topLeftRadius: Math.max(0, bg.cardRadius - 1)
        bottomLeftRadius: Math.max(0, bg.cardRadius - 1)
        bottomRightRadius: Math.max(0, bg.cardRadius - 1)
        topRightRadius: Math.max(0, bg.topRightRadius - 1)
        color: "transparent"
        border.width: 1
        border.color: "#1AFFFFFF"
    }
}
