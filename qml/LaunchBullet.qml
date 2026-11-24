import QtQuick

// Luminous Claude orange-gold launch streak fired from CornerRevolver's Claude chamber
// to the center of the card, scattering warm sparks and flaring into the card reveal.
Item {
    id: bullet

    property real fromX: 0
    property real fromY: 0
    property real toX: 0
    property real toY: 0
    property real holeR: 25
    property real progress: 0
    property real burst: 0
    property color coreColor: "#FFF5EA"
    property color accentColor: "#E47849"

    readonly property real dx: toX - fromX
    readonly property real dy: toY - fromY
    readonly property real dist: Math.max(1, Math.sqrt(dx * dx + dy * dy))
    readonly property real angle: Math.atan2(dy, dx) * 180 / Math.PI
    readonly property real headX: fromX + dx * progress
    readonly property real headY: fromY + dy * progress
    readonly property real tailLen: Math.min(dist * 0.42, 48 + 210 * Math.sin(Math.min(1, progress) * Math.PI))
    readonly property real beamThick: 5.0 - 1.6 * progress
    readonly property real nx: -dy / dist
    readonly property real ny: dx / dist

    visible: progress > 0 || burst > 0

    // Warm trailing spark embers drifting gently away from the flight axis
    Repeater {
        model: 12
        delegate: Rectangle {
            required property int index
            readonly property real lag: (index + 1) * 0.042
            readonly property real p: Math.max(0, bullet.progress - lag)
            readonly property real dir: index % 2 === 0 ? 1 : -1
            readonly property real spread: dir * (3 + index * 2.2) * Math.sin(bullet.progress * 3.8 + index * 1.1)
            readonly property real size: Math.max(1.5, 4.4 - index * 0.28)
            visible: bullet.progress > lag + 0.015 && bullet.burst < 0.95
            width: size
            height: size
            radius: size * 0.5
            x: bullet.fromX + bullet.dx * p + bullet.nx * spread - size * 0.5
            y: bullet.fromY + bullet.dy * p + bullet.ny * spread - size * 0.5
            color: index % 3 === 0 ? bullet.coreColor : bullet.accentColor
            opacity: (1 - index * 0.075) * 0.92 * (1 - bullet.burst * 1.1)
        }
    }

    // Sleek glowing orange-gold beam streak (head at origin 0,0, tapered tail behind)
    Item {
        visible: bullet.progress > 0.01 && bullet.progress < 0.995
        x: bullet.headX
        y: bullet.headY
        rotation: bullet.angle

        // Soft outer plasma sheath
        Rectangle {
            x: -bullet.tailLen
            y: -(bullet.beamThick * 1.9) * 0.5
            width: bullet.tailLen + 6
            height: bullet.beamThick * 1.9
            radius: height * 0.5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#00E47849" }
                GradientStop { position: 0.45; color: "#55E47849" }
                GradientStop { position: 0.88; color: "#CCFF965E" }
                GradientStop { position: 1.0; color: "#EEFFF4E8" }
            }
        }

        // Sharp inner white-orange filament
        Rectangle {
            x: -bullet.tailLen * 0.72
            y: -bullet.beamThick * 0.5
            width: bullet.tailLen * 0.72 + 4
            height: bullet.beamThick
            radius: height * 0.5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#00FF965E" }
                GradientStop { position: 0.55; color: "#DDF08A55" }
                GradientStop { position: 1.0; color: "#FFFFFAF2" }
            }
        }

        // Luminous pinpoint head
        Rectangle {
            width: 10
            height: 10
            radius: 5
            x: -width * 0.5
            y: -height * 0.5
            color: bullet.coreColor
        }
    }

    // Moving head aura
    Image {
        source: "assets/glow-orb.svg"
        sourceSize: Qt.size(128, 128)
        smooth: true
        width: bullet.holeR * 4.4
        height: width
        x: bullet.headX - width * 0.5
        y: bullet.headY - height * 0.5
        opacity: 0.85 * Math.min(1, bullet.progress * 3) * (1 - bullet.burst)
        visible: bullet.progress > 0 && bullet.burst < 0.99
    }

    // Impact glow at landing point (feeds smoothly into water reveal)
    Image {
        source: "assets/glow-orb.svg"
        sourceSize: Qt.size(128, 128)
        smooth: true
        width: bullet.holeR * 3.2 + 240 * bullet.burst
        height: width
        x: bullet.toX - width * 0.5
        y: bullet.toY - height * 0.5
        opacity: bullet.burst > 0.005 ? (0.9 * (1 - bullet.burst)) : 0
    }

    // Crisp warm energy ring expanding at impact
    Rectangle {
        visible: bullet.burst > 0.01 && bullet.burst < 0.99
        width: bullet.holeR * 0.9 + 210 * bullet.burst
        height: width
        radius: width * 0.5
        x: bullet.toX - width * 0.5
        y: bullet.toY - height * 0.5
        color: "transparent"
        border.width: Math.max(0.8, 2.2 * (1 - bullet.burst))
        border.color: Qt.alpha("#FF9C66", 0.72 * (1 - bullet.burst))
    }
}
