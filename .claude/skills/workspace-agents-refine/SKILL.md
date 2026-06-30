---
name: workspace-agents-refine
description: |
  Audits and refines Claude Code agent definitions against Anthropic orchestration best practices and a minimal tool/permission baseline. Produces a diff-style proposal report; never edits agents, workspace.py, settings.json, or rules directly.

  Works on any Claude Code workspace whose agents live in `.claude/agents/*.md` (optionally metadata-driven via Artisyn `workspace.py`). Grades each agent against a 14-point rubric, classifies tool and permission deviations, and identifies sub-domain splits that clear a 2x token-gain gate.

  Use when tuning agent descriptions, adding/removing agents, before publishing a workspace, or periodically after usage telemetry accumulates. Triggers: "refine agents", "audit agent orchestration", "optimize agent orchestration", "refine agent descriptions", "workspace agents refine". For broader workspace audits covering scope, tasks, and WHAT-vs-HOW classification, use the `workspace-audit` skill instead.

license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
metadata:
  category: sdlc-process
  level: "110"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-06-12"
  tags: [agents, claude-code, orchestration, audit, refinement, aila-workspace]
---

# Workspace Agents Refine

Audit and refine Claude Code agent definitions against Anthropic orchestration best practices and an embedded minimal tool/permission baseline. Propose improvements as a **diff-style report** only — this skill never edits agents, `workspace.py`, `settings.json`, or rules directly.

## Triggers

- "refine agents"
- "audit agent orchestration"
- "optimize agent orchestration"
- "refine agent descriptions"
- "workspace agents refine"

> **Related skills:** For broader workspace audits covering scope structure, task classification, and WHAT-vs-HOW analysis, use the `workspace-audit` skill. This skill is **propose-only**; to *apply* the prompt-anatomy (rubric items 10–14) to a single agent or skill with a reviewed, confirm-before-apply edit, use the `author-agent` skill — it edits the body source (`prompts/<name>.md`), not the generated file.

## What it does

Reads the current agent bundle, grades each agent against a 14-point orchestration rubric, compares tools and permissions against a documented minimal baseline, and identifies sub-domain splits that would reduce token usage by **>=2x**. Emits a single timestamped Markdown report with copy-paste-ready diffs that the user applies manually.

## When to use

- After manual tuning of `.claude/agents/*.md` bodies — verify nothing drifted from best practices.
- When adding or removing an agent — check the ripple into `workspace.py` (if Artisyn-managed), `routing.md`, `delegation.md`.
- Before publishing the workspace via the Artisyn catalog — confirm Kiro and Claude regeneration will both work.
- Periodically (e.g. after enough new agent invocations logged via the agent-usage hook) — evaluate whether any fat agent is now worth splitting.

## What it never does

- Edit agent `.md` files, `workspace.py`, `settings.json`, or any rules file.
- Run `python3 workspace.py generate` (destroys hand-tuned `.md` enrichments when metadata is Artisyn-managed).
- Read any file outside the current workspace root. All comparison material lives in this skill's `references/`.
- Post to Jira, Confluence, Slack, or any external system.
- Modify `MEMORY.md` or any other memory artifact.

## Inputs (all inside the workspace root)

Required:
- `.claude/agents/*.md` — current agent definitions.
- `.claude/rules/*.md` — orchestration wiring (`routing.md`, `delegation.md`, and any others present).
- `.claude/settings.json` — permissions and hooks.
- `references/anthropic-orchestration-checklist.md` (in this skill) — audit rubric.
- `references/tools-baseline.md` (in this skill) — minimal tool sets + preserve-with-reason instructions.
- `references/permissions-baseline.md` (in this skill) — settings.json shape.
- `references/bash-guard.md` (in this skill) — PreToolUse hook content.
- `references/token-gain-heuristic.md` (in this skill) — split-gate formula.
- `references/report-template.md` (in this skill) — report structure.

Optional:
- `workspace.py` — Artisyn metadata source, if the workspace is Artisyn-managed.
- Any agent-usage telemetry log directory the workspace configures (commonly `reporting/agent-usage/*.log`) — falls back to heuristic when absent.
- Project knowledge-base roots (e.g. `steering-docs/`, `docs/`, `kb/`) — headers read for scope-to-KB mapping.

## Output

One file at the workspace root:

```
workspace-agents-refine-<YYYYMMDD-HHMMSS>.md
```

The timestamp guarantees same-day reruns do not collide; never overwrite an existing report. Exact structure defined by `references/report-template.md`. Nothing else is written.

---

## Phase walkthrough

Execute these phases in order. Do not skip; each feeds the next.

### Phase 1 — Inventory

1. `Read` all files in `.claude/agents/*.md`. For each agent, capture:
   - Frontmatter: `name`, `description`, `tools`, `model`.
   - Body section headings (e.g. "Scope Boundary", "Knowledge-First Protocol", "Pattern Recording", "Invocation constraint", and the prompt-anatomy sections "Act and scope", "Evidence", "Report", "Output shape").
   - Total line count and approximate token count (line_count x 8 as a cheap heuristic).
2. `Read` every `.claude/rules/*.md` present. Build the set of *named* agents in routing vs. actual files — flag mismatches.
3. `Read` `.claude/settings.json`. Capture:
   - `permissions.allow`, `permissions.ask`, `permissions.deny`.
   - Hook matchers and commands.
4. If `workspace.py` exists at the workspace root, `Read` it. Capture each `Agent(...)` block's `tools`, `allowedTools`, `resources`, `model`, and `prompt=W.prompt_ref(...)` target. If no `workspace.py`, skip the `.md`-vs-Python consistency check in Phase 3.
5. Detect telemetry: `Glob` for any agent-usage log directory in the workspace (heuristics: `reporting/agent-usage/*.log`, `.claude/logs/agent-usage/*.log`, or whatever the project's settings.json hook writes to). If present, tally invocations per agent name. If absent, mark telemetry as unavailable.
6. Detect knowledge-base roots the agents reference in their bodies (common patterns: `steering-docs/**`, `docs/**`, `kb/**`, `wiki/**`). For each root present, read top-level headings to build a domain map. If no KB root is referenced, record `no KB detected` — code-specialist rubric items 6 and 7 degrade from `critical` to `warn` in that case.

Record everything in working notes; do not emit output yet.

### Phase 2 — Orchestration rubric audit

Open `references/anthropic-orchestration-checklist.md` and apply each of its 14 rubric items to every agent. For each finding, record:

- `agent_name`
- `rubric_item`
- `severity` — one of `critical`, `warn`, `info`
- `evidence` — 1-sentence quote or observation from the agent's file
- `proposed_fix` — a unified-diff block targeting the agent's `.md` (frontmatter or body)

### Phase 3 — Tools and permissions audit

1. Open `references/tools-baseline.md`. For each agent, infer its **class** (orchestrator / read-only reference / structured writer / code specialist / testing specialist / SDK operator) from its description and tool list. Compute the delta between its current `tools` list (from both the `.md` frontmatter and, when present, `workspace.py`) and the baseline for its class.
2. Classify every deviation:
   - `adopt` — the baseline is wrong for this workspace and should be updated.
   - `preserve-with-reason` — the extra tool has a documented reason in the agent body or a project `.claude/rules/*.md` file (quote the reason in the report).
   - `remove` — the tool is extraneous and no documented reason exists.
3. Open `references/permissions-baseline.md`. Compare `.claude/settings.json` to the expected allow/ask/deny shape. Flag:
   - Missing deny entries for destructive patterns.
   - Over-broad allow entries that should be path-scoped.
   - Absent PreToolUse hook (see next step).
4. Open `references/bash-guard.md`. Check whether `.claude/settings.json` has a `PreToolUse(Bash)` hook matching the bash-guard contract. If missing, propose adding it (the reference contains the full script body and activation snippet to drop in verbatim).

### Phase 4 — New-agent opportunity analysis

1. Open `references/token-gain-heuristic.md`.
2. Candidate sub-domains are **discovered from the current workspace**, not prescribed here. Walk every agent body over 400 lines and every agent whose description lists three or more distinct responsibilities — each is a potential split parent. For each, extract one or more candidate sub-domains by reading its body section headings and grouping adjacent sections that share a noun ("feature-area-A", "subsystem-B", "integration-X", "UI screens", etc.).
3. For each candidate:
   - Identify the parent agent whose body currently covers it.
   - Compute baseline load = `avg_prompt_tokens * invocation_count` if telemetry present; else fallback load = `parent_body_size_tokens * 10`.
   - Estimate the split:
     - `new_agent_body_tokens` = rough token cost of a focused agent (typically 800-1500 tokens for scope + protocol).
     - `parent_delegation_tokens` = tokens the parent would now spend just forwarding requests (typically 80-150 tokens).
     - `saved_tokens_per_query` = `parent_body_size_tokens - new_agent_body_tokens`.
4. Apply the gate: propose the new agent **only if** `saved_tokens_per_query x invocations >= 2 x (new_agent_body_tokens + parent_delegation_tokens x invocations)`. Show numerator and denominator in the report — do not assert without numbers.
5. For each proposal that clears the gate, prepare:
   - A full agent definition (frontmatter + body outline following the rubric in Phase 2).
   - The required addition to `workspace.py` if the workspace is Artisyn-managed (using `Agent(...)` with `W.prompt_ref(...)`; Artisyn vocabulary only).
   - The required addition to `.claude/rules/routing.md` (how other agents find this one).

### Phase 5 — Report

1. Open `references/report-template.md` for the exact section ordering, headings, and code-block conventions.
2. Populate every section with Phase 1-4 findings.
3. Write to `workspace-agents-refine-<YYYYMMDD-HHMMSS>.md` at the workspace root. The timestamp guarantees same-day reruns do not collide; never overwrite an existing report.
4. End with a one-paragraph summary under 120 words stating: agents audited (N), findings by severity, new agents proposed (N with estimated per-query savings), and which files the user must edit manually to apply.

Do not edit anything else. Do not print the report inline — the user opens the file.

---

## Artisyn standard compliance (when workspace.py is present)

If the workspace uses Artisyn `workspace.py`, every proposal the report emits must respect:

- **`workspace.py` primitives only** — `W`, `Agent`, `Prompt`, `ExternalLink`, `W.prompt_ref(...)`. No new constructs.
- **Artisyn tool vocabulary** — `fs_read`, `fs_write`, `execute_bash`, `grep`, `glob`, `use_subagent`. Claude-native names (`Read`, `Write`, `Bash`, `Grep`, `Glob`, `Agent`) are used in `.md` frontmatter only; `workspace.py` stays in Artisyn vocabulary so Kiro regeneration works.
- **Prompt separation** — agent bodies stay in `.md` files, referenced via `W.prompt_ref("<name>.md")`. Never inline a body into Python.
- **No generate side effect** — the apply checklist in the report explicitly instructs the user to run `python3 workspace.py validate --agent claude` and `--agent kiro` after applying metadata changes, and warns against `python3 workspace.py generate`.

If no `workspace.py` is present, skip these constraints and treat `.md` frontmatter as the sole source of truth for tool lists.

## Failure modes and how to handle them

- **Agent referenced in a rules file does not exist as a `.md` file** — record as a `critical` finding; propose either adding the agent or removing the routing entry.
- **Agent `.md` frontmatter `tools` list disagrees with `workspace.py`** — record as `critical`; propose aligning (workspace.py is the metadata source of truth when Artisyn-managed; if the `.md` list is richer, the Python side must be updated to match for regeneration to stay clean).
- **Telemetry missing** — note in Phase 4 that estimates used the body-size fallback; flag the new-agent gate as *heuristic-only, not telemetry-grounded*.
- **Report path already exists for today** — increment suffix; never overwrite.
- **Any reference file in this skill missing** — stop and report: "Skill bundle is incomplete, cannot proceed. Missing: `references/<name>.md`." Do not emit a partial report.

## Idempotence

Running the skill a second time after the user applies all proposed changes should produce a report whose executive summary shows **zero `critical` findings, zero `warn` findings, zero unjustified baseline divergences**. Any remaining finding must carry a written justification in the affected agent's body (a `<!-- baseline-divergence: <reason> -->` HTML comment is the canonical marker; the rubric treats its presence as closing the finding).
