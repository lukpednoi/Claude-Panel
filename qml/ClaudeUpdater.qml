import QtQuick
import Quickshell
import Quickshell.Io

// Background updater for standalone Claude Panel.
// Checks GitHub's version.txt 1 minute after start and then every 6 hours,
// caches the latest version under ~/.cache/claude-panel/, notifies once per
// new version via notify-send (if available), and applies git ff-only updates
// in place via `bin/claude-panel update --apply` without opening a terminal.
Item {
    id: root
    visible: false

    readonly property string repo: "lukpednoi/Claude-Panel"
    readonly property string rawVersionUrl: Quickshell.env("CLAUDE_PANEL_UPDATE_URL")
        || ("https://raw.githubusercontent.com/" + repo + "/main/version.txt")
    readonly property string repoRoot: {
        const env = Quickshell.env("CLAUDE_PANEL_ROOT");
        if (env) return env.replace(/\/+$/, "");
        const d = Quickshell.shellDir ? Quickshell.shellDir.toString().replace(/^file:\/\//, "") : "";
        return d.replace(/\/qml\/?$/, "");
    }
    readonly property string cliBin: repoRoot + "/bin/claude-panel"
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")) + "/claude-panel"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/claude-panel"
    readonly property string cacheFile: cacheDir + "/latest-version"
    readonly property string notifiedFile: stateDir + "/notified-version"

    property string localVersion: ""
    property string remoteVersion: ""
    property string notifiedVersion: ""
    property bool notifiedRead: false
    property bool checking: false
    property bool updating: false
    property bool restartNeeded: false
    property string updatedToVersion: ""
    property string lastError: ""
    property string lastCheckText: ""
    property bool manualCheck: false
    property bool _updExited: false
    property bool _updOutDone: false
    property bool _updErrDone: false
    property int _updExitCode: 0
    property string _updOutText: ""
    property string _updErrText: ""

    readonly property bool updateAvailable: localVersion !== "" && remoteVersion !== "" && newer(remoteVersion, localVersion)

    function parts(v) {
        return String(v || "0").split(/[^0-9]+/).filter(s => s !== "").map(n => parseInt(n, 10));
    }
    function newer(a, b) {
        const x = parts(a), y = parts(b);
        for (let i = 0; i < Math.max(x.length, y.length); i++) {
            const p = x[i] || 0, q = y[i] || 0;
            if (p !== q) return p > q;
        }
        return false;
    }
    function cleanVersion(s) {
        const t = String(s || "").trim().replace(/^v/i, "");
        return /^[0-9]+(\.[0-9]+){1,3}$/.test(t) ? t : "";
    }
    function formatNow() {
        return Qt.formatTime(new Date(), "HH:mm");
    }

    function check(manual) {
        if (fetchProc.running || updateProc.running || repoRoot === "") return;
        manualCheck = !!manual;
        if (manualCheck) lastError = "";
        checking = true;
        fetchProc.running = true;
    }

    function applyUpdate() {
        if (updateProc.running || fetchProc.running || repoRoot === "") return;
        lastError = "";
        _updExited = false;
        _updOutDone = false;
        _updErrDone = false;
        _updExitCode = 0;
        _updOutText = "";
        _updErrText = "";
        updating = true;
        updateProc.running = true;
    }

    function _finishUpdate() {
        if (!_updExited || !_updOutDone || !_updErrDone) return;
        const out = _updOutText.trim();
        const err = _updErrText.trim();
        localVerView.reload();
        if (_updExitCode === 0) {
            lastError = "";
            lastCheckText = "Checked " + formatNow();
            if (out.indexOf("Updated ") === 0) {
                const m = /->\s*v?([0-9]+(?:\.[0-9]+){1,3})/.exec(out);
                updatedToVersion = m ? m[1] : remoteVersion;
                restartNeeded = true;
            }
        } else {
            const msg = err || out || "Update failed";
            lastError = msg.split("\n")[0];
        }
        updating = false;
    }

    function restartPanel() {
        if (repoRoot === "") return;
        Quickshell.execDetached([cliBin, "restart", "--open"]);
    }

    FileView {
        id: localVerView
        path: root.repoRoot !== "" ? root.repoRoot + "/version.txt" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.localVersion = root.cleanVersion(text());
            root.maybeNotify();
        }
    }

    FileView {
        id: cacheVerView
        path: root.cacheFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.remoteVersion = root.cleanVersion(text());
            root.maybeNotify();
        }
    }

    FileView {
        id: notifiedVerView
        path: root.notifiedFile
        printErrors: false
        onLoaded: {
            root.notifiedVersion = root.cleanVersion(text());
            root.notifiedRead = true;
            root.maybeNotify();
        }
        onLoadFailed: {
            root.notifiedRead = true;
            root.maybeNotify();
        }
    }

    // Fetch version.txt with curl (fallback to python3 urllib) and atomically update cache only on valid semver.
    Process {
        id: fetchProc
        command: [
            "bash", "-c",
            'url="$1"; dst="$2"; mkdir -p "$(dirname "$dst")" || exit 1; '
            + 'if command -v curl >/dev/null 2>&1; then raw="$(curl -fsL --max-time 15 "$url")" || exit 1; '
            + 'else raw="$(python3 -c "import sys,urllib.request; print(urllib.request.urlopen(sys.argv[1], timeout=15).read().decode().strip())" "$url")" || exit 1; fi; '
            + 'ver="$(printf "%s" "$raw" | tr -d "\\r\\n" | sed "s/^[vV]//")"; '
            + 'printf "%s" "$ver" | grep -Eq "^[0-9]+(\\.[0-9]+){1,3}$" || exit 2; '
            + '(printf "%s\\n" "$ver" > "$dst.part" && mv -f "$dst.part" "$dst") || { rm -f "$dst.part"; exit 1; }',
            "_", root.rawVersionUrl, root.cacheFile
        ]
        onExited: function(code) {
            root.checking = false;
            if (code === 0) {
                root.lastCheckText = "Checked " + root.formatNow();
                root.lastError = "";
                cacheVerView.reload();
            } else if (root.manualCheck) {
                root.lastError = "Could not check GitHub";
            }
            root.manualCheck = false;
        }
    }

    // Apply git ff-only update in place via `bin/claude-panel update --apply`.
    Process {
        id: updateProc
        command: [root.cliBin, "update", "--apply"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._updOutText = text || "";
                root._updOutDone = true;
                root._finishUpdate();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root._updErrText = text || "";
                root._updErrDone = true;
                root._finishUpdate();
            }
        }
        onExited: function(code) {
            root._updExitCode = code;
            root._updExited = true;
            root._finishUpdate();
        }
    }

    // 1 minute after daemon start, then every 6 hours (matching Anserin's update cadence)
    Timer {
        interval: 60 * 1000
        running: root.repoRoot !== ""
        onTriggered: root.check(false)
    }
    Timer {
        interval: 6 * 60 * 60 * 1000
        repeat: true
        running: root.repoRoot !== ""
        onTriggered: root.check(false)
    }

    // Notify once per new remote version (skipped quietly if notify-send is unavailable)
    function maybeNotify() {
        if (!notifiedRead || !updateAvailable || remoteVersion === notifiedVersion || noticeProc.running) return;
        notifiedVersion = remoteVersion;
        Quickshell.execDetached([
            "bash", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"',
            "_", notifiedFile, remoteVersion
        ]);
        noticeProc.command = [
            "bash", "-c",
            'command -v notify-send >/dev/null 2>&1 || exit 0; '
            + 'notify-send -a "Claude Panel" -i software-update-available '
            + '"Claude Panel v$1 is available" '
            + '"Open Settings -> Updates or run: claude-panel update"',
            "_", remoteVersion
        ];
        noticeProc.running = true;
    }

    Process { id: noticeProc }
}
