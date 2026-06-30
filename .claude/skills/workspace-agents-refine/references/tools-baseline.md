# Tools Baseline

Minimal tool sets per agent class, plus rules for identifying **preserve-with-reason** extras that a specific workspace legitimately needs.

All names use Artisyn vocabulary (`fs_read`, `fs_write`, `execute_bash`, `grep`, `glob`, `use_subagent`). Claude-native names (`Read`, `Write`, `Bash`, `Grep`, `Glob`, `Agent`) appear only in `.claude/agents/*.md` frontmatter — when the workspace is Artisyn-managed, `workspace.py` must stay in Artisyn vocabulary so Kiro regeneration works without mapping.

## Agent classes

Infer an agent's class from its description and current tool list. If the class is ambiguous, classify as the **least privileged** class that matches the description, and flag the ambiguity as `info`.

| Class | Role | Baseline `tools` (Artisyn) | Rationale |
|---|---|---|---|
| **Orchestrator** | Plans work, delegates to specialists, synthesizes results | `fs_read`, `use_subagent` | Reads KB and task files; delegates via sub-agents. No writes. No Bash — orchestration decisions are pure reasoning. |
| **Read-only domain expert** | Answers questions from documented knowledge | `fs_read`, `grep`, `glob` | Answers from KB and docs; needs search but never writes. |
| **Structured writer** | Authors stories, KB fragments, docs from a template | `fs_read`, `fs_write`, `grep`, `glob` | Writes structured artifacts; no shell, no source code navigation by default. |
| **Code specialist** | Implements/edits source in a scoped area | `fs_read`, `fs_write`, `execute_bash`, `grep`, `glob` | Full code control within its scope boundary. Bash needed for build/test. |
| **Testing specialist** | Writes and runs tests | `fs_read`, `fs_write`, `execute_bash`, `grep`, `glob` | Same as code specialist — tests are code. |
| **Catalog/schema reference** | Pure reference for types/structures | `fs_read` | Pure read-only reference. |
| **SDK operator** | Runs a specific SDK via shell | `fs_read`, `execute_bash` | Runtime SDK calls via Python/CLI in Bash; no writes by default. |

## Identifying preserve-with-reason extras

A tool on an agent that is **not** in its class baseline is either:

1. **preserve-with-reason** — the agent legitimately needs it, and the reason is already documented either in the agent's body or in a `.claude/rules/*.md` file. Examples of legitimate reasons you may find in a workspace:
   - Task-coordination tools (`TaskCreate`, `TaskUpdate`, `TaskGet`, `TaskList`) on an orchestrator — to create sub-tasks the user can observe.
   - Task-status tools (`TaskUpdate` only) on code specialists — to report progress back without chat-channel overhead.
   - Ticketing MCP tools (e.g. Jira, Linear, Azure DevOps) on an orchestrator — when the workspace's system of record is an external tracker and the orchestrator posts status comments.
   - `Agent` on an agent whose baseline already includes `use_subagent` — same capability surfaced under the Claude-native name.
2. **remove** — no documented reason exists.

**How the skill decides.** Before flagging a non-baseline tool as `remove`, search:
- The agent's own `.md` body for language justifying the tool (e.g. "uses TaskCreate to spawn sub-work").
- `.claude/rules/routing.md`, `.claude/rules/delegation.md`, `.claude/rules/workflows.md` for rules mentioning the tool or the convention it enables.
- The workspace root's `CLAUDE.md` for project-level instructions that require the tool.

If at least one of those sources documents the tool's role, classify as `preserve-with-reason` and quote the source in the report. Otherwise, classify as `remove`.

## Must-never-have

Flag these as `critical` any time they appear:

| Tool | Rule |
|---|---|
| `fs_write` / `Write` / `Edit` on a read-only domain or reference agent | Read-only means read-only. The capability itself is the enforcement. |
| `TaskCreate` on anything other than an orchestrator | Only the orchestrator creates tasks. Specialists only update. |
| External ticketing MCP tools on a non-orchestrator agent | Coordination with external trackers is an orchestrator concern. Specialists returning external-tracker artifacts leak coordination conventions. |
| `execute_bash` / `Bash` on a pure reference agent | No shell for pure reasoning/reference agents. |
| `Agent` / `use_subagent` on a non-orchestrator | Nested delegation is unreliable; see rubric item 4 in `anthropic-orchestration-checklist.md`. |

## Consistency rule (`.md` frontmatter vs. `workspace.py`)

When the workspace is Artisyn-managed, the `tools` list in agent `.md` frontmatter must match the `tools` and `allowedTools` lists in the agent's `workspace.py` block *after* the Artisyn<->Claude name mapping below. If they diverge, flag `critical` — regeneration will silently overwrite one or the other.

| Artisyn name | Claude-native name in `.md` |
|---|---|
| `fs_read` | `Read` |
| `fs_write` | `Write` (and `Edit` when editing is expected) |
| `execute_bash` | `Bash` |
| `grep` | `Grep` |
| `glob` | `Glob` |
| `use_subagent` | `Agent` |
| `TaskCreate` / `TaskGet` / `TaskList` / `TaskUpdate` | same (task tools are Claude-native only; carry them through unchanged) |
| `mcp__*` (MCP tools) | same |

When the skill proposes a tool-list change and the workspace is Artisyn-managed, it emits **two** diff blocks: one for the `.md` frontmatter (Claude-native) and one for the `workspace.py` block (Artisyn). Never only one side. When the workspace is not Artisyn-managed (no `workspace.py`), only the `.md` diff is emitted.

## Worked example — aligning a code specialist

Current state (abridged):
```yaml
# .claude/agents/backend.md
tools: Bash, Edit, Glob, Grep, Read, TaskUpdate, Write
```
```python
# workspace.py
TOOLS_CODE = ["fs_read", "fs_write", "execute_bash", "grep", "glob", "TaskUpdate"]
Agent(name="backend", tools=TOOLS_CODE, allowedTools=TOOLS_CODE, ...)
```

After mapping, `Bash, Edit, Glob, Grep, Read, TaskUpdate, Write` <-> `execute_bash, fs_write, glob, grep, fs_read, TaskUpdate, fs_write`. Note `Edit` and `Write` both map to `fs_write`; that's expected — Artisyn collapses them.

Result: consistent. No finding. `TaskUpdate` is preserved-with-reason only if the agent body or rules file documents the coordination convention.

## Worked example — a violation

If a read-only domain expert's `.md` had `tools: Read, Grep, Glob, Write` but `workspace.py` listed `["fs_read", "grep", "glob"]`, the `.md` has a write capability that the Python side does not. On regeneration, the `.md` reverts to read-only — the operator's change silently disappears. Flag `critical`; proposed fix reconciles both sides and keeps the agent read-only.
