import QtQuick
import Quickshell
import Quickshell.Io

// The Claude Panel's live data, with the same shape the Studio panes were designed against (StudioMockData).
// Everything comes from the real session in the panel's terminal, never from its screen:
//   events.jsonl  hooks of that session (bridge.py hook): running/idle, attention, edited files, checklist
//   status.json   its statusLine input (bridge.py status): model, effort, version, context window, plan limits
//   bridge.py sessions / commands   recent sessions of the folder and its slash commands
// Pins and pane toggles are kept in ~/.local/state/claude-panel/prefs.json.
Item {
    id: store
    visible: false

    // the folder the session starts in: $CLAUDE_PANEL_CWD, else home (Claude asks there to trust it each time)
    property string cwd: Quickshell.env("CLAUDE_PANEL_CWD") || Quickshell.env("HOME") || "/"
    // extra claude arguments for the next start of the terminal (Resume sets --resume <id>; cleared once it started)
    property var launchArgs: []
    property bool active: true              // read files / run lists only while the panel exists
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string runDir: (Quickshell.env("CLAUDE_PANEL_RUN")
        || ((Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/claude-panel"))
    readonly property string repoRoot: {
        const env = Quickshell.env("CLAUDE_PANEL_ROOT");
        if (env) return env.replace(/\/+$/, "");
        const d = Quickshell.shellDir ? Quickshell.shellDir.toString().replace(/^file:\/\//, "") : "";
        return d.replace(/\/qml\/?$/, "");
    }
    readonly property string scriptDir: repoRoot + "/scripts"
    readonly property string launchScript: scriptDir + "/launch.sh"
    readonly property string bridgeScript: scriptDir + "/bridge.py"
    readonly property string statePath: home + "/.local/state/claude-panel/prefs.json"

    // ---------- pane toggles + pins (kept between sessions) ----------
    property bool showEditedFiles: true
    property bool showWorkspaceFiles: true
    property bool showCommandSearch: true
    property bool showCommandDesc: true
    property bool showSessions: true
    property string commandFilter: ""
    property var pinnedCommands: [ "/compact", "/plan", "/context", "/usage" ]
    property bool prefsLoaded: false

    onShowEditedFilesChanged: savePrefs()
    onShowWorkspaceFilesChanged: savePrefs()
    onShowCommandSearchChanged: savePrefs()
    onShowCommandDescChanged: savePrefs()
    onShowSessionsChanged: savePrefs()
    onPinnedCommandsChanged: savePrefs()

    function savePrefs() {
        if (!prefsLoaded) return;
        prefsFile.setText(JSON.stringify({
            pinnedCommands: pinnedCommands, showEditedFiles: showEditedFiles, showWorkspaceFiles: showWorkspaceFiles,
            showCommandSearch: showCommandSearch, showCommandDesc: showCommandDesc, showSessions: showSessions
        }, null, 2) + "\n");
    }

    FileView {
        id: prefsFile
        path: store.statePath
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (Array.isArray(d.pinnedCommands)) store.pinnedCommands = d.pinnedCommands.filter(c => typeof c === "string");
                for (const k of ["showEditedFiles", "showWorkspaceFiles", "showCommandSearch", "showCommandDesc", "showSessions"])
                    if (typeof d[k] === "boolean") store[k] = d[k];
            } catch (e) {}
            store.prefsLoaded = true;
        }
        onLoadFailed: store.prefsLoaded = true
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", home + "/.local/state/claude-panel"])

    // ---------- model / effort ----------
    readonly property var modelOptions: [
        { name: "Opus 5.5", slug: "claude-opus-5-5", note: "Deep reasoning" },
        { name: "Sonnet 5.5", slug: "claude-sonnet-5-5", note: "Fast daily driver" },
        { name: "Haiku 5.5", slug: "claude-haiku-5-5", note: "Instant & light" },
        { name: "Fable 5.2", slug: "claude-fable-5-2", note: "Most capable" }
    ]
    readonly property var effortOptions: [
        { name: "Low", slug: "low", note: "Quick responses" },
        { name: "Medium", slug: "medium", note: "Balanced depth" },
        { name: "High", slug: "high", note: "Thorough" },
        { name: "XHigh", slug: "xhigh", note: "Extra thorough" },
        { name: "Max", slug: "max", note: "Everything it has" }
    ]

    // ---------- live session state ----------
    property var status: ({})
    property bool agentRunning: false
    property bool needsAttention: false      // e.g. Claude waits for a permission answer
    property string attentionText: ""
    property string sessionId: ""
    property bool sessionLive: false         // SessionStart seen and no SessionEnd after it
    property var editedFiles: []
    property var checklist: []               // [{ id, text, status: pending | in_progress | completed }]

    readonly property string modelId: (status.model && status.model.id) || ""
    readonly property string modelName: (status.model && status.model.display_name) || ""
    readonly property string effortLevel: (status.effort && status.effort.level) || ""
    readonly property string cliVersion: status.version ? "v" + status.version : ""
    readonly property int modelIndex: {
        for (let i = 0; i < modelOptions.length; i++)
            if (modelId && modelId.indexOf(modelOptions[i].slug) === 0) return i;
        return -1;
    }
    readonly property int effortIndex: {
        for (let i = 0; i < effortOptions.length; i++) if (effortOptions[i].slug === effortLevel) return i;
        return -1;
    }
    readonly property var contextWindow: status.context_window || null
    readonly property real contextUsedPct: contextWindow && contextWindow.used_percentage !== null
        && contextWindow.used_percentage !== undefined ? contextWindow.used_percentage / 100 : 0
    readonly property string contextSummaryText: {
        if (!contextWindow) return "No session yet";
        const used = (contextWindow.current_usage && contextWindow.current_usage.input_tokens !== undefined)
            ? usageTokens(contextWindow.current_usage) : 0;
        return fmtTokens(used) + " / " + fmtTokens(contextWindow.context_window_size || 0) + " tokens";
    }
    readonly property string contextFreeText: {
        if (!contextWindow || contextWindow.remaining_percentage === null || contextWindow.remaining_percentage === undefined)
            return "Updates after Claude's first answer";
        return Math.round(contextWindow.remaining_percentage) + "% free";
    }
    // plan limits (statusLine `rate_limits`, only sent for subscription plans once Claude has answered)
    readonly property var limitSession: limitOf(["five_hour", "session"])
    readonly property var limitWeek: limitOf(["seven_day", "weekly_all", "weekly"])

    function usageTokens(u) {
        return (u.input_tokens || 0) + (u.cache_creation_input_tokens || 0) + (u.cache_read_input_tokens || 0);
    }
    function fmtTokens(n) {
        if (n >= 1000000) return (n / 1000000).toFixed(n % 1000000 === 0 ? 0 : 1) + "m";
        if (n >= 1000) return (n / 1000).toFixed(1) + "k";
        return String(n);
    }
    function limitOf(keys) {
        const rl = status.rate_limits;
        if (!rl || typeof rl !== "object") return null;
        let v = null;
        for (const k of keys) if (rl[k]) { v = rl[k]; break; }
        if (!v && Array.isArray(rl.limits)) {
            for (const row of rl.limits) if (keys.indexOf(row.kind) >= 0 || keys.indexOf(row.group) >= 0) { v = row; break; }
        }
        if (!v || typeof v !== "object") return null;
        let pct = v.used_percentage !== undefined ? v.used_percentage : (v.utilization !== undefined ? v.utilization : null);
        if (pct === null || pct === undefined) return null;
        if (pct > 1.0001) pct = pct / 100;
        const reset = v.resets_at !== undefined ? v.resets_at : null;
        return { pct: Math.max(0, Math.min(1, pct)), resetText: resetLabel(reset) };
    }
    function resetLabel(r) {
        if (r === null || r === undefined || r === "") return "";
        const d = typeof r === "number" ? new Date(r < 1e12 ? r * 1000 : r) : new Date(r);
        if (isNaN(d.getTime())) return "";
        const sameDay = d.toDateString() === new Date().toDateString();
        return "Resets " + (sameDay ? Qt.formatTime(d, "h:mmap") : Qt.formatDateTime(d, "MMM d, h:mmap"));
    }

    function shortPath(p) {
        if (home && p === home) return "~";
        return home && p.indexOf(home + "/") === 0 ? "~" + p.substring(home.length) : p;
    }
    function baseName(p) {
        const i = p.lastIndexOf("/");
        return i >= 0 ? p.substring(i + 1) : p;
    }

    // Rebuilds everything from the session's events (a session's file stays small: only these events are kept)
    function applyEvents(text) {
        const files = {}, order = [];
        let running = false, attention = false, attnText = "", sid = "", live = false;
        let tasks = [];
        const lines = text.split("\n");
        for (const line of lines) {
            if (!line) continue;
            let ev;
            try { ev = JSON.parse(line); } catch (e) { continue; }
            switch (ev.e) {
            case "SessionStart": sid = ev.sid; live = true; break;
            case "UserPromptSubmit": running = true; attention = false; break;
            case "Stop": case "StopFailure": running = false; attention = false; break;
            case "SessionEnd": running = false; attention = false; live = false; break;
            case "Notification":
                if (ev.kind !== "idle_prompt") { attention = true; attnText = ev.msg || ""; }
                break;
            case "edit": {
                attention = false;
                let f = files[ev.path];
                if (!f) {
                    f = files[ev.path] = { id: ev.path, name: baseName(ev.path), path: shortPath(ev.path),
                                           badge: ev.created ? "A" : "M", adds: 0, dels: 0, edits: 0, lines: [] };
                    order.push(ev.path);
                }
                f.adds += ev.adds || 0; f.dels += ev.dels || 0; f.edits += 1;
                if (f.lines.length) f.lines.push({ num: "", kind: "ctx", code: "···" });
                f.lines = f.lines.concat(ev.lines || []);
                if (f.lines.length > 1200) f.lines = f.lines.slice(f.lines.length - 1200);
                f.summary = "+" + f.adds + " / -" + f.dels + "  ·  " + f.edits + (f.edits === 1 ? " edit" : " edits");
                // newest first
                order.splice(order.indexOf(ev.path), 1); order.unshift(ev.path);
                break;
            }
            case "todos":
                tasks = (ev.todos || []).map((t, i) => ({ id: "todo-" + i, text: t.text, status: t.status }));
                break;
            case "TaskCreated":
                if (!tasks.some(t => t.id === ev.id)) tasks.push({ id: ev.id, text: ev.text, status: "pending" });
                break;
            case "taskUpdate":
                tasks = tasks.map(t => t.id === ev.id ? { id: t.id, text: ev.text || t.text, status: ev.status || t.status } : t);
                break;
            case "TaskCompleted":
                tasks = tasks.map(t => t.id === ev.id ? { id: t.id, text: t.text, status: "completed" } : t);
                break;
            }
        }
        editedFiles = order.map(p => files[p]);
        checklist = tasks;
        agentRunning = running && live;
        needsAttention = attention && live;
        attentionText = attnText;
        sessionId = sid;
        sessionLive = live;
    }

    FileView {
        id: eventsFile
        path: store.active ? store.runDir + "/events.jsonl" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: store.applyEvents(text())
        onLoadFailed: store.applyEvents("")
    }
    FileView {
        id: statusFile
        path: store.active ? store.runDir + "/status.json" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { store.status = JSON.parse(text()); } catch (e) {} }
        onLoadFailed: store.status = ({})
    }
    // status.json is replaced whole on each update (a file watch can lose a replaced file) and the run folder may not
    // exist before the first session: read again every 2 s while the panel exists (a ~2 KB file)
    Timer {
        interval: 2000; repeat: true
        running: store.active
        onTriggered: { statusFile.reload(); if (!eventsFile.loaded) eventsFile.reload(); }
    }

    // ---------- commands ----------
    readonly property var builtinCommands: [
        { cmd: "/compact", cat: "Session", desc: "Free up context by summarizing the conversation" },
        { cmd: "/clear", cat: "Session", desc: "Start a fresh conversation" },
        { cmd: "/resume", cat: "Session", desc: "Resume a previous session" },
        { cmd: "/rename", cat: "Session", desc: "Rename the current conversation" },
        { cmd: "/rewind", cat: "Session", desc: "Go back to an earlier point" },
        { cmd: "/export", cat: "Session", desc: "Export the conversation" },
        { cmd: "/plan", cat: "Workflow", desc: "Plan before editing" },
        { cmd: "/review", cat: "Workflow", desc: "Review the current changes" },
        { cmd: "/init", cat: "Workflow", desc: "Write a CLAUDE.md for this project" },
        { cmd: "/context", cat: "Usage", desc: "Show what fills the context" },
        { cmd: "/usage", cat: "Usage", desc: "Session cost, plan usage and activity" },
        { cmd: "/model", cat: "Config", desc: "Switch the model" },
        { cmd: "/effort", cat: "Config", desc: "Set the model's effort level" },
        { cmd: "/memory", cat: "Config", desc: "Edit Claude's memory files" },
        { cmd: "/permissions", cat: "Config", desc: "Manage tool permissions" },
        { cmd: "/agents", cat: "Tools", desc: "Manage subagents" },
        { cmd: "/hooks", cat: "Tools", desc: "Manage hooks" },
        { cmd: "/mcp", cat: "Tools", desc: "Manage MCP servers" },
        { cmd: "/doctor", cat: "Tools", desc: "Check the installation" }
    ]
    property var customCommands: []
    readonly property var allCommands: builtinCommands.concat(customCommands)

    Process {
        id: commandsProc
        command: ["python3", "-I", store.bridgeScript, "commands", store.cwd]
        stdout: StdioCollector {
            onStreamFinished: { try { store.customCommands = JSON.parse(text) || []; } catch (e) {} }
        }
    }

    // ---------- sessions ----------
    property var recentSessions: []
    Process {
        id: sessionsProc
        command: ["python3", "-I", store.bridgeScript, "sessions"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text) || [];
                    store.recentSessions = list.map(s => ({
                        id: s.id, title: s.title, time: store.ago(s.mtime), cwd: s.cwd, dir: store.shortPath(s.cwd),
                        model: store.prettyModel(s.model)
                    }));
                } catch (e) {}
            }
        }
    }
    function ago(ms) {
        const s = Math.max(0, (Date.now() - ms) / 1000);
        if (s < 60) return "just now";
        if (s < 3600) return Math.round(s / 60) + "m ago";
        if (s < 86400) return Math.round(s / 3600) + "h ago";
        return Math.round(s / 86400) + "d ago";
    }
    function prettyModel(id) {
        for (const m of modelOptions) if (id && id.indexOf(m.slug) === 0) return m.name;
        return id || "";
    }
    function refreshLists() {
        if (!active) return;
        if (!commandsProc.running) commandsProc.running = true;
        if (!sessionsProc.running) sessionsProc.running = true;
    }
    onActiveChanged: { refreshLists(); if (active) workspaceProc.running = true; }
    onCwdChanged: { refreshLists(); if (active) workspaceProc.running = true; }
    // a session that just ended or started shows up in the list
    onSessionIdChanged: { refreshLists(); if (sessionId !== "") launchArgs = []; }
    onAgentRunningChanged: if (!agentRunning) refreshLists()

    // ---------- workspace files: the folder's instruction files, read on demand ----------
    readonly property var workspaceCandidates: ["CLAUDE.md", "AGENTS.md", "README.md", ".claude/CLAUDE.md", home + "/.claude/CLAUDE.md"]
    property var workspaceFiles: []
    Process {
        id: workspaceProc
        command: ["python3", "-I", store.bridgeScript, "files", store.cwd].concat(store.workspaceCandidates)
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    store.workspaceFiles = (JSON.parse(text) || []).map(f => ({
                        id: f.path, name: f.name, path: store.shortPath(f.path), badge: "doc",
                        summary: f.total + " lines", lines: f.lines
                    }));
                } catch (e) {}
            }
        }
    }
    Timer { interval: 10; running: store.active; onTriggered: { store.checkAuth(); store.refreshLists(); workspaceProc.running = true; } }

    // ---------- who is signed in: the name Claude calls them (claude.ai profile), else the login name ----------
    property string accountName: ""
    readonly property string userName: accountName !== "" ? accountName : (Quickshell.env("USER") || "there")
    FileView {
        id: accountFile
        // Claude Code keeps the signed-in account here; read when the panel opens and after a sign-in (not watched:
        // Claude Code rewrites this file often)
        path: store.home + "/.claude.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const acc = JSON.parse(text()).oauthAccount || {};
                store.accountName = String(acc.displayName || "").trim();
            } catch (e) { store.accountName = ""; }
        }
        onLoadFailed: store.accountName = ""
    }

    // ---------- sign-in: `claude auth status` / `claude auth login` ----------
    property bool loggedIn: true             // assumed until the first check answers, so signed-in users never see a flash
    property bool authChecked: false
    property string loginUrl: ""
    readonly property bool loginRunning: loginProc.running
    Process {
        id: authProc
        command: ["claude", "auth", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { store.loggedIn = JSON.parse(text).loggedIn === true; } catch (e) {}
                store.authChecked = true;
            }
        }
    }
    function checkAuth() { if (active && !authProc.running) authProc.running = true; }
    Timer {     // while signed out, look every 3 s whether the browser sign-in finished
        interval: 3000; repeat: true
        running: store.active && store.authChecked && !store.loggedIn
        onTriggered: store.checkAuth()
    }
    function startLogin() {
        if (loginProc.running) return;
        loginUrl = "";
        loginProc.running = true;
    }
    function stopLogin() { if (loginProc.running) loginProc.signal(15); }
    function takeUrl(line) {
        const m = /https:\/\/\S+/.exec(line);
        if (m && store.loginUrl === "") store.loginUrl = m[0];
    }
    Process {
        id: loginProc
        command: ["claude", "auth", "login"]
        stdout: SplitParser { onRead: data => store.takeUrl(data) }
        stderr: SplitParser { onRead: data => store.takeUrl(data) }
        onExited: store.checkAuth()
    }
    onLoggedInChanged: { if (loggedIn) stopLogin(); accountFile.reload(); }
    function openUrl(url) { if (url) Quickshell.execDetached(["xdg-open", url]); }

    // ---------- the session process ----------
    // The terminal's shell runs launch.sh, which execs claude and writes its PID: stop it by that PID, checked first.
    function stopSession() {
        Quickshell.execDetached(["bash", "-c",
            'f="$1/claude.pid"; [ -f "$f" ] || exit 0; p=$(cat "$f"); case "$p" in ""|*[!0-9]*) exit 0;; esac; '
            + 'tr "\\0" " " < "/proc/$p/cmdline" 2>/dev/null | grep -q "^claude .*--settings $1/settings.json" && kill -TERM "$p"; '
            + 'rm -f "$f"', "_", runDir]);
    }
    Component.onDestruction: stopLogin()

    // ---------- the API the panes use (same as StudioMockData) ----------
    function allFiles() { return editedFiles.concat(workspaceFiles); }
    function fileById(fileId) {
        const list = allFiles();
        for (let i = 0; i < list.length; i++) if (list[i].id === fileId) return list[i];
        return null;
    }
    function isPinned(cmdName) { return pinnedCommands.indexOf(cmdName) !== -1; }
    function togglePin(cmdName) {
        const next = pinnedCommands.slice();
        const idx = next.indexOf(cmdName);
        if (idx >= 0) next.splice(idx, 1); else next.push(cmdName);
        pinnedCommands = next;
    }
    function reorderPinnedCommand(fromIdx, toIdx) {
        if (fromIdx < 0 || toIdx < 0 || fromIdx >= pinnedCommands.length || toIdx >= pinnedCommands.length || fromIdx === toIdx) return;
        const next = pinnedCommands.slice();
        const moved = next.splice(fromIdx, 1)[0];
        next.splice(toIdx, 0, moved);
        pinnedCommands = next;
    }
    function matchesQuery(cmdObj, query) {
        const q = (query || "").trim().toLowerCase();
        if (q === "") return true;
        return cmdObj.cmd.toLowerCase().indexOf(q) !== -1 || cmdObj.cat.toLowerCase().indexOf(q) !== -1
            || (cmdObj.desc || "").toLowerCase().indexOf(q) !== -1;
    }
    function commandByName(cmdName) {
        for (let i = 0; i < allCommands.length; i++) if (allCommands[i].cmd === cmdName) return allCommands[i];
        return null;
    }
    function starredCommandObjects(query, pinnedList) {
        const out = [];
        for (let i = 0; i < pinnedList.length; i++) {
            const obj = commandByName(pinnedList[i]);
            if (obj && matchesQuery(obj, query)) out.push(obj);
        }
        return out;
    }
    function unstarredCommandObjects(query, pinnedList) {
        return allCommands.filter(obj => pinnedList.indexOf(obj.cmd) === -1 && matchesQuery(obj, query));
    }
}
