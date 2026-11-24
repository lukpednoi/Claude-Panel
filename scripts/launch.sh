#!/usr/bin/env bash
# Starts the Claude Panel's real Claude Code session inside the panel's terminal.
#   launch.sh [--resume <id>] [other claude args...]
# The hooks and statusLine below are loaded with --settings for this session only (~/.claude/settings.json is never
# touched). They run bridge.py, which writes events.jsonl / status.json in $CLAUDE_PANEL_RUN for the panel to read.
set -u
HERE="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
RUN="${CLAUDE_PANEL_RUN:-${XDG_RUNTIME_DIR:-/run/user/$UID}/claude-panel}"
export CLAUDE_PANEL_RUN="$RUN"
mkdir -p "$RUN"
chmod 700 "$RUN"

BRIDGE="python3 -I '$HERE/bridge.py'"
# async hooks never slow Claude down; the ones that end a state run in step (~40 ms) so they are never lost on exit
HOOK="{\"type\":\"command\",\"command\":\"$BRIDGE hook\",\"async\":true,\"timeout\":10}"
SYNC="{\"type\":\"command\",\"command\":\"$BRIDGE hook\",\"timeout\":5}"
EVENTS=(SessionStart UserPromptSubmit TaskCreated TaskCompleted PostModelSwitch PreCompact PostCompact)
SYNC_EVENTS=(Stop StopFailure Notification SessionEnd)
{
    printf '{"hooks":{'
    for e in "${EVENTS[@]}"; do printf '"%s":[{"hooks":[%s]}],' "$e" "$HOOK"; done
    for e in "${SYNC_EVENTS[@]}"; do printf '"%s":[{"hooks":[%s]}],' "$e" "$SYNC"; done
    printf '"PostToolUse":[{"matcher":"Edit|Write|MultiEdit|NotebookEdit|TodoWrite|TaskUpdate","hooks":[%s]}]},' "$HOOK"
    printf '"statusLine":{"type":"command","command":"%s status"}}\n' "$BRIDGE"
} > "$RUN/settings.json.tmp" && mv "$RUN/settings.json.tmp" "$RUN/settings.json"

# The shell may have been (re)started from inside another Claude Code session and passes that session's markers on;
# with them this claude thinks it is that session's child (no transcripts, so /resume cannot find it). Drop them.
unset CLAUDECODE CLAUDE_PID CLAUDE_EFFORT CLAUDE_CODE_CHILD_SESSION CLAUDE_CODE_SESSION_ID CLAUDE_CODE_ENTRYPOINT \
      CLAUDE_CODE_EXECPATH CLAUDE_CODE_SESSION_ATTENDED CLAUDE_CODE_CHILD_NOTES_DIR CLAUDE_CODE_MESSAGING_SOCKET \
      CLAUDE_CODE_MESSAGING_TOKEN

# a new terminal session starts a new panel record (edited files, checklist, state)
: > "$RUN/events.jsonl"
rm -f "$RUN/status.json"
echo $$ > "$RUN/claude.pid"
exec claude --settings "$RUN/settings.json" "$@"
