import QtQuick
import Quickshell
import Quickshell.Io

// Standalone Claude Panel entry point (Wayland wlr-layer-shell).
// Run via `bin/claude-panel` or directly with `quickshell -p qml/shell.qml`.
ShellRoot {
    id: root

    property bool shown: false
    property var targetScreen: null
    property var overlay: null

    function screenByName(name) {
        if (!name) return null;
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i];
        }
        return null;
    }

    function pickScreen(screenName) {
        return screenByName(screenName)
            || screenByName(Quickshell.env("CLAUDE_PANEL_SCREEN") || "")
            || Quickshell.screens[0]
            || null;
    }

    function openPanel(screenName) {
        if (shown) {
            if (overlay && overlay.experience.folded) overlay.experience.startUnfold();
            return;
        }
        targetScreen = pickScreen(screenName);
        shown = true;
    }

    function togglePanel(screenName) {
        if (!shown) {
            openPanel(screenName);
            return;
        }
        if (!overlay) return;
        const exp = overlay.experience;
        if (exp.folded) exp.startUnfold();
        else if (exp.loggedIn) exp.toggleFold();
    }

    function closePanel() {
        if (shown && overlay) overlay.experience.close();
    }

    function closed() {
        shown = false;
        overlay = null;
    }

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup(); }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup(); }
    }

    IpcHandler {
        target: "claude"
        function toggle(screenName: string): void { root.togglePanel(screenName); }
        function open(screenName: string): void { root.openPanel(screenName); }
        function close(): void { root.closePanel(); }
        function quit(): void {
            if (root.shown && root.overlay) root.overlay.experience.store.stopSession();
            Qt.quit();
        }
    }

    Loader {
        active: root.shown
        sourceComponent: ClaudeWelcomeOverlay {
            controller: root
            targetScreen: root.targetScreen
            onFinished: root.closed()
        }
    }

    Component.onCompleted: {
        Qt.application.organization = "claude-panel";
        Qt.application.name = "claude-panel";
        if (Quickshell.env("CLAUDE_PANEL_AUTO_OPEN") !== "0") {
            Qt.callLater(() => root.openPanel(""));
        }
    }
}
