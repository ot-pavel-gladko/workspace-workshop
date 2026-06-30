"""
artisyn-workspace-runner UI sidecar — Chainlit (Apache-2.0) chat app.

This file is thin glue only: it accepts operator messages (text + image/file
attachments) and hands them to the SAME lead-dispatch path the headless runner
uses — a `claude -p <dispatch> --append-system-prompt <lead_persona> ...`
subprocess, exactly as `run_claude()` in lib.sh.  There is no second
orchestration path around the lead; a message submitted here is equivalent to:

    docker compose run --rm artisyn-lead "<dispatch>"

The UI sidecar is OPTIONAL (compose profile "ui").  The headless artisyn-lead
and artisyn-watch services work without it and take no dependency on it.

Multimodal: Chainlit exposes file/image attachments via cl.Message.elements.
Text attachments are appended to the dispatch prompt; images are written to a
temporary file and referenced in the prompt so the lead can read them with its
vision tool.

Observability: if LANGFUSE_PUBLIC_KEY + LANGFUSE_SECRET_KEY + LANGFUSE_HOST are
set, the Langfuse SDK is initialised and each dispatch is traced as a single-step
span (input = dispatch prompt, output = stdout snippet, metadata = lead agent +
timestamp).  The Langfuse dashboard (port 3000, artisyn-langfuse compose service)
provides the running-agents activity view and agent session/trace replay (AC3).
The adlc/OpenObserve KPI tiles referenced in AC4 are surfaced via the iframe embed
at the bottom of the Chainlit page — they are NOT reimplemented here.
"""

from __future__ import annotations

import asyncio
import json
import os
import subprocess
import sys
import tempfile
import textwrap
from pathlib import Path

import chainlit as cl

# ---------------------------------------------------------------------------
# Paths — mirrors lib.sh constants (the sidecar runs in the same image).
# ---------------------------------------------------------------------------

_WORKSPACE_SRC = Path(os.environ.get("WORKSPACE_SRC", "/artisyn/workspace-src"))
_WORKSPACE_DST = Path(os.environ.get("WORKSPACE_DST", "/artisyn/workspace"))
_LIB_SH = Path("/usr/local/bin/lib.sh")

# ---------------------------------------------------------------------------
# Langfuse — optional; initialised once if credentials are present.
# ---------------------------------------------------------------------------

_lf_client = None

def _init_langfuse() -> None:
    global _lf_client
    pk = os.environ.get("LANGFUSE_PUBLIC_KEY", "")
    sk = os.environ.get("LANGFUSE_SECRET_KEY", "")
    host = os.environ.get("LANGFUSE_HOST", "")
    if not (pk and sk):
        return
    try:
        from langfuse import Langfuse  # noqa: PLC0415 — optional dep
        kwargs: dict = {"public_key": pk, "secret_key": sk}
        if host:
            kwargs["host"] = host
        _lf_client = Langfuse(**kwargs)
    except Exception:  # pragma: no cover
        pass


_init_langfuse()

# ---------------------------------------------------------------------------
# Workspace and lead-agent helpers (shell out to lib.sh where possible;
# fall back to Python reimplementations for the subset we need here).
# ---------------------------------------------------------------------------

def _sync_workspace() -> None:
    """Rsync the read-only workspace mount into the writable container copy.

    Equivalent to sync_workspace() in lib.sh.  Called once per chat session
    startup so the sidecar has the same agent view as the headless runner.
    """
    dst = str(_WORKSPACE_DST)
    Path(dst).mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "rsync", "-a", "--delete",
            "--exclude", ".git/",
            "--exclude", ".venv/",
            "--exclude", "node_modules/",
            "--exclude", "__pycache__/",
            "--exclude", "*.pyc",
            "--exclude", ".artisyn/cache/",
            "--exclude", ".aila/cache/",
            f"{_WORKSPACE_SRC}/",
            f"{dst}/",
        ],
        check=False,  # non-fatal; proceed even on partial sync failure
    )


def _discover_lead_agent() -> str:
    """Return the lead agent name from .claude/agents/ (mirrors lib.sh).

    Preference: file containing 'lead' in its basename. Falls back to the
    first .md in the directory.
    """
    agents_dir = _WORKSPACE_DST / ".claude" / "agents"
    if not agents_dir.is_dir():
        return "artisyn-lead"  # safe fallback name for display

    candidates = sorted(agents_dir.glob("*lead*.md"))
    if not candidates:
        candidates = sorted(agents_dir.glob("*.md"))
    if not candidates:
        return "artisyn-lead"
    return candidates[0].stem


def _lead_persona(agent_name: str) -> str:
    """Return the lead persona string (frontmatter stripped), equivalent to lead_persona() in lib.sh."""
    agent_file = _WORKSPACE_DST / ".claude" / "agents" / f"{agent_name}.md"
    if not agent_file.exists():
        return ""

    text = agent_file.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    body_lines: list[str] = []
    in_fm = False
    fm_done = False
    for line in lines:
        if not fm_done:
            if line.strip() == "---":
                if not in_fm:
                    in_fm = True
                    continue
                else:
                    fm_done = True
                    continue
            if not in_fm:
                fm_done = True
        if fm_done:
            body_lines.append(line)
    body = "\n".join(body_lines)

    return textwrap.dedent(f"""
You are operating as {agent_name}, the orchestrator and the single entry point for all
work in this workspace. You are the TOP-LEVEL session: never dispatch {agent_name} as a
subagent. Follow the lead-orchestration runbook at
.claude/skills/lead-orchestration/SKILL.md (five-anchor implementer brief,
sequencing/ADR gate, cost-loop capture). Delegate to the appropriate specialist agents
via the Agent tool, based on what the work needs.

MERGE REQUEST OVERVIEW (container runner specifics): the implementer pushes from
the container's own code repo clone and the merge request is auto-created by
git push options. GitLab derives the MR TITLE from the commit SUBJECT and the MR
DESCRIPTION from the commit BODY. So brief the implementer to write a STRUCTURED
COMMIT BODY that doubles as the MR overview, with these sections, above the
Co-Authored-By trailer:
  Summary: one line on what ships and why.
  Changes: 2-5 bullets of the concrete changes.
  Refs: <ticket-key>
  Test plan: how to verify (commands / expected output).
A bare commit body (only the trailer) produces an empty MR overview, which is not
acceptable. Keep the subject as <type>(<scope>): <ticket-key> <desc> with an accurate scope.

--- {agent_name} role definition ---
{body}
""").strip()


def _build_dispatch_prompt(message: cl.Message) -> tuple[str, list[str]]:
    """Build the dispatch string and a list of temp files to clean up.

    Text content of the message is the dispatch body.  File/image attachments
    are referenced by path (images) or appended as text (text files).
    Temp files returned must be removed by the caller after the dispatch.
    """
    parts: list[str] = [message.content or ""]
    tmp_files: list[str] = []

    for element in message.elements or []:
        # Chainlit elements: File (with path/content) or Image (with path/url/content).
        element_path: str | None = getattr(element, "path", None)
        element_content: bytes | str | None = getattr(element, "content", None)
        element_name: str = getattr(element, "name", "attachment") or "attachment"
        mime: str = getattr(element, "mime", "") or ""

        if element_path:
            src = element_path
        elif element_content is not None:
            # Write content to a temp file so the subprocess can read it.
            suffix = Path(element_name).suffix or ".bin"
            with tempfile.NamedTemporaryFile(
                delete=False, suffix=suffix, prefix="artisyn_ui_attachment_"
            ) as tf:
                if isinstance(element_content, str):
                    tf.write(element_content.encode("utf-8"))
                else:
                    tf.write(element_content)
                src = tf.name
                tmp_files.append(src)
        else:
            continue

        if mime.startswith("image/") or element_name.lower().endswith(
            (".png", ".jpg", ".jpeg", ".gif", ".webp")
        ):
            parts.append(f"\n[Attached image: {src}]")
        else:
            # Text / binary attachment: try to read and append.
            try:
                text = Path(src).read_text(encoding="utf-8", errors="replace")
                parts.append(f"\n[Attached file {element_name}]:\n```\n{text}\n```")
            except OSError:
                parts.append(f"\n[Attached file: {src}]")

    return "\n".join(p for p in parts if p), tmp_files


# Tool names Claude Code uses for a subagent dispatch (varies by version).
_SUBAGENT_TOOLS = {"Agent", "Task"}


def _subagent_name(inp: dict) -> str:
    return (
        inp.get("subagent_type")
        or inp.get("subagentType")
        or inp.get("subAgentType")
        or "subagent"
    )


def _op_summary(name: str, inp: dict) -> str:
    """A short, human one-liner for the CURRENT operation (not a full dump)."""
    for key in ("command", "file_path", "path", "pattern", "query", "url"):
        if key in inp and inp[key]:
            val = str(inp[key]).splitlines()[0]
            return f"{name} · {val[:80]}"
    return name


async def _run_dispatch_streaming(
    dispatch: str, agent_name: str, lead_msg: "cl.Message"
) -> tuple[int, str]:
    """Run the lead via `claude -p ... --output-format stream-json --verbose` and
    render it at a HIGH LEVEL: stream the lead's narration into `lead_msg`, keep a
    single inline-updated "current operation" line per context, and show each
    SUBAGENT as a named, nested step (lead -> 🤖 specialist -> 🤖 sub-specialist).
    Individual tool calls are NOT listed; they only update the active context's
    one-line status.

    This is NOT a second orchestrator: it execs the same `claude -p
    --append-system-prompt <persona>` binary as run_claude() in lib.sh; only the
    output FORMAT changes (stream-json) so the UI can render progress.

    Returns (exit_code, final_result_text).
    """
    persona = _lead_persona(agent_name)
    flags: list[str] = [
        "claude", "-p", dispatch,
        "--append-system-prompt", persona,
        "--permission-mode", os.environ.get("CLAUDE_PERMISSION_MODE", "acceptEdits"),
        "--output-format", "stream-json",
        "--verbose",  # required by Claude Code for stream-json in -p mode
    ]
    mcp_json = _WORKSPACE_DST / ".mcp.json"
    if mcp_json.exists():
        flags += ["--mcp-config", str(mcp_json)]

    proc = await asyncio.create_subprocess_exec(
        *flags,
        cwd=str(_WORKSPACE_DST),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )

    # One Step per "context": the lead (key None) gets a root activity line; each
    # subagent dispatch (keyed by its Agent/Task tool_use id) gets a named step
    # whose output is the subagent's live current-operation. Sub-subagents nest.
    ctx_step: dict[object, cl.Step] = {}
    agent_ids: set[str] = set()
    stderr_chunks: list[str] = []
    streamed_any = False
    final_text = ""

    async def _drain_stderr() -> None:
        assert proc.stderr is not None
        async for line in proc.stderr:
            stderr_chunks.append(line.decode("utf-8", "replace"))

    stderr_task = asyncio.create_task(_drain_stderr())

    async def _set(step: cl.Step, text: str) -> None:
        """Overwrite a step's status line inline (not append)."""
        step.output = text
        try:
            await step.update()
        except Exception:  # pragma: no cover — never let a UI hiccup kill the run
            pass

    # Root "activity" line for the lead's own operations.
    root = cl.Step(name="⚙️ activity", type="tool")
    try:
        await root.send()
    except Exception:  # pragma: no cover
        pass
    ctx_step[None] = root

    assert proc.stdout is not None
    async for raw in proc.stdout:
        line = raw.decode("utf-8", "replace").strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        etype = ev.get("type")
        parent = ev.get("parent_tool_use_id")
        here = ctx_step.get(parent) if parent else ctx_step.get(None)

        if etype == "assistant":
            for block in ev.get("message", {}).get("content", []):
                btype = block.get("type")
                if btype == "text" and block.get("text"):
                    text = block["text"]
                    if parent is None:
                        streamed_any = True
                        await lead_msg.stream_token(text)
                    elif here is not None:
                        # subagent narration → show a trimmed live snippet
                        await _set(here, "💭 " + " ".join(text.split())[:140])
                elif btype == "tool_use":
                    tid = block.get("id") or ""
                    name = block.get("name", "tool")
                    inp = block.get("input") or {}
                    if name in _SUBAGENT_TOOLS:
                        sub = _subagent_name(inp)
                        try:
                            step = cl.Step(
                                name=f"🤖 {sub}",
                                type="tool",
                                parent_id=here.id if here is not None else None,
                            )
                            step.input = str(inp.get("description") or "")[:200]
                            step.output = "⚙️ starting…"
                            await step.send()
                            ctx_step[tid] = step
                            agent_ids.add(tid)
                        except Exception:  # pragma: no cover
                            pass
                    elif here is not None:
                        # plain tool → just update this context's one-line status
                        await _set(here, "⚙️ " + _op_summary(name, inp))
        elif etype == "user":
            for block in ev.get("message", {}).get("content", []):
                if block.get("type") != "tool_result":
                    continue
                tid = block.get("tool_use_id") or ""
                if tid in agent_ids and tid in ctx_step:
                    await _set(ctx_step[tid], "✓ done")
        elif etype == "result":
            final_text = ev.get("result", "") or ""
            parts: list[str] = []
            if ev.get("num_turns") is not None:
                parts.append(f"{ev['num_turns']} turns")
            usage = ev.get("usage") or {}
            if usage.get("input_tokens") is not None and usage.get("output_tokens") is not None:
                parts.append(f"{usage['input_tokens']}+{usage['output_tokens']} tok")
            if ev.get("total_cost_usd") is not None:
                parts.append(f"${ev['total_cost_usd']:.4f}")
            if parts:
                cl.user_session.set("last_footer", " · ".join(parts))

    await proc.wait()
    await stderr_task
    await _set(root, "✓ done")

    if not streamed_any and final_text:
        await lead_msg.stream_token(final_text)
    rc = proc.returncode or 0
    if rc != 0 and not final_text:
        final_text = "".join(stderr_chunks)[:2000]
    return rc, final_text


# ---------------------------------------------------------------------------
# Chainlit lifecycle
# ---------------------------------------------------------------------------

@cl.on_chat_start
async def on_chat_start() -> None:
    """Sync workspace and discover lead agent; display session info."""
    _sync_workspace()
    agent_name = _discover_lead_agent()
    cl.user_session.set("lead_agent", agent_name)

    adlc_url = os.environ.get("ADLC_COCKPIT_URL", "")
    langfuse_url = os.environ.get("LANGFUSE_HOST", "http://localhost:3000")

    welcome = (
        f"**Artisyn workspace runner — UI sidecar**\n\n"
        f"Lead agent: `{agent_name}`\n\n"
        f"Type a dispatch message (e.g. `dispatch issue #42` or `what's next`). "
        f"You can attach images or files — they will be passed into the dispatch.\n\n"
        f"Activity dashboard (Langfuse traces): [{langfuse_url}]({langfuse_url})\n"
    )
    if adlc_url:
        welcome += f"Delivery KPIs (adlc cockpit): [{adlc_url}]({adlc_url})\n"

    await cl.Message(content=welcome).send()


@cl.on_message
async def on_message(message: cl.Message) -> None:
    """Handle an operator message: build dispatch, run lead, stream response.

    This is the single entry point for UI-originated dispatches.  It calls the
    same `claude -p ... --append-system-prompt <lead_persona>` path as lib.sh's
    run_claude() — NOT a separate orchestrator.
    """
    agent_name: str = cl.user_session.get("lead_agent") or _discover_lead_agent()
    dispatch, tmp_files = _build_dispatch_prompt(message)

    if not dispatch.strip():
        await cl.Message(content="Empty dispatch — please enter a message.").send()
        return

    # The lead's narration streams into this message; tool/subagent activity
    # renders as (nested) Steps alongside it.
    msg = cl.Message(content="")
    await msg.send()

    trace_id: str | None = None
    if _lf_client is not None:
        try:
            trace = _lf_client.trace(
                name="artisyn-ui-dispatch",
                input=dispatch,
                metadata={"lead_agent": agent_name},
            )
            trace_id = trace.id
        except Exception:  # pragma: no cover
            pass

    cl.user_session.set("last_footer", "")
    try:
        exit_code, output = await _run_dispatch_streaming(dispatch, agent_name, msg)
    finally:
        for tmp in tmp_files:
            try:
                os.unlink(tmp)
            except OSError:
                pass

    if trace_id and _lf_client is not None:
        try:
            _lf_client.generation(
                trace_id=trace_id,
                name="lead-dispatch",
                input=dispatch,
                output=output[:4000],
                metadata={"exit_code": exit_code, "lead_agent": agent_name},
            )
            _lf_client.flush()
        except Exception:  # pragma: no cover
            pass

    # Footer: turns · tokens · cost (from the stream's result event) + exit status.
    footer = cl.user_session.get("last_footer") or ""
    if exit_code == 0:
        if not (msg.content or "").strip():
            msg.content = "(dispatch completed — no output)"
        if footer:
            msg.content = (msg.content or "") + f"\n\n---\n_{footer}_"
    else:
        msg.content = (
            (msg.content or "")
            + f"\n\n---\n**Dispatch exited with code {exit_code}.**"
            + (f" _{footer}_" if footer else "")
            + "\n\nCheck `runner/.env` (CLAUDE_CODE_OAUTH_TOKEN) and the Steps above; "
            + "retry with `--dryrun` if it persists."
        )
    await msg.update()
