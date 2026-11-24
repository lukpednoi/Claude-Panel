import QtQuick
import QtQuick.Shapes

// Shared Claude Welcome + Login (Auth Gate) + Studio Type C experience:
// - Open: orange-gold energy streak from bottom-left -> layered bottom-left -> top-right liquid wave ->
//   After Effects-inspired Welcome Hero -> Login Auth Gate (`!loggedIn`) or Studio Type C (`loggedIn`).
// - Fold ("↙ พับเก็บ", signed-in Studio only): reverse liquid wave peels the card back (top-right -> bottom-left),
//   fires an orange-gold bullet down to the bottom-left corner, pops the corner dome and Clawd waves twice!
//   After waving: stands still when Idle (`!agentRunning`), or sits typing at a mini laptop when Running!
Item {
    id: stage

    property real frameInset: 10
    property real startX: frameInset + 29
    property real startY: height - frameInset - 109
    property real startHoleR: 25
    property string shaderUrl: ""
    property bool showCloseButton: true
    property bool autoStart: true
    // for photographs of a window that is not on screen (it gets no frames, so nothing animates): open still
    property bool still: false
    // the live session: sign-in, running/idle and everything the Studio shows come from the store
    readonly property alias store: claudeStore
    property bool loggedIn: claudeStore.loggedIn
    property bool agentRunning: claudeStore.agentRunning
    property string greetingMode: "auto"
    // the terminal takes the keyboard only while the open Studio is on screen
    readonly property bool wantsKeyboard: boxP > 0.99 && inStudio && !folded && exitP < 0.5

    ClaudeStore { id: claudeStore }
    readonly property var terminal: studioView.terminal
    onWantsKeyboardChanged: if (wantsKeyboard && studioView.terminal) Qt.callLater(() => studioView.terminal.focusTerminal())

    signal finished()
    signal loginLinkOpened(string url)
    signal sfxRequested(string file, real volume)

    readonly property real cardW: Math.min(width - 60, 1380)
    readonly property real cardH: Math.min(height - 50, 770)
    readonly property real cardX: Math.round((width - cardW) * 0.5)
    readonly property real cardY: Math.round((height - cardH) * 0.5)
    readonly property real cardCenterX: cardX + cardW * 0.5
    readonly property real cardCenterY: cardY + cardH * 0.5

    // the folded dome stays small so it never gets in the way (half of the first design)
    readonly property real domeBaseW: 38
    readonly property real domeBaseH: 33
    property real domeW: domeHover.hovered ? domeBaseW + 4 : domeBaseW
    property real domeH: domeHover.hovered ? domeBaseH + 3 : domeBaseH
    Behavior on domeW { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on domeH { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    readonly property real domeTargetX: frameInset
    readonly property real domeTargetY: height - frameInset - domeH
    readonly property real domeCenterX: frameInset + domeBaseW * 0.5
    readonly property real domeCenterY: height - frameInset - domeBaseH * 0.5

    // Exposed for PanelWindow pointer mask
    readonly property bool capturePointer: boxP > 0.01 || domeP > 0.01
    readonly property real maskX: boxP > 0.01 ? shellBox.x : cornerDome.x
    readonly property real maskY: boxP > 0.01 ? shellBox.y : cornerDome.y
    readonly property real maskW: boxP > 0.01 ? shellBox.width : cornerDome.width
    readonly property real maskH: boxP > 0.01 ? shellBox.height : cornerDome.height

    property real bulletP: 0
    property real burstP: 0
    property real boxP: 0
    property real ambient: 0
    property bool inStudio: false
    property real studioP: inStudio ? 1 : 0
    Behavior on studioP { enabled: !stage.still; NumberAnimation { duration: 560; easing.type: Easing.InOutCubic } }

    // Fold / corner dome choreography state
    property bool folded: false
    property bool bulletFromDome: false
    property bool cornerGreetDone: false
    property real studioFoldOut: 0
    property real foldBulletP: 0
    property real foldBurstP: 0
    property real domeP: 0
    property real exitP: 0

    // Brief CornerRevolver origin marker opacity: visible only during initial Replay All launch
    readonly property real introOriginOpacity: (!bulletFromDome && !folded && domeP < 0.05 && introFlow.running)
        ? Math.max(0, 1 - burstP * 1.45)
        : 0

    // closing like any window (SUPER + X over the panel): the exit fade, then the session ends
    function close() {
        if (exitFlow.running) return;
        foldFlow.stop(); unfoldFlow.stop(); introFlow.stop();
        if (folded) boxP = 0;
        exitFlow.start();
    }

    function enterStudio() {
        if (!inStudio) inStudio = true;
    }

    onLoggedInChanged: {
        if (!loggedIn && folded) {
            foldFlow.stop();
            unfoldFlow.stop();
            cornerGreetDone = false;
            cornerClawd.resetPose();
            folded = false;
            bulletFromDome = false;
            domeP = 0;
            studioFoldOut = 0;
            foldBulletP = 0;
            foldBurstP = 0;
            boxP = 1;
            ambient = 1;
        }
    }

    function startFold() {
        if (!loggedIn || folded || foldFlow.running || unfoldFlow.running) return;
        folded = true;
        bulletFromDome = true;
        cornerGreetDone = false;
        cornerClawd.resetPose();
        bulletP = 0;
        burstP = 0;
        foldBulletP = 0;
        foldBurstP = 0;
        foldFlow.restart();
    }

    function startUnfold() {
        if (!folded || foldFlow.running || unfoldFlow.running) return;
        bulletFromDome = true;
        unfoldFlow.restart();
    }

    function replayFull() {
        exitFlow.stop();
        foldFlow.stop();
        unfoldFlow.stop();
        introFlow.stop();
        hero.reset();
        cornerClawd.resetPose();
        folded = false;
        bulletFromDome = false;
        cornerGreetDone = false;
        inStudio = false;
        studioFoldOut = 0;
        foldBulletP = 0;
        foldBurstP = 0;
        domeP = 0;
        exitP = 0;
        bulletP = 0;
        burstP = 0;
        boxP = 0;
        ambient = 0;
        introFlow.restart();
    }

    function replayHero() {
        exitFlow.stop();
        foldFlow.stop();
        unfoldFlow.stop();
        introFlow.stop();
        hero.reset();
        cornerClawd.resetPose();
        folded = false;
        bulletFromDome = false;
        cornerGreetDone = false;
        inStudio = false;
        studioFoldOut = 0;
        foldBulletP = 0;
        foldBurstP = 0;
        domeP = 0;
        exitP = 0;
        bulletP = 1;
        burstP = 1;
        boxP = 1;
        ambient = 1;
        hero.play();
    }

    function toggleStudio() {
        if (folded) {
            startUnfold();
            return;
        }
        inStudio = !inStudio;
    }

    function toggleFold() {
        if (!loggedIn || foldFlow.running || unfoldFlow.running) return;
        if (folded) {
            startUnfold();
            return;
        }
        if (!inStudio) inStudio = true;
        startFold();
    }

    Component.onCompleted: {
        if (still) { bulletP = 1; burstP = 1; boxP = 1; ambient = 1; inStudio = true; }
        else if (autoStart) introFlow.start();
    }

    // Launch flow: corner streak -> bottom-left to top-right liquid wave -> Welcome Hero
    SequentialAnimation {
        id: introFlow
        ScriptAction { script: stage.sfxRequested("claude/shot.wav", 0.65) }
        NumberAnimation { target: stage; property: "bulletP"; from: 0; to: 1; duration: 165; easing.type: Easing.OutQuad }
        ParallelAnimation {
            NumberAnimation { target: stage; property: "boxP"; from: 0; to: 1; duration: 580; easing.type: Easing.Linear }
            NumberAnimation { target: stage; property: "burstP"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: stage; property: "ambient"; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: 190 }
                ScriptAction { script: stage.sfxRequested("claude/wave.wav", 0.42) }
            }
            SequentialAnimation {
                PauseAnimation { duration: 420 }
                ScriptAction { script: hero.play() }
            }
        }
    }

    // Fold flow: reverse liquid wipe (top-right -> bottom-left) + orange streak to corner ->
    // corner impact burst + dome pop + Clawd waves twice -> settles to Idle or Typing
    SequentialAnimation {
        id: foldFlow
        ParallelAnimation {
            NumberAnimation { target: stage; property: "studioFoldOut"; from: 0; to: 1; duration: 170; easing.type: Easing.OutCubic }
            NumberAnimation { target: stage; property: "boxP"; from: 1; to: 0; duration: 420; easing.type: Easing.Linear }
            SequentialAnimation {
                PauseAnimation { duration: 110 }
                ScriptAction { script: stage.sfxRequested("claude/wave.wav", 0.34) }
            }
            SequentialAnimation {
                PauseAnimation { duration: 250 }
                ScriptAction { script: stage.sfxRequested("claude/shot.wav", 0.62) }
                NumberAnimation { target: stage; property: "foldBulletP"; from: 0; to: 1; duration: 170; easing.type: Easing.InQuad }
            }
        }
        ParallelAnimation {
            NumberAnimation { target: stage; property: "foldBurstP"; from: 0; to: 1; duration: 340; easing.type: Easing.OutCubic }
            NumberAnimation { target: stage; property: "domeP"; from: 0; to: 1; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
            ScriptAction { script: cornerClawd.waveTwice() }
        }
    }

    // Unfold flow: dome pulls in -> fires orange-gold streak straight from the resting corner dome -> opens into Studio
    SequentialAnimation {
        id: unfoldFlow
        ScriptAction {
            script: {
                stage.cornerGreetDone = false;
                cornerClawd.resetPose();
                stage.studioFoldOut = 0;
                stage.bulletFromDome = true;
                stage.bulletP = 0;
                stage.burstP = 0;
                stage.foldBulletP = 0;
                stage.foldBurstP = 0;
                stage.inStudio = true;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: stage; property: "domeP"; from: 1; to: 0; duration: 135; easing.type: Easing.InCubic }
            SequentialAnimation {
                PauseAnimation { duration: 85 }
                ScriptAction {
                    script: {
                        stage.folded = false;
                        stage.sfxRequested("claude/shot.wav", 0.56);
                    }
                }
                NumberAnimation { target: stage; property: "bulletP"; from: 0; to: 1; duration: 145; easing.type: Easing.OutQuad }
            }
        }
        ParallelAnimation {
            NumberAnimation { target: stage; property: "burstP"; from: 0; to: 1; duration: 360; easing.type: Easing.OutCubic }
            NumberAnimation { target: stage; property: "boxP"; from: 0; to: 1; duration: 450; easing.type: Easing.Linear }
            NumberAnimation { target: stage; property: "ambient"; from: 0; to: 1; duration: 460; easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: 130 }
                ScriptAction { script: stage.sfxRequested("claude/wave.wav", 0.36) }
            }
        }
    }

    SequentialAnimation {
        id: exitFlow
        NumberAnimation { target: stage; property: "exitP"; from: 0; to: 1; duration: 300; easing.type: Easing.InOutSine }
        ScriptAction { script: { claudeStore.stopSession(); stage.finished(); } }
    }

    // Launch / Unfold energy streak (from CornerRevolver on initial open, or from corner dome on unfold -> card center)
    LaunchBullet {
        anchors.fill: parent
        holeR: stage.bulletFromDome ? 9 : stage.startHoleR
        fromX: stage.bulletFromDome ? stage.domeCenterX : stage.startX
        fromY: stage.bulletFromDome ? stage.domeCenterY : stage.startY
        toX: stage.cardCenterX
        toY: stage.cardCenterY
        progress: stage.bulletP
        burst: stage.burstP
    }

    // Fold energy streak (card center -> bottom-left corner dome)
    LaunchBullet {
        anchors.fill: parent
        holeR: 9
        fromX: stage.cardCenterX
        fromY: stage.cardCenterY
        toX: stage.domeCenterX
        toY: stage.domeCenterY
        progress: stage.foldBulletP
        burst: stage.foldBurstP
    }

    // Main Card Container: 1380x770 Welcome -> 1380x770 Studio Type C
    Item {
        id: shellBox
        visible: stage.boxP > 0.001
        opacity: 1 - stage.exitP
        x: stage.cardX
        y: stage.cardY
        width: stage.cardW
        height: stage.cardH
        clip: true

        Rectangle {
            id: cardSurface
            anchors.fill: parent
            color: "transparent"
            clip: true

            Item {
                id: cardContent
                anchors.fill: parent

                Rectangle {
                    id: cardFill
                    anchors.fill: parent
                    radius: 22
                    color: "#0A0807"
                    border.width: 1
                    border.color: "#4CE2774A"
                }

                WelcomeBackdrop {
                    ambient: stage.ambient * (1 - stage.studioFoldOut * 0.5)
                    flare: hero.backdropFlare * (1 - stage.studioP)
                    horizonGlow: stage.studioP > 0 && stage.studioP < 1 ? Math.sin(stage.studioP * Math.PI) : 0
                    cardRadius: 22
                    animate: stage.ambient > 0.02 && !stage.folded && stage.exitP < 0.5
                }

                // STAGE 1: WELCOME HERO
                Item {
                    width: stage.cardW
                    height: stage.cardH
                    visible: stage.boxP > 0.001 && stage.studioP < 0.72 && !stage.folded
                    opacity: 1 - stage.studioFoldOut

                    WelcomeHero {
                        id: hero
                        anchors.fill: parent
                        autoPlay: false
                        cardWidth: stage.cardW
                        cardHeight: stage.cardH
                        studioShiftP: stage.studioP
                        greetingMode: stage.greetingMode
                        userName: claudeStore.userName
                        onWaveFinished: stage.enterStudio()
                        onSfxRequested: function(file, vol) { stage.sfxRequested(file, vol) }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: stage.boxP > 0.9 && !stage.inStudio
                        cursorShape: Qt.PointingHandCursor
                        onClicked: stage.enterStudio()
                    }
                }

                // STAGE 2: LOGIN GATE (!loggedIn) OR STUDIO TYPE C (loggedIn)
                Item {
                    width: stage.cardW
                    height: stage.cardH
                    visible: stage.studioP > 0.14
                    opacity: Math.min(1, Math.max(0, (stage.studioP - 0.16) / 0.72)) * (1 - stage.studioFoldOut * 0.75)
                    transformOrigin: Item.BottomLeft
                    scale: (0.968 + 0.032 * stage.studioP) * (1 - stage.studioFoldOut * 0.04)
                    transform: Translate { y: (1 - stage.studioP) * 52 }

                    ClaudeStudioView {
                        id: studioView
                        anchors.fill: parent
                        visible: stage.loggedIn
                        store: claudeStore
                        // the session boots during the welcome, once sign-in is known
                        terminalAutoStart: claudeStore.authChecked && stage.loggedIn
                        stageWidth: stage.cardW
                        stageHeight: stage.cardH
                        showCloseButton: stage.showCloseButton
                        agentRunning: stage.agentRunning
                        cursorActive: stage.loggedIn && stage.inStudio && !stage.folded && stage.exitP < 0.5
                        onFoldRequested: stage.startFold()
                        onCloseRequested: exitFlow.start()
                    }

                    ClaudeLoginView {
                        anchors.fill: parent
                        visible: !stage.loggedIn
                        active: !stage.loggedIn && stage.inStudio && !stage.folded && stage.exitP < 0.5
                        loginUrl: claudeStore.loginUrl
                        waiting: claudeStore.loginRunning
                        onActiveChanged: if (active) claudeStore.startLogin()
                        showCloseButton: stage.showCloseButton
                        onCloseRequested: exitFlow.start()
                        onOpenLoginRequested: function(url) { claudeStore.openUrl(url); stage.loginLinkOpened(url) }
                        onSfxRequested: function(file, vol) { stage.sfxRequested(file, vol) }
                    }
                }
            }

            ShaderEffectSource {
                id: cardTexture
                sourceItem: cardContent
                hideSource: stage.boxP > 0.001 && stage.boxP < 0.999
                live: stage.boxP > 0.001 && stage.boxP < 0.999
                visible: false
            }

            // Layered water-wave reveal / reverse collapse
            ShaderEffect {
                anchors.fill: parent
                z: 50
                visible: stage.boxP > 0.001 && stage.boxP < 0.999
                property var source: cardTexture
                property vector2d itemSize: Qt.vector2d(width, height)
                property real reveal: stage.boxP
                property real amp: 24
                property real radius: 22
                property color crest: "#E47849"
                fragmentShader: stage.shaderUrl
            }
        }
    }

    // Concave fillet joins around the bottom-left folded dome
    Shape {
        id: frameJoins
        anchors.fill: parent
        visible: stage.domeP > 0.35
        opacity: Math.max(0, Math.min(1, (stage.domeP - 0.35) / 0.55)) * (1 - stage.exitP)
        preferredRendererType: Shape.CurveRenderer

        readonly property real joinR: 8
        readonly property real bx: cornerDome.x
        readonly property real by: cornerDome.y
        readonly property real bw: cornerDome.width
        readonly property real bh: cornerDome.height

        ShapePath {
            strokeColor: "transparent"
            fillColor: "#141110"
            startX: frameJoins.bx; startY: frameJoins.by - frameJoins.joinR
            PathLine { x: frameJoins.bx; y: frameJoins.by + 1 }
            PathLine { x: frameJoins.bx + frameJoins.joinR; y: frameJoins.by + 1 }
            PathArc {
                x: frameJoins.bx; y: frameJoins.by - frameJoins.joinR
                radiusX: frameJoins.joinR; radiusY: frameJoins.joinR
                direction: PathArc.Clockwise
            }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: "#141110"
            startX: frameJoins.bx + frameJoins.bw + frameJoins.joinR; startY: frameJoins.by + frameJoins.bh
            PathLine { x: frameJoins.bx + frameJoins.bw - 1; y: frameJoins.by + frameJoins.bh }
            PathLine { x: frameJoins.bx + frameJoins.bw - 1; y: frameJoins.by + frameJoins.bh - frameJoins.joinR }
            PathArc {
                x: frameJoins.bx + frameJoins.bw + frameJoins.joinR; y: frameJoins.by + frameJoins.bh
                radiusX: frameJoins.joinR; radiusY: frameJoins.joinR
                direction: PathArc.Counterclockwise
            }
        }
    }

    // STAGE 3: FOLDED CORNER DOME (pops out when fold streak lands, shows Clawd waving -> Idle / Typing)
    Item {
        id: cornerDome
        visible: stage.domeP > 0.01
        opacity: Math.min(1, stage.domeP * 1.35) * (1 - stage.exitP)
        x: stage.domeTargetX
        y: stage.domeTargetY
        width: stage.domeW
        height: stage.domeH
        transform: Scale {
            origin.x: 0
            origin.y: cornerDome.height
            xScale: Math.max(0.05, stage.domeP)
            yScale: Math.max(0.05, stage.domeP)
        }

        HoverHandler { id: domeHover }

        Rectangle {
            anchors.fill: parent
            topRightRadius: Math.min(width, height) * 0.72
            topLeftRadius: 0
            bottomLeftRadius: 0
            bottomRightRadius: 0
            color: "#141110"
            border.width: 1
            border.color: domeHover.hovered ? "#BAE2774A" : (stage.agentRunning ? "#7AE2774A" : "#4CE2774A")
        }

        // Subtle orange status glow behind Clawd while actively running
        Image {
            visible: stage.agentRunning && stage.cornerGreetDone
            anchors.centerIn: cornerClawd
            source: "assets/glow-orb.svg"
            sourceSize: Qt.size(32, 32)
            smooth: true
            width: 29
            height: 29
            opacity: 0.45
        }

        ClawdMascot {
            id: cornerClawd
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: (stage.folded && stage.cornerGreetDone && stage.agentRunning) ? 0 : -1
            anchors.verticalCenterOffset: 1
            unit: 1.25
            initialDelay: 60
            bodyColor: "#E2774A"
            autoWave: false
            typing: stage.folded && stage.cornerGreetDone && stage.agentRunning && stage.domeP > 0.85
            scale: domeHover.hovered ? 1.07 : 1.0
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            onWaveFinished: stage.cornerGreetDone = true
        }

        MouseArea {
            anchors.fill: parent
            enabled: stage.folded && stage.domeP > 0.8
            cursorShape: Qt.PointingHandCursor
            onClicked: stage.startUnfold()
        }
    }
}
