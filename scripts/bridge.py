#!/usr/bin/env python3
"""Claude Panel bridge: the side channel between the panel's real `claude` terminal session and the panel UI.

The terminal runs the real Claude Code TUI; this script never reads its screen. Claude Code itself calls it:
  bridge.py hook        a hook (async, see launch.sh): appends one compact JSON line to events.jsonl
  bridge.py status      the statusLine command: writes status.json (atomically) and prints the status line
The panel calls it for lists it shows:
  bridge.py sessions         recent sessions of every folder (from ~/.claude/projects), JSON on stdout
  bridge.py commands <cwd>   user/project slash commands and skills, JSON on stdout
  bridge.py files <cwd> <names...>   the folder's instruction files that exist, with their lines
Files live in $CLAUDE_PANEL_RUN (default $XDG_RUNTIME_DIR/claude-panel).
"""
import json
import os
import sys
import time

RUN = os.environ.get("CLAUDE_PANEL_RUN") or os.path.join(
    os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}", "claude-panel")
EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
MAX_PATCH_LINES = 400
MAX_LINE = 300


def append_event(event):
    os.makedirs(RUN, exist_ok=True)
    event["ts"] = int(time.time() * 1000)
    line = (json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n").encode()
    # one write() on an O_APPEND file: lines from hooks that run at the same time never interleave
    fd = os.open(os.path.join(RUN, "events.jsonl"), os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
    try:
        os.write(fd, line)
    finally:
        os.close(fd)


def clip(text):
    text = str(text)
    return text if len(text) <= MAX_LINE else text[:MAX_LINE] + "…"


def patch_of(tool, inp, resp):
    """[{num, kind: add|del|ctx, code}] of what this tool call changed, plus +/- counts."""
    rows, adds, dels = [], 0, 0
    hunks = resp.get("structuredPatch") if isinstance(resp, dict) else None
    if hunks:
        for h in hunks:
            old_n, new_n = int(h.get("oldStart") or 1), int(h.get("newStart") or 1)
            for raw in h.get("lines") or []:
                mark, code = (raw[:1], raw[1:]) if raw else (" ", "")
                if mark == "+":
                    rows.append({"num": new_n, "kind": "add", "code": clip(code)}); new_n += 1; adds += 1
                elif mark == "-":
                    rows.append({"num": old_n, "kind": "del", "code": clip(code)}); old_n += 1; dels += 1
                else:
                    rows.append({"num": new_n, "kind": "ctx", "code": clip(code)}); old_n += 1; new_n += 1
    elif tool == "Write":
        for i, code in enumerate(str(inp.get("content") or "").split("\n")[:MAX_PATCH_LINES], 1):
            rows.append({"num": i, "kind": "add", "code": clip(code)}); adds += 1
    return rows[:MAX_PATCH_LINES], adds, dels


def cmd_hook():
    d = json.load(sys.stdin)
    e = d.get("hook_event_name") or ""
    base = {"e": e, "sid": d.get("session_id") or ""}
    if e == "SessionStart":
        base.update(src=d.get("source") or "", model=d.get("model") or "", cwd=d.get("cwd") or "",
                    transcript=d.get("transcript_path") or "")
    elif e in ("UserPromptSubmit", "Stop", "StopFailure", "PreCompact", "PostCompact"):
        pass
    elif e == "Notification":
        base.update(msg=clip(d.get("message") or ""), kind=d.get("notification_type") or "")
    elif e == "SessionEnd":
        base.update(reason=d.get("reason") or "")
    elif e in ("TaskCreated", "TaskCompleted"):
        base.update(id=str(d.get("task_id") or ""), text=clip(d.get("task_subject") or ""))
    elif e == "PostModelSwitch":
        base.update(model=d.get("to_model") or "")
    elif e == "PostToolUse":
        tool = d.get("tool_name") or ""
        inp = d.get("tool_input") or {}
        resp = d.get("tool_response") or {}
        if tool in EDIT_TOOLS:
            path = inp.get("file_path") or inp.get("notebook_path") or (resp.get("filePath") if isinstance(resp, dict) else "") or ""
            rows, adds, dels = patch_of(tool, inp, resp)
            created = isinstance(resp, dict) and resp.get("type") == "create"
            base.update(e="edit", tool=tool, path=path, created=created, lines=rows, adds=adds, dels=dels)
        elif tool == "TodoWrite":
            todos = [{"text": clip(t.get("content") or t.get("activeForm") or ""), "status": t.get("status") or "pending"}
                     for t in (inp.get("todos") or []) if isinstance(t, dict)]
            base.update(e="todos", todos=todos)
        elif tool == "TaskUpdate":
            base.update(e="taskUpdate", id=str(inp.get("taskId") or inp.get("task_id") or inp.get("id") or ""),
                        status=inp.get("status") or "", text=clip(inp.get("subject") or ""))
        else:
            return
    else:
        return
    append_event(base)


def cmd_status():
    d = json.load(sys.stdin)
    os.makedirs(RUN, exist_ok=True)
    tmp = os.path.join(RUN, "status.json.tmp")
    with open(tmp, "w") as f:
        json.dump(d, f)
    os.replace(tmp, os.path.join(RUN, "status.json"))
    model = (d.get("model") or {}).get("display_name") or ""
    effort = (d.get("effort") or {}).get("level") or ""
    pct = (d.get("context_window") or {}).get("used_percentage")
    parts = [p for p in (model, effort) if p]
    if pct is not None:
        parts.append(f"ctx {round(pct)}%")
    print(" · ".join(parts))


def project_dir(cwd):
    # Claude Code names a folder's project dir by its path with every non-alphanumeric character turned into "-"
    safe = "".join(c if c.isalnum() else "-" for c in os.path.abspath(cwd))
    return os.path.join(os.path.expanduser("~/.claude/projects"), safe)


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        for part in content:
            if isinstance(part, dict) and part.get("type") == "text":
                return part.get("text") or ""
    return ""


def chunk_lines(path, size=96 * 1024):
    """Lines of the file's head and tail only: session files grow to many MB, the title and model are near the end."""
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        end = f.tell()
        f.seek(0)
        head = f.read(min(size, end))
        tail = b""
        if end > size:
            f.seek(max(size, end - size))
            tail = f.read()
    lines = head.split(b"\n")
    if tail:
        lines += tail.split(b"\n")[1:]  # its first line is cut
    return (l.decode("utf-8", "replace") for l in lines if l.strip())


def session_info(path):
    title = custom = first = model = cwd = ""
    try:
        for line in chunk_lines(path):
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                t = d.get("type")
                if not cwd and isinstance(d.get("cwd"), str):
                    cwd = d["cwd"]
                if t in ("custom-title", "summary", "ai-title"):
                    val = d.get("customTitle") or d.get("summary") or d.get("aiTitle") or d.get("title") or ""
                    if t == "custom-title":
                        custom = val or custom
                    else:
                        title = val or title
                elif t == "user" and not first and not d.get("isMeta"):
                    txt = text_of((d.get("message") or {}).get("content")).strip()
                    if txt and not txt.startswith("<"):
                        first = txt
                elif t == "assistant":
                    model = (d.get("message") or {}).get("model") or model
    except OSError:
        return None
    name = custom or title or first
    if not name:
        return None
    return {"title": clip(" ".join(name.split()))[:90], "model": model, "cwd": cwd}


def cmd_sessions():
    """The newest sessions of every folder (like /resume's "all"), each with the folder it ran in."""
    root = os.path.expanduser("~/.claude/projects")
    files = []
    try:
        for d in os.listdir(root):
            pdir = os.path.join(root, d)
            try:
                files += [os.path.join(pdir, n) for n in os.listdir(pdir) if n.endswith(".jsonl")]
            except OSError:
                pass
    except OSError:
        pass
    stamped = []
    for p in files:
        try:
            stamped.append((os.path.getmtime(p), p))
        except OSError:
            pass
    stamped.sort(reverse=True)
    out = []
    for mtime, path in stamped[:80]:
        info = session_info(path)
        # a session is resumed in its own folder: leave out ones whose folder is gone
        if not info or not info["cwd"] or not os.path.isdir(info["cwd"]):
            continue
        info.update(id=os.path.basename(path)[:-6], mtime=int(mtime * 1000))
        out.append(info)
        if len(out) >= 30:
            break
    json.dump(out, sys.stdout)


def first_description(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            head = f.read(4000)
    except OSError:
        return ""
    if head.startswith("---"):
        for line in head.split("\n")[1:]:
            if line.strip() == "---":
                break
            if line.lower().startswith("description:"):
                return clip(line.split(":", 1)[1].strip().strip("\"'"))
    for line in head.split("\n"):
        s = line.strip().lstrip("#").strip()
        if s and s != "---":
            return clip(s)
    return ""


def cmd_commands(cwd):
    out, seen = [], set()
    roots = [(os.path.expanduser("~/.claude"), "User"), (os.path.join(cwd, ".claude"), "Project")]
    for root, cat in roots:
        cdir = os.path.join(root, "commands")
        for dirpath, _, names in os.walk(cdir):
            for n in sorted(names):
                if not n.endswith(".md"):
                    continue
                rel = os.path.relpath(os.path.join(dirpath, n), cdir)[:-3].replace(os.sep, ":")
                cmd = "/" + rel
                if cmd not in seen:
                    seen.add(cmd); out.append({"cmd": cmd, "cat": cat, "desc": first_description(os.path.join(dirpath, n))})
        sdir = os.path.join(root, "skills")
        try:
            names = sorted(os.listdir(sdir))
        except OSError:
            names = []
        for n in names:
            md = os.path.join(sdir, n, "SKILL.md")
            if os.path.isfile(md) and "/" + n not in seen:
                seen.add("/" + n); out.append({"cmd": "/" + n, "cat": "Skill", "desc": first_description(md)})
    json.dump(out, sys.stdout)


def cmd_files(cwd, names):
    """The folder's instruction files that exist: [{path, name, total, lines: [{num, kind: ctx, code}]}]."""
    out, seen = [], set()
    for n in names:
        path = os.path.realpath(os.path.join(cwd, n))   # an absolute name is used as is
        if path in seen or not os.path.isfile(path):
            continue
        seen.add(path)
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read(512 * 1024).split("\n")
        except OSError:
            continue
        rows = [{"num": i, "kind": "ctx", "code": clip(c)} for i, c in enumerate(text[:MAX_PATCH_LINES], 1)]
        out.append({"path": path, "name": os.path.basename(n), "total": len(text), "lines": rows})
    json.dump(out, sys.stdout)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        if cmd == "hook":
            cmd_hook()
        elif cmd == "status":
            cmd_status()
        elif cmd == "sessions":
            cmd_sessions()
        elif cmd == "commands":
            cmd_commands(sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~"))
        elif cmd == "files":
            cmd_files(sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~"), sys.argv[3:])
        else:
            print(__doc__, file=sys.stderr)
            return 2
    except Exception as exc:  # a broken event must never disturb the Claude session
        print(f"claude-panel bridge: {exc}", file=sys.stderr)
        return 0 if cmd in ("hook", "status") else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
