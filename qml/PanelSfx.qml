import QtQuick
import Quickshell
import Quickshell.Io

// Standalone path & SFX helper: resolves the repository's GPU shader and WAV sounds
// without depending on any desktop shell config. Optional config lives at
// ~/.config/claude-panel/config.json ({ "muteSfx": false, "sfxVolume": 100 }).
Item {
    id: helper
    visible: false

    readonly property string repoRoot: {
        const env = Quickshell.env("CLAUDE_PANEL_ROOT");
        if (env) return env.replace(/\/+$/, "");
        const d = Quickshell.shellDir ? Quickshell.shellDir.toString() : "";
        const clean = d.startsWith("file://") ? d.substring(7) : d;
        return clean.replace(/\/qml\/?$/, "");
    }
    readonly property string shaderUrl: "file://" + repoRoot + "/assets/shaders/claude_box_wipe.frag.qsb"
    readonly property string soundsRoot: repoRoot + "/assets/sounds/"
    readonly property string homeDir: Quickshell.env("HOME") || ""

    property bool muted: Quickshell.env("CLAUDE_PANEL_MUTE") === "1"
    property real volume: {
        const envVol = Quickshell.env("CLAUDE_PANEL_VOLUME");
        if (envVol !== "") {
            const parsed = Number(envVol);
            if (!isNaN(parsed)) return Math.max(0.0, Math.min(1.5, parsed));
        }
        return 1.0;
    }

    FileView {
        path: helper.homeDir ? (helper.homeDir + "/.config/claude-panel/config.json") : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data && typeof data === "object") {
                    if (typeof data.muteSfx === "boolean") helper.muted = data.muteSfx;
                    if (data.sfxVolume !== undefined) {
                        const v = Number(data.sfxVolume);
                        if (!isNaN(v)) helper.volume = Math.max(0.0, Math.min(1.0, v / 100.0));
                    }
                }
            } catch (e) {}
        }
    }

    function play(relPath, vol) {
        if (muted || volume <= 0.01 || !relPath) return;
        const v = Math.max(0.0, Math.min(1.5, (vol === undefined ? 0.6 : vol) * volume));
        if (v <= 0.01) return;
        const cleanRel = relPath.replace(/^claude\//, "");
        const fullPath = soundsRoot + cleanRel;
        const propsJson = "{\"application.id\":\"claude-panel-sfx\",\"application.name\":\"claude-panel-sfx\",\"media.role\":\"event\"}";
        try {
            Quickshell.execDetached(["pw-play", "-P", propsJson, "--volume=" + v.toFixed(2), fullPath]);
        } catch (e) {}
    }
}
