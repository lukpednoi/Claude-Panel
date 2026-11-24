import QtQuick

// Claude Code launch welcome choreography:
// 1. Pinpoint golden-orange spark ignites at dead center and spins into the vibrant orange Claude starburst.
// 2. The starburst glides smoothly left while "Claude Code" (Noto Serif) emerges letter by letter into a
//    strictly centered [Starburst + Claude Code] lockup (zero clipping or left-shift jitter).
// 3. After a crisp hold, a warm flare drops "Claude Code" smoothly and sweeps curved glowing spark arcs
//    across the canvas as "[✦] Good morning, <user>" emerges centered with Clawd waving gently above the G.
Item {
    id: hero

    property real cardWidth: 1380
    property real cardHeight: 770
    property string userName: ""         // the signed-in account's name (ClaudeStore.userName)
    property bool autoPlay: true
    property real studioShiftP: 0.0   // 0..1 when transitioning upward into Studio
    property string greetingMode: "auto" // "auto" | "morning" | "afternoon" | "evening" | "night"
    property int currentHour: (new Date()).getHours()
    readonly property string greetingText: {
        if (greetingMode === "morning") return "Good morning,";
        if (greetingMode === "afternoon") return "Good afternoon,";
        if (greetingMode === "evening") return "Good evening,";
        if (greetingMode === "night") return "Good night,";
        if (currentHour >= 6 && currentHour < 12) return "Good morning,";
        if (currentHour >= 12 && currentHour < 17) return "Good afternoon,";
        if (currentHour >= 17 && currentHour < 21) return "Good evening,";
        return "Good night,";
    }
    readonly property real backdropFlare: Math.max(sparkFlare, arcFlare)
    signal waveFinished()
    signal sfxRequested(string file, real volume)

    readonly property string title: "Claude Code"
    readonly property var glyphs: title.split("")
    readonly property int glyphCount: glyphs.length
    readonly property real titleSize: Math.round(Math.max(40, Math.min(cardWidth * 0.060, cardHeight * 0.104)))
    readonly property real logoSize: Math.round(titleSize * 1.48)
    readonly property real logoGap: Math.round(titleSize * 0.28)
    readonly property real greetSize: Math.round(Math.max(24, Math.min(cardWidth * 0.029, cardHeight * 0.052)))
    readonly property real titleWidth: Math.max(1, fullTitle.advanceWidth)
    readonly property real lockupWidth: logoSize + logoGap + titleWidth
    readonly property real lockupLeftX: Math.round((cardWidth - lockupWidth) * 0.5)
    readonly property real centerLogoX: Math.round((cardWidth - logoSize) * 0.5)

    // Letter emergence timing (seconds)
    readonly property real glyphStagger: 0.055
    readonly property real glyphGrow: 0.22
    readonly property real lettersSpan: (glyphCount - 1) * glyphStagger + glyphGrow

    property real sparkP: 0
    property real logoP: 0
    property real glideP: 0
    property real lettersP: 0
    property real dropP: 0
    property real arcP: 0
    property real greetP: 0
    property real clawdP: 0

    readonly property real sparkFlare: sparkP > 0 && sparkP < 1 ? Math.sin(sparkP * Math.PI) * 0.85 : 0
    readonly property real arcFlare: arcP > 0 && arcP < 1 ? Math.sin(arcP * Math.PI) * 0.95 : 0

    width: cardWidth
    height: cardHeight

    function glyphP(index) {
        if (lettersP <= 0) return 0;
        const start = index * glyphStagger / lettersSpan;
        const span = glyphGrow / lettersSpan;
        return Math.max(0, Math.min(1, (lettersP - start) / span));
    }

    function reset() {
        seq.stop();
        sparkP = 0;
        logoP = 0;
        glideP = 0;
        lettersP = 0;
        dropP = 0;
        arcP = 0;
        greetP = 0;
        clawdP = 0;
        greetClawd.resetPose();
    }

    function play() {
        currentHour = (new Date()).getHours();
        reset();
        seq.restart();
    }

    onArcPChanged: {
        if (arcCanvas.visible) arcCanvas.requestPaint();
    }

    Component.onCompleted: if (autoPlay) play()

    SequentialAnimation {
        id: seq

        // Beat 1: Pinpoint flare + starburst spin-bloom at dead center
        ParallelAnimation {
            NumberAnimation { target: hero; property: "sparkP"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: 70 }
                NumberAnimation { target: hero; property: "logoP"; from: 0; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.22 }
            }
        }
        PauseAnimation { duration: 150 }

        // Beat 2: Starburst glides left first, then "Claude Code" blooms smoothly into centered lockup
        ParallelAnimation {
            NumberAnimation { target: hero; property: "glideP"; from: 0; to: 1; duration: 360; easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: 210 }
                NumberAnimation { target: hero; property: "lettersP"; from: 0; to: 1; duration: hero.lettersSpan * 1000; easing.type: Easing.Linear }
            }
        }
        PauseAnimation { duration: 460 }

        // Beat 3: Luminous flare drop + curved spark arcs -> "[✦] Good morning, <user>" + Clawd wave
        ParallelAnimation {
            NumberAnimation { target: hero; property: "dropP"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: hero; property: "arcP"; from: 0; to: 1; duration: 500; easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: 30 }
                ScriptAction { script: hero.sfxRequested("claude/wave.wav", 0.36) }
            }
            SequentialAnimation {
                PauseAnimation { duration: 185 }
                ParallelAnimation {
                    NumberAnimation { target: hero; property: "greetP"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
                    SequentialAnimation {
                        PauseAnimation { duration: 150 }
                        ParallelAnimation {
                            NumberAnimation { target: hero; property: "clawdP"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
                            ScriptAction { script: greetClawd.waveTwice() }
                        }
                    }
                }
            }
        }
    }

    Text {
        id: titleSpec
        visible: false
        text: hero.title
        font.family: "Noto Serif"
        font.pixelSize: hero.titleSize
        font.weight: Font.Medium
    }

    TextMetrics {
        id: fullTitle
        font: titleSpec.font
        text: hero.title
    }

    // Beat 1 pinpoint ignition light at dead center
    Item {
        anchors.centerIn: parent
        visible: hero.sparkP > 0.005 && hero.sparkP < 0.995
        opacity: Math.sin(hero.sparkP * Math.PI)

        Image {
            anchors.centerIn: parent
            source: "assets/glow-orb.svg"
            sourceSize: Qt.size(128, 128)
            smooth: true
            width: 80 + 240 * hero.sparkP
            height: width
            opacity: 0.95
        }

        Rectangle {
            anchors.centerIn: parent
            width: 14 * (1 - hero.sparkP * 0.5)
            height: width
            radius: width * 0.5
            color: "#FFF6EA"
            opacity: Math.max(0, 1 - hero.sparkP * 1.4)
        }
    }

    // Beats 1 & 2: Centered [Orange Claude Starburst + "Claude Code"] lockup
    Item {
        id: brandStage
        anchors.fill: parent
        visible: hero.logoP > 0.002 && hero.dropP < 0.998
        opacity: Math.max(0, 1 - hero.dropP * 1.15)
        transform: [
            Translate { y: hero.dropP * 42 },
            Scale {
                origin.x: hero.cardWidth * 0.5
                origin.y: hero.cardHeight * 0.5
                xScale: 1 - hero.dropP * 0.08
                yScale: 1 - hero.dropP * 0.08
            }
        ]

        // Vibrant orange Claude starburst (starts dead center, glides smoothly left to lockupLeftX)
        ClaudeLogo {
            id: heroLogo
            size: hero.logoSize
            color: "#E2774A"
            glowOpacity: (0.48 + 0.30 * Math.sin(hero.glideP * Math.PI)) * hero.logoP
            glowScale: 2.05
            iconScale: 0.16 + 0.84 * hero.logoP
            iconRotation: (1 - hero.logoP) * -52
            x: hero.centerLogoX + (hero.lockupLeftX - hero.centerLogoX) * hero.glideP
            y: Math.round((hero.cardHeight - height) * 0.5)
            opacity: Math.min(1, hero.logoP * 1.8)
        }

        // "Claude Code" aligned right of the starburst; zero width clipping, smooth letter bloom
        Row {
            id: lettersRow
            x: hero.lockupLeftX + hero.logoSize + hero.logoGap
            y: Math.round((hero.cardHeight - height) * 0.5)
            spacing: 0

            Repeater {
                model: hero.glyphs
                delegate: Item {
                    id: glyphSlot
                    required property int index
                    required property string modelData

                    readonly property real raw: hero.glyphP(index)
                    readonly property real p: 1 - Math.pow(1 - raw, 3)
                    property bool ticked: false

                    width: glyphMetrics.advanceWidth
                    height: glyphText.implicitHeight

                    TextMetrics {
                        id: glyphMetrics
                        font: titleSpec.font
                        text: glyphSlot.modelData
                    }

                    onRawChanged: {
                        if (raw <= 0.01) {
                            ticked = false;
                            return;
                        }
                        if (ticked || modelData === " ") return;
                        ticked = true;
                        hero.sfxRequested("claude/tick-" + (1 + (index % 3)) + ".wav", 0.42);
                    }

                    // Soft warm glow behind newly emerging letter
                    Image {
                        anchors.centerIn: glyphText
                        source: "assets/glow-orb.svg"
                        sourceSize: Qt.size(64, 64)
                        smooth: true
                        width: hero.titleSize * 1.35
                        height: width
                        opacity: glyphSlot.raw > 0 && glyphSlot.raw < 1 ? Math.sin(glyphSlot.raw * Math.PI) * 0.55 : 0
                        visible: opacity > 0.01
                    }

                    Text {
                        id: glyphText
                        anchors.verticalCenter: parent.verticalCenter
                        text: glyphSlot.modelData
                        font: titleSpec.font
                        color: "#FAF4EC"
                        opacity: Math.min(1, glyphSlot.p * 1.35)
                        scale: 0.78 + 0.22 * glyphSlot.p
                        transform: Translate {
                            x: (1 - glyphSlot.p) * -10
                            y: (1 - glyphSlot.p) * 6
                        }
                    }
                }
            }
        }
    }

    // Beat 3 curved glowing spark arcs (rendered only during the 480ms transition)
    Canvas {
        id: arcCanvas
        anchors.fill: parent
        visible: hero.arcP > 0.002 && hero.arcP < 0.998
        antialiasing: true

        readonly property var arcs: [
            { x0: 0.56, y0: 0.49, cx: 0.72, cy: 0.46, x1: 0.80, y1: 0.14, w: 3.1, del: 0.00 },
            { x0: 0.46, y0: 0.51, cx: 0.28, cy: 0.48, x1: 0.21, y1: 0.19, w: 2.7, del: 0.05 },
            { x0: 0.55, y0: 0.53, cx: 0.71, cy: 0.58, x1: 0.77, y1: 0.84, w: 2.8, del: 0.03 },
            { x0: 0.44, y0: 0.52, cx: 0.29, cy: 0.57, x1: 0.24, y1: 0.82, w: 2.5, del: 0.08 },
            { x0: 0.50, y0: 0.46, cx: 0.43, cy: 0.26, x1: 0.59, y1: 0.12, w: 2.3, del: 0.06 },
            { x0: 0.50, y0: 0.55, cx: 0.57, cy: 0.74, x1: 0.40, y1: 0.88, w: 2.3, del: 0.10 }
        ]

        function qPt(p0, pc, p1, t) {
            const mt = 1 - t;
            return mt * mt * p0 + 2 * mt * t * pc + t * t * p1;
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const p = hero.arcP;
            if (p <= 0.002 || p >= 0.998) return;

            for (let i = 0; i < arcs.length; i++) {
                const a = arcs[i];
                const local = Math.max(0, Math.min(1, (p - a.del) / (1 - a.del)));
                if (local <= 0.01 || local >= 0.99) continue;

                const tHead = Math.min(1, local * 1.12);
                const tTail = Math.max(0, tHead - 0.48 * (1 - local * 0.30));
                const alpha = Math.min(1, Math.sin(local * Math.PI) * 1.25);

                const x0 = a.x0 * width, y0 = a.y0 * height;
                const cx = a.cx * width, cy = a.cy * height;
                const x1 = a.x1 * width, y1 = a.y1 * height;

                const hx = qPt(x0, cx, x1, tHead);
                const hy = qPt(y0, cy, y1, tHead);
                const tx = qPt(x0, cx, x1, tTail);
                const ty = qPt(y0, cy, y1, tTail);

                const steps = 14;
                // Soft wide orange bloom pass
                const haloGrad = ctx.createLinearGradient(tx, ty, hx, hy);
                haloGrad.addColorStop(0.0, "rgba(226, 119, 74, 0.0)");
                haloGrad.addColorStop(0.6, "rgba(226, 119, 74, " + (0.34 * alpha).toFixed(3) + ")");
                haloGrad.addColorStop(1.0, "rgba(255, 168, 110, " + (0.45 * alpha).toFixed(3) + ")");
                ctx.strokeStyle = haloGrad;
                ctx.lineWidth = a.w * 3.2;
                ctx.lineCap = "round";
                ctx.beginPath();
                for (let s = 0; s <= steps; s++) {
                    const tt = tTail + (tHead - tTail) * (s / steps);
                    const px = qPt(x0, cx, x1, tt);
                    const py = qPt(y0, cy, y1, tt);
                    if (s === 0) ctx.moveTo(px, py);
                    else ctx.lineTo(px, py);
                }
                ctx.stroke();

                // Crisp bright inner spark core
                const grad = ctx.createLinearGradient(tx, ty, hx, hy);
                grad.addColorStop(0.0, "rgba(226, 119, 74, 0.0)");
                grad.addColorStop(0.55, "rgba(255, 152, 96, " + (0.85 * alpha).toFixed(3) + ")");
                grad.addColorStop(1.0, "rgba(255, 246, 234, " + (0.98 * alpha).toFixed(3) + ")");
                ctx.strokeStyle = grad;
                ctx.lineWidth = a.w;
                ctx.stroke();
            }
        }
    }

    // Beat 3 -> 4: Centered "[✦] Good morning, <user>" + Clawd perched neatly above G
    Item {
        id: greetStage
        anchors.fill: parent
        visible: hero.greetP > 0.002 && hero.studioShiftP < 0.72
        opacity: hero.greetP * Math.max(0, 1 - hero.studioShiftP * 2.4)
        transform: Translate {
            y: (1 - hero.greetP) * 18 - hero.studioShiftP * 92
        }

        // Subtle warm bloom behind greeting as it converges
        Image {
            anchors.centerIn: greetRow
            source: "assets/glow-orb.svg"
            sourceSize: Qt.size(128, 128)
            smooth: true
            width: greetRow.width * 1.45
            height: hero.greetSize * 5.2
            opacity: 0.42 * hero.greetP
        }

        Row {
            id: greetRow
            anchors.centerIn: parent
            spacing: Math.round(hero.greetSize * 0.36)

            ClaudeLogo {
                anchors.verticalCenter: parent.verticalCenter
                size: Math.round(hero.greetSize * 1.15)
                color: "#E2774A"
                glowOpacity: 0.58 * hero.greetP
                glowScale: 2.2
                iconScale: 0.62 + 0.38 * hero.greetP
                iconRotation: (1 - hero.greetP) * -28
            }

            Text {
                id: greetText
                anchors.verticalCenter: parent.verticalCenter
                text: hero.greetingText
                font.family: "Noto Serif"
                font.pixelSize: hero.greetSize
                font.weight: Font.Medium
                color: "#F5EEE6"

                TextMetrics { id: gMetrics; font: greetText.font; text: hero.greetingText.length > 0 ? hero.greetingText.charAt(0) : "G" }

                ClawdMascot {
                    id: greetClawd
                    autoWave: false
                    initialDelay: 120
                    bodyColor: "#E2774A"
                    unit: Math.max(2.5, hero.greetSize * 0.095)
                    x: Math.round(gMetrics.tightBoundingRect.x + gMetrics.tightBoundingRect.width * 0.5 - width * 0.5)
                    y: -height - 4 - (1 - hero.clawdP) * unit * 8
                    opacity: Math.min(1, hero.clawdP * 2.2)
                    onWaveFinished: hero.waveFinished()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: hero.userName
                // an account name can be long: keep it inside the card
                width: Math.min(implicitWidth, hero.cardWidth * 0.42)
                elide: Text.ElideRight
                font.family: "Noto Serif"
                font.pixelSize: hero.greetSize
                font.weight: Font.Bold
                color: "#E68052"
                opacity: Math.min(1, Math.max(0, (hero.greetP - 0.15) / 0.85))
                transform: Translate { x: Math.max(0, (1 - hero.greetP) * 14) }
            }
        }
    }
}
