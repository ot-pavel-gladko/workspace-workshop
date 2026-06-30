#!/usr/bin/env python3
"""Log internal agent <-> Claude Code communication for observability.

Registered as a Claude Code hook on PreToolUse / PostToolUse / Stop. Pure
observer: reads the hook JSON on stdin, appends a structured JSONL record, and
emits a concise human line to the live console — the container's PID-1 stdout
when running in Docker, so `docker compose logs -f` shows agent activity in real
time despite `claude -p` output buffering. Never blocks a tool call: every error
is swallowed and the script always exits 0.

Capture policy (hybrid):
  - Task/Agent dispatches (PreToolUse) and their results (PostToolUse): full.
  - All other tool calls (PreToolUse): a one-line summary.
  - Non-agent PostToolUse: skipped (avoids doubling ordinary-tool noise).

Secrets (tokens, oauth URLs, JWTs, auth headers) are redacted before logging.

STORY-0048 AC6: writes to AGENT_COMMS_LOG_DIR (env var) when set, so logs
land in the host-visible bind-mounted path rather than only the container-internal
cwd. Falls back to <cwd>/.artisyn/logs when AGENT_COMMS_LOG_DIR is unset.
"""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone

_REDACTORS = [
    re.compile(r"glpat-[A-Za-z0-9_\-]{8,}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{8,}"),
    re.compile(r"sk-ant-[A-Za-z0-9_\-]{8,}"),
    re.compile(r"oauth2:[^@\s/]+"),
    re.compile(r"eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+"),  # JWT
    re.compile(r"(?i)(authorization|private-token|x-api-key)\s*[:=]\s*\S+"),
    re.compile(r"(?i)(token|secret|password|api[_-]?key)\"?\s*[:=]\s*\"?[A-Za-z0-9._\-]{8,}"),
]


def _redact(value):
    if not isinstance(value, str):
        try:
            value = json.dumps(value, default=str)
        except Exception:
            value = str(value)
    for rx in _REDACTORS:
        value = rx.sub("<redacted>", value)
    return value


def _truncate(text, limit):
    return text if len(text) <= limit else text[:limit] + f"...<+{len(text) - limit} chars>"


def main():
    raw = sys.stdin.read()
    if not raw.strip():
        return
    try:
        data = json.loads(raw)
    except Exception:
        return

    event = data.get("hook_event_name", "?")
    tool = data.get("tool_name", "")
    session = (str(data.get("session_id", "")) or "session")[:16]
    cwd = data.get("cwd") or os.getcwd()
    ts = datetime.now(timezone.utc).isoformat()
    tool_input = data.get("tool_input", {}) or {}
    tool_response = data.get("tool_response", "")
    is_agent = tool in ("Task", "Agent")

    record = {"ts": ts, "event": event, "session": session}
    line = None

    if event == "PreToolUse" and is_agent:
        subtype = tool_input.get("subagent_type", "?")
        desc = tool_input.get("description", "")
        prompt = _redact(tool_input.get("prompt", ""))
        record.update({"kind": "dispatch", "subagent": subtype,
                       "description": desc, "prompt": _truncate(prompt, 20000)})
        line = f"→ dispatch {subtype}: {desc or _truncate(prompt, 120)}"
    elif (event == "PostToolUse" and is_agent) or event == "SubagentStop":
        subtype = tool_input.get("subagent_type", "?")
        result = _redact(tool_response)
        record.update({"kind": "dispatch_result", "subagent": subtype,
                       "result": _truncate(result, 20000)})
        line = f"← {subtype} returned ({len(result)} chars)"
    elif event == "PreToolUse":
        summary = _redact(tool_input)
        record.update({"kind": "tool", "tool": tool, "input": _truncate(summary, 2000)})
        line = f"· {tool} {_truncate(summary, 120)}"
    elif event == "Stop":
        record.update({"kind": "session_stop"})
        line = "■ session stop"
    else:
        return  # non-agent PostToolUse and anything else: skip

    try:
        # STORY-0048 AC6: check for AGENT_COMMS_LOG_DIR env var so logs land in the
        # host-visible bind-mounted path rather than only the container-internal cwd.
        log_dir_env = os.environ.get("AGENT_COMMS_LOG_DIR")
        if log_dir_env:
            log_dir = log_dir_env
        else:
            log_dir = os.path.join(cwd, ".artisyn", "logs")
        os.makedirs(log_dir, exist_ok=True)
        with open(os.path.join(log_dir, f"agent-comms-{session}.jsonl"), "a", encoding="utf-8") as fh:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")
    except Exception:
        pass

    if line:
        msg = f"[agent-comms] {line}\n"
        wrote = False
        if os.path.exists("/.dockerenv"):
            try:
                with open("/proc/1/fd/1", "w") as pid1:
                    pid1.write(msg)
                wrote = True
            except Exception:
                wrote = False
        if not wrote:
            try:
                sys.stderr.write(msg)
            except Exception:
                pass


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
