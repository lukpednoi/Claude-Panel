import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// The Claude Panel on screen: a full-screen overlay that only takes the pointer over the card (or the folded dome)
// and the keyboard only while the open Studio shows, so the rest of the desktop keeps working.
PanelWindow {
    id: win
    property var targetScreen: null
    // where the launch streak starts (the bottom-left corner, where the folded dome rests)
    property real startX: 10 + 29
    property real startY: (targetScreen ? targetScreen.height : 1080) - 10 - 29
    property real startHoleR: 25
    readonly property alias experience: experience
    signal finished()
    // set by the shell controller so toggle keybinds can fold and unfold it
    property var controller: null
    Component.onCompleted: {
        if (controller) controller.overlay = win;
        Quickshell.execDetached(["mkdir", "-p", experience.store.runDir]);
    }

    screen: targetScreen || Quickshell.screens[0]
    WlrLayershell.namespace: "claude-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: experience.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"

    mask: Region {
        x: experience.capturePointer ? experience.maskX : -1
        y: experience.capturePointer ? experience.maskY : -1
        width: experience.capturePointer ? experience.maskW : 0
        height: experience.capturePointer ? experience.maskH : 0
    }

    PanelSfx { id: sfx }

    // Where the panel is on the desktop (the card, or the folded dome), exposed for compositor keybind scripts.
    readonly property string rectPath: experience.store.runDir + "/panel-rect"
    readonly property string rectText: experience.capturePointer && experience.exitP < 0.5
        ? [Math.round((win.screen ? win.screen.x : 0) + experience.maskX), Math.round((win.screen ? win.screen.y : 0) + experience.maskY),
           Math.round(experience.maskW), Math.round(experience.maskH)].join(" ") + "\n"
        : ""
    onRectTextChanged: rectTimer.restart()
    Timer { id: rectTimer; interval: 40; onTriggered: rectFile.setText(win.rectText) }
    FileView { id: rectFile; path: win.rectPath; printErrors: false; blockLoading: true; preload: false }
    Component.onDestruction: Quickshell.execDetached(["rm", "-f", win.rectPath])

    ClaudeExperience {
        id: experience
        anchors.fill: parent
        frameInset: 10
        startX: win.startX
        startY: win.startY
        startHoleR: win.startHoleR
        shaderUrl: sfx.shaderUrl
        showCloseButton: true
        onSfxRequested: function(file, vol) { sfx.play(file, vol) }
        onFinished: win.finished()
    }
}
