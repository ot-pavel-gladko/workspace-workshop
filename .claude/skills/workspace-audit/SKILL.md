---
name: workspace-audit
description: |
  Audit how a workspace defines agents, scope, and tasks — classify each file as
  WHAT-focused (role identity, behavior contracts, acceptance criteria) or
  HOW-focused (file inventories, navigation imperatives, sequential mechanics),
  flag structural gaps, and produce concrete rewrite drafts aligned with the
  aidlc_hackathon reference pattern.

  HOW-focused task files shrink implementation to mechanical file-touching and
  produce shallow agent output. WHAT-focused scope files declare contracts and
  leave agents freedom, which produces substantive implementations. This skill
  reviews an existing workspace's agents, scope/design docs, and task/step
  files, then reports what to fix and drafts the aidlc-style replacement.

  Use when: a workspace's agents or tasks feel too prescriptive; agent output
  is unexpectedly shallow; tasks read like commit logs instead of scope; scope
  files lack acceptance criteria; orchestrator delegates without reading
  scope; onboarding aila-SDK workspace to the aidlc pattern.

  Triggers: "workspace audit", "audit workspace scope", "review my agents and tasks", "check
  workspace against aidlc pattern", "classify scope WHAT vs HOW", "why are my
  agents producing shallow implementations", "audit myproj-feature-area tasks". For
  a deeper orchestration-mechanics audit (9-point rubric, tool/permission baseline,
  split-gate analysis), use the `workspace-agents-refine` skill.

license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
metadata:
  category: workspace-structure
  level: "201"
  author: viktor.boldin@dataart.com
  version: "0.3.0"
  last_updated: "2026-04-25"
  tags:
    - workspace
    - agents
    - scope
    - specs
    - acceptance-criteria
    - aidlc
    - aila-sdk
    - audit
    - what-vs-how
---

# Workspace Audit

Audit a workspace's agents + scope + tasks against the `aidlc_hackathon`
WHAT-focused pattern. Produce a concern report with line-level evidence and
inline rewrite proposals.

## Quick Start

**What it does:** Classifies every agent/scope/task file as WHAT / MIXED /
HOW, detects structural gaps (missing overview, missing acceptance criteria,
orchestrator not wired to scope, no changelog), and drafts aidlc-style
rewrites for flagged files.

**When to use:**
- "Workspace audit"
- "Audit workspace scope"
- "Review my agents and tasks"
- "Why are my agents producing shallow implementations?"
- "Check workspace against aidlc pattern"

> **Related skill:** For a deeper agent-orchestration audit (9-point rubric, tool/permission baseline, split-gate analysis), use the `workspace-agents-refine` skill.

**Inputs:**
- Workspace root directory (default: cwd)
- Optional: explicit list of files to audit

**Outputs:**
- `workspace-audit-<YYYYMMDD>.md` at workspace root — full audit report
- Inline rewrite proposals for every flagged file (review-then-apply)
- Explicit acknowledgement of WHAT-aligned files so reviewer doesn't touch
  them

**Reference pattern:** agents in `.claude/commands/*.md` or `.claude/agents/*.md`,
scope in `specs/NN-*.md` with behavior acceptance criteria, single
`specs/00-overview.md` execution plan, `specs/CHANGELOG.md` for scope delta.
See [references/02-aidlc-templates.md](references/02-aidlc-templates.md) for
concrete examples of each artifact type.

---

## The WHAT vs HOW distinction

| Dimension | WHAT-focused (good) | HOW-focused (bad) |
|---|---|---|
| Agent prompt | Role identity, ownership, boundaries, stack, delegation | File paths to read, line numbers, tool-call sequences |
| Scope file | Data model, API contract, behavior acceptance criteria | "New files / Modified files" inventories, sequential steps |
| Acceptance criteria | `Join public room → user added as member` | `Edit models.py line 47 to add room table` |
| Layer section header | `## angular-web` (agent name) | `## Frontend` (generic) |

Rule of thumb: if you can delete the body and infer the file inventory from
the acceptance criteria alone, the file is WHAT-focused. If the acceptance
criteria list `.cs` / `.py` / `.ts` paths, it's HOW-focused.

See [references/01-classification-heuristics.md](references/01-classification-heuristics.md)
for the full signal catalog with greppable regexes.

---

## Workflow

### Step 1 — Discover artifacts

Scan the workspace for three artifact types. Patterns (matched from workspace
root):

| Bucket | Patterns |
|---|---|
| Agent definitions | `.claude/agents/*.md`, `.claude/commands/*.md` (exclude `generate/validate/info`), `prompts/*.md` |
| Scope / design docs | `specs/*.md`, `**/design/*.md`, `**/detailed-design.md`, `**/data-model.md`, `docs/design/*.md` |
| Task / step files | `**/tasks/*.md`, `**/step-*.md`, `TASKS.md`, `BACKLOG.md` |

Also record:
- Orchestrator agent (description contains "delegate" / "tech lead" / "orchestrat")
- Changelog location (`specs/CHANGELOG.md` / `CHANGELOG.md` — must reference scope IDs to count)
- Execution plan (`specs/00-*.md`, or README with agent-assignment matrix)

### Step 2 — Classify each artifact

For each discovered file, tally WHAT and HOW signals (see
[references/01-classification-heuristics.md](references/01-classification-heuristics.md)).

Classification rule:
- **WHAT** — 0 HOW signals AND ≥ 2 WHAT signals
- **HOW** — ≥ 2 HOW signals AND (HOW count > WHAT count)
- **MIXED** — otherwise

Special cases — record as informational tags, do **not** count as HOW:
- `INFO-NAVIGATION` — "Code Navigation Protocol" section (lookup, not execution)
- `INFO-STACK-DUPLICATION` — same stack/version block in `CLAUDE.md` and agent prompts (intentional context-pinning for isolated sub-agent runs)
- `INFO-INLINE-FIXTURE` — agent prompt inlines a canonical code fixture (`conftest.py`, `vite.config.ts`) that also lives in the repo (intentional for human readability)

See [references/01-classification-heuristics.md](references/01-classification-heuristics.md)
"Informational tags" section for the full list and exceptions.

### Step 3 — Structural checks (corpus-level)

Apply these checks across the whole workspace. Each produces a `GAP-*` or
`FLAG-*` code:

- `GAP-OVERVIEW` — no execution plan exists (`specs/00-*.md` / agent-assignment matrix)
- `FLAG-SCOPE-HEADER` — scope files lack `Components:` (or legacy `Agent:`) and `Depends on:` header (advisory; promoted to `GAP-*` only in `--mode strict`). `Phase:` is optional and not flagged. `Parallel with:` is deprecated.
- `GAP-AC` — scope files have no `Acceptance Criteria` section
- `FLAG-AC-NOT-BEHAVIOR` — AC items don't use behavior-arrow notation and don't state testable predicates
- `FLAG-LAYER-NAMING` — per-layer section headers use generic terms (`Frontend`/`Backend`) instead of agent names (`angular-web` / `promotions-backend`)
- `GAP-ORCHESTRATOR-SCOPE` — orchestrator prompt does not instruct the agent to read scope **or** a feature/product overview (README / overview doc / initial-goal) before delegating
- `GAP-CHANGELOG` — no scope-level changelog present or changelog is trivial (no references to shipped scope IDs)
- `FLAG-ORPHAN-SPEC` — files in `specs/` that are neither numbered scope files nor referenced from the overview (advisory; recommend relocate / namespace / explicit index)

### Scope rigor mode

Workspaces span a spectrum from *strict greenfield* (full scope locked
upfront, no scope drift) to *iterative/kanban* (scope grows as discoveries
land; tasks added mid-sprint or post-milestone). A single set of strict
checks misfires on the iterative end of that spectrum.

The skill runs in one of two modes:
- `--mode iterative` (default) — header-block conformance is advisory
  (`FLAG-SCOPE-HEADER`), no rewrite proposed solely for a missing header.
- `--mode strict` — promote `FLAG-SCOPE-HEADER` to `GAP-SCOPE-HEADER` and
  emit header rewrite proposals.

Auto-detection (when mode is unspecified): if `specs/00-overview.md` exists
**and** every `specs/NN-*.md` is referenced from it **and** there is no
`CHANGELOG.md` evidence of post-hoc tasks, default to strict; otherwise
default to iterative.

### Step 4 — Translate findings into recommendations

The classification (W/H signals, structural codes) is internal reasoning,
not the report's voice. The report itself reads like a senior reviewer's
audit: narrative, concrete, terse. Convert each finding into one of three
forms:

- **Per-agent recommendations** — for each flagged agent prompt, a small
  set of bullets starting with action verbs: **Add** … / **Adjust** … /
  **Trim** … / **Remove** … . Each bullet is 1–3 lines and names the
  specific change, not the signal code. Group multiple agents that share
  one fix under a combined header (e.g., `### /backend, /frontend, /docker`).
- **Worked example** — for HOW-coded scope/task files, a single
  `## Ticket / scope organization` section with one or two before/after
  code blocks. The Before quotes 4–8 lines of the offending section; the
  After is a recommended replacement (header block + AC, per the aidlc
  templates). Do not produce one block per file — one or two
  representative examples is enough.
- **Other gaps** — single-line bullets for cross-cutting issues that
  don't deserve a full rewrite block (orphan files, stale stack values,
  missing index entry).

Templates referenced internally:
- HOW task file → aidlc scope file (header + per-layer sections + behavior AC)
- Missing overview → `specs/00-overview.md` seeded from existing scope files
- Missing changelog → `specs/CHANGELOG.md` skeleton with `Unreleased` section
- Orchestrator gap → inline addition to the lead agent's prompt

### Step 5 — Honour guardrails

Before drafting any rewrite, check if the target file is auto-generated.
See [references/04-aila-sdk-constraints.md](references/04-aila-sdk-constraints.md).

For aila-SDK workspaces: `CLAUDE.md`, `.claude/agents/*.md`,
`.claude/rules/*.md` are all auto-generated. Rewrite proposals must target
the source of truth (`prompts/<agent>.md`, `workspace.py`) — never the
generated artifact.

### Step 6 — Emit the report

Write to `workspace-audit-<YYYYMMDD-HHMMSS>.md` at workspace root.
The timestamp guarantees same-day reruns do not collide; never overwrite
an existing audit. The report is a structured human-readable audit —
optimise for clarity and structure first, length second. Drop sections
that would be empty rather than padding with boilerplate, but do **not**
compact distinct findings into prose to hit a length target.

Format:

```markdown
# Workspace Audit — `<workspace-name>`

**Date:** YYYY-MM-DD HH:MM
**Workspace type:** Artisyn SDK | Not Artisyn SDK
**Scope:** N agents · M skills · K slash-commands · J scope files
(omit categories the workspace does not have; add others present —
e.g. `tasks/`, `prompts/`, `steering-docs/`).

### Critical elements

```text
<repo>/
├── .claude/commands/        # 6 slash-commands (lead, architect, ...)
├── specs/
│   ├── 00-overview.md       # execution plan + agent-assignment matrix
│   ├── CHANGELOG.md
│   ├── current-state.md
│   ├── 01-…16-…             # 16 numbered scope files
│   └── 13-jabber-design.md  # orphan (not linked from 00-overview)
├── CLAUDE.md
└── docker-compose.yml
```

(Hand-drawn ASCII tree of the artifacts the audit actually examined,
plus any one or two callouts useful for orienting the reader. Keep to
~12 lines. Skip files that are not load-bearing for this audit.)

---

## Summary

<2–4 sentences absorbing what was previously the intro paragraph: what
kind of workspace this is, where it sits on the strict→iterative
spectrum, what mode the audit ran in, the headline of the drift to
fix. This is the only place that frames the audit; do not repeat the
framing in later sections.>

Stats (one short line, no duplication of the framing above): N agents,
K flagged · M scope files, J flagged · CHANGELOG / overview / patterns
status.

- **<First concern title in bold.>** <2–3 sentences with enough detail
  to act on. Cite file paths inline.>
- **<Second concern.>** <Same shape.>
- **<Third concern, if any.>** <Same shape.>
- **<Fourth, fifth concern if present.>** <Each distinct drift gets its
  own bullet — do not merge two unrelated drifts into one bullet just
  to limit the count. Three bullets is typical, more is fine when the
  workspace genuinely has more distinct concerns.>

---

## Per-agent recommendations

### `/<agent>` (`<file path>`, N lines)

- **Add** <one specific change, 1–3 lines>. Where the rewrite is
  non-trivial, follow with a fenced code block of the recommended text.
- **Adjust** <one specific change>. …
- **Trim** <duplication or noise to remove>. …

### `/<agent>`, `/<agent>`, `/<agent>` (combined when fix is the same)

- **Trim** the shared "Project layout" block from each. The tree is
  already in `CLAUDE.md`; duplication makes Python/Node version a
  three-place update.
- **Add** a one-line "Scope contract" pointing at the per-task spec.

(Skip this entire section for agents that look right.)

**Recommendation rule:** orchestrator and code-agent prompts already use
`$ARGUMENTS` to receive a task. The argument is **flexible** — it can be
free-form text, a Jira ticket link, a `TASK-NN` ref, a feature
description, or a "read X then do Y" instruction. Recommendations that
say "open `specs/NN-*.md`" must therefore be conditional, not absolute.
Phrase as: "When the argument is a `TASK-NN` ref, open
`specs/NN-*.md` first; otherwise treat the argument as the task body."
This preserves the lead-via-Jira-link path without losing the scope-file
path.

---

## Ticket / scope organization

<1–2 sentences: the typical scope shape, named exemplars (e.g., "see
`02-auth.md` or `05-rooms.md` as exemplars"). One or two outliers worth
reshaping.>

Current shape — `<path>` (lines N–M):

```
<4–8 line excerpt of the HOW-coded section>
```

Recommended shape:

```
<aidlc-style replacement: header block + Acceptance Criteria>
```

(One worked example, two at most. Do not produce one block per flagged
file — the example is the pattern, not the deliverable.)

---

## Feedback channels & shared state

- **`<file>` — exists, healthy.** <One-line description of what it
  carries and why it matters.>
- **`<file>` — missing.** <One-line description of what would go in it
  and why this is worth adding.>
- **<Practice observation>.** <e.g., "AC checkboxes are flipped to
  `[x]` on completion across 12 of 15 spec files — keep the practice.">

(Mention `specs/patterns.md` here only if the workspace would genuinely
benefit; do not add it as boilerplate.)

---

## Other gaps

- <Single-line observation>.
- <Single-line observation>. (Stale value, orphan file, missing index
  entry, regex-able drift, etc.)
- …

(Tight bulleted list. One line each. No headers, no code blocks.)
```

Voice and format rules:

- The recommendation is the deliverable, not the signal code. Do **not**
  print `H2` / `GAP-AC` / `FLAG-SCOPE-HEADER` codes in the report body.
  The codes exist for the audit's internal reasoning only.
- Per-agent bullets start with **Add** / **Adjust** / **Trim** / **Remove**.
- One distinct drift per bullet. Do not merge two unrelated drifts (e.g.,
  "TASK-14 missing header AND TASK-15 has line numbers in design") into
  one bullet to keep the list short — split them.
- Workspace-type line is a binary tag: `Artisyn SDK` or `Not Artisyn SDK`.
  Don't expand into "hand-authored (no `workspace.py`, no `.aila/` ...)";
  the audit's behaviour follows from the tag, not from prose.
- Scope line is a short categorized count: agents, skills, slash-commands,
  scope files. Add categories the workspace actually has (`prompts/`,
  `tasks/`, `steering-docs/`); omit ones it doesn't. Do not enumerate
  filenames in the scope line.
- The Critical elements tree is the structural orientation device. It
  carries the load that prose framing previously did, so the framing
  paragraph between the header and Summary is dropped.
- "What looked right" is folded into prose where natural (named exemplars
  in scope-organization, healthy bullets in feedback channels). Do **not**
  emit a separate "What looked right" section.
- "Fix sequence" / "Quality checklist" / "Classification table" are
  **internal reasoning artifacts**. Do not emit them in the report.
- For Artisyn SDK workspaces, append a one-line "How to apply" at the end
  of any rewrite that targets a generated artifact's source. Do **not**
  repeat the guardrail in every section.
- Length follows from findings. Do not compact distinct findings into
  prose to hit a length target. Do not pad with "no issues found"
  boilerplate to fill sections. Drop empty sections; expand sections
  that have real content to cover.

See [references/03-sample-report.md](references/03-sample-report.md) for
a worked example matching this format.

#### Optional appendix (only when the user requests it)

If the user asks for the underlying classification (`--show-classification`
or "show me the signals"), append a single `## Appendix — Classification`
section after Other gaps with: per-file rows of bucket / class / signals /
informational tags / evidence excerpt. This is the only place
signal codes appear in the document.

---

## Output contract

**Must produce:**
- Single markdown file at workspace root, name
  `workspace-audit-<YYYYMMDD-HHMMSS>.md`. Never overwrite an existing
  audit; the timestamp guarantees uniqueness.
- Structured narrative format per Step 6 — Critical elements tree at the
  top, Summary that absorbs framing, Per-agent recommendations with
  concrete **Add** / **Adjust** / **Trim** bullets, one worked
  before/after example for scope shape, terse Other gaps list. Length
  follows from findings, not a target.
- Every flagged agent prompt has a per-agent recommendation block.
- Each distinct drift gets its own bullet — splits when in doubt.
- For Artisyn SDK workspaces: every rewrite naming a generated artifact
  notes the source-of-truth path and the regenerate command.

**Must NOT:**
- Auto-apply rewrites. User approves each fix manually in a follow-up.
- Print signal codes (`H2`, `GAP-AC`, `FLAG-SCOPE-HEADER`, `INFO-*`,
  `PRACTICE-*`) in the report body. They are internal to the audit's
  reasoning. The recommendation is the deliverable.
- Emit a "Classification table", "Executive Summary" with metric tables,
  "Rewrite proposals" labeled blocks, "What looked right" section, "Fix
  sequence", or "Quality checklist" in the report. These are reasoning
  scaffolding, not output.
- Propose edits to auto-generated files. Only source-of-truth files.
- Flag `Code Navigation Protocol` sections as HOW. Informational only.
- Flag stack/version blocks duplicated across `CLAUDE.md` and per-agent
  prompts. Intentional context-pinning. Only flag value disagreements.
- Flag inline canonical fixtures (e.g. `conftest.py` in `/qa`) as
  duplication. Intentional for human readability.
- Recommend appending `## Corrections` to each `specs/NN-*.md`. See
  "Non-recommendations" below.
- Recommend a "cross-agent lessons" file. Recommend `specs/patterns.md`
  only when the workspace would genuinely benefit (cross-cutting
  invariants exist that are currently re-derived from prose).
- Pad with "no issues found" boilerplate. Drop empty sections.

---

## Non-recommendations

The following used to surface in earlier audit drafts and are **not** to be
proposed automatically — they add noise without an outer process to consume
them. Mention only as optional improvements when the user has the supporting
process in place.

### Per-spec `## Corrections` section
Adding a `## Corrections` section to every `specs/NN-*.md` to capture what
broke and how it was fixed sounds principled but in practice produces
write-only sections that nobody re-reads.

If the user wants a feedback loop, recommend instead:
- A separate retrospective document (e.g., `specs/anti-patterns.md` or a
  sprint-level review doc).
- Populated via a *periodic* process (per sprint / milestone) that distils
  PR comments + review findings into reusable rules.
- Distilled rules are then applied back into agent prompts, scope file
  templates, or `specs/patterns.md` — not stored inline in every scope.

Surface this as a single line in **Optional improvements** if the workspace
shows signs of a review-feedback process (e.g., a PR review template, a
retros folder); otherwise omit entirely.

### Cross-agent "lessons" / `KNOW.md`
Do **not** recommend a free-form lessons-learned file. Recommend
`specs/patterns.md` for cross-cutting invariants only:
- Behaviors that span multiple scope files (keyset pagination, soft-delete
  semantics, httpOnly cookie shape, ban-as-hard-remove, idempotency keys).
- Each entry should be one paragraph, written as a contract, not a story.

If the workspace already encodes invariants inside agent prompts or scope
files, do not propose extracting them — duplication is fine, churn is not.

---

## Quality checklist (internal — run before emitting the report)

These are checks on the audit's reasoning, not items to print:

- [ ] Every agent file, scope file, and task file is classified (no
      silent drops); the classification informs the report even when the
      table is not emitted
- [ ] Every HOW-coded file has a concrete recommendation in the report —
      either named in per-agent bullets, demonstrated in the worked
      example, or listed in Other gaps
- [ ] No recommendation targets an auto-generated file
- [ ] Voice check: report bullets start with action verbs (Add / Adjust /
      Trim / Remove); no signal codes leak into prose
- [ ] Length check: clean workspaces produce shorter reports; busy
      workspaces produce longer reports. Neither padded nor compacted.
- [ ] Filename uses timestamp suffix (`YYYYMMDD-HHMMSS`); existing audit
      not overwritten.
- [ ] Critical-elements tree present and oriented to this audit's
      findings (orphan files, missing scope index entries, etc. called
      out as comments inline).
- [ ] Baseline sanity: running on a known WHAT-focused reference workspace
      produces a short audit with no per-agent recommendations and only
      "Feedback channels" + "Other gaps" populated lightly.

---

## References

- [01-classification-heuristics.md](references/01-classification-heuristics.md) — full WHAT/HOW signal catalog with greppable regexes
- [02-aidlc-templates.md](references/02-aidlc-templates.md) — index of all rewrite templates
  - [templates/agent-prompt.md](references/templates/agent-prompt.md) — WHAT-focused agent prompt shape
  - [templates/scope-file.md](references/templates/scope-file.md) — aidlc scope file with concrete auth example
  - [templates/overview.md](references/templates/overview.md) — execution plan (`specs/00-overview.md`)
  - [templates/changelog.md](references/templates/changelog.md) — scope-level changelog
  - [templates/acceptance-criteria.md](references/templates/acceptance-criteria.md) — behavior-arrow AC block
  - [templates/orchestrator-scope-protocol.md](references/templates/orchestrator-scope-protocol.md) — scope-reading protocol for lead agent
  - [templates/slash-command.md](references/templates/slash-command.md) — role-scoped slash command (optional)
- [03-sample-report.md](references/03-sample-report.md) — worked example audit output
- [04-aila-sdk-constraints.md](references/04-aila-sdk-constraints.md) — guardrails for aila-SDK workspaces
