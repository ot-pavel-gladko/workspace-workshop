# Sample Audit Report

Worked example showing the expected report shape. The audit writes this
file to `workspace-audit-<YYYYMMDD-HHMMSS>.md` at workspace root —
timestamp guarantees same-day reruns do not collide.

The sample below is what a real audit looks like — structured narrative,
voice-first, length determined by findings. Signal codes (`H2`, `GAP-*`,
`INFO-*`, `PRACTICE-*`) do **not** appear in the report; they are
internal reasoning only. The recommendation is the deliverable.

---

# Workspace Audit — `example-workspace`

**Date:** 2026-04-25 17:42
**Workspace type:** Artisyn SDK
**Scope:** 8 agents · 2 skills · 6 steering-docs KBs · 1 monolithic
requirements doc · 2 ad-hoc task files

### Critical elements

```text
example-workspace/
├── prompts/                                   # 8 agent source prompts
│   ├── lead.md                                # orchestrator (flagged)
│   ├── ba.md, domain-expert.md, …
│   └── qa.md
├── workspace.py                               # Artisyn SDK declarative def
├── steering-docs/
│   ├── project-kb/                            # 6 KB files (strong asset)
│   │   ├── REQUIREMENTS.md                    # ~30 stories, no header blocks
│   │   ├── DOMAINS.md, FEATURES.md, GLOSSARY.md
│   │   └── PROJECT_GOALS.md                   # business stages only, no execution plan
│   ├── qa/scenarios/                          # 2 of ~30 stories covered
│   └── aila-code-doc/<repo>/*/PATTERNS.md     # declared, status unverified
├── tasks/
│   ├── TASK-myproj-catalog-command.md         # behaviour-style story (clean)
│   └── myproj-prefix-analysis.md            # find-and-replace plan (flagged)
├── CLAUDE.md                                  # auto-generated
└── .claude/                                   # auto-generated
    ├── agents/*.md
    └── rules/*.md
```

---

## Summary

This workspace ships a strong steering-docs corpus and well-scoped agent
prompts. The drift to fix is concentrated in two places: the lead
agent's delegation flow (it does not read story scope before
sub-tasking) and the `tasks/` folder, which mixes one behaviour-style
story with one find-and-replace change plan masquerading as a task.
Audit ran in iterative mode — there is no execution plan and no
locked phase set.

8 agents, 1 flagged · 2 ad-hoc task files, 1 flagged · `REQUIREMENTS.md`
is the implicit scope file, no `specs/` directory · no execution plan ·
no shipped-scope changelog.

- **No story-level scope contract between BA output and code agents.**
  `REQUIREMENTS.md` carries acceptance criteria per story but has no
  per-story `Components / Depends on` header, so `myproj-lead` re-routes
  every story by reading `DOMAINS.md` instead of a one-line declaration
  of what the story touches.
- **Only 2 of ~30 stories have a QA scenario file.** The other 28 live
  as Jira tickets with no behaviour-as-data record. Either commit to
  the format (and backfill) or retire it; the current state reads as
  an abandoned experiment.
- **No execution plan.** `PROJECT_GOALS.md` describes business stages
  but nothing maps story IDs to agents, sequence, or done-state.
- **No shipped-scope changelog.** `git log` is the only record of what
  shipped. A `specs/CHANGELOG.md` with one entry per STORY-* story as it
  ships would close the cold-read gap.
- **`tasks/myproj-prefix-analysis.md` is a diff disguised as a task.**
  File paths and line numbers in the body, no acceptance criteria, no
  agent assignment.

---

## Per-agent recommendations

### `myproj-lead` (`prompts/myproj-lead.md`, 92 lines)

`myproj-lead`'s `$ARGUMENTS` carries a Jira ticket ID, a story ID
(`STORY-NN`), or a free-form implementation request. The recommendations
below assume that flexibility — they do not collapse the agent into
"always read `specs/NN-*.md`".

- **Add** a step before sub-task creation that branches on the input
  form:

  ```
  Read story scope:
  - If $ARGUMENTS is an STORY-* / TASK-NN ref → quote the story's
    Acceptance Criteria and Business Rules from
    steering-docs/project-kb/REQUIREMENTS.md into the sub-task body.
  - If a matching scenario exists at
    steering-docs/qa/scenarios/<story>-*.json → link it.
  - If $ARGUMENTS is a Jira link → fetch (or ask the user for) the
    description first; do not sub-task from the title alone.
  - If $ARGUMENTS is a free-form description → proceed with the body
    as the de-facto scope.
  ```

- **Trim** step 2 (Jira fetch) — `jira_get_issue` is not a tool the
  lead has wired. Either configure the MCP or replace with: "ask the
  user for the Jira description if not in `tasks/`".

**How to apply:** edit `prompts/myproj-lead.md`, then run
`python3 workspace.py generate --agent claude`. Do NOT edit
`.claude/agents/myproj-lead.md` directly.

---

## Ticket / scope organization

The agent-ready scope files (`tasks/TASK-myproj-catalog-command.md`)
follow the right shape — header block, problem statement, acceptance
criteria. The outlier worth reshaping is
`tasks/myproj-prefix-analysis.md`:

Current shape:

```
## Planned Changes

### Production code (3 files)
1. GroupCodeVerificationService.java:33 — "5.GROUP-" → ".GROUP-"
2. AfterHoursGenerator.java:31 — "<legacy-prefix-format>" → "<new-format>"
3. SuccessfullyQueuedParser.java:14-15 — "5H-SUCCESSFULLY QUEUED (.*)" → "H-SUCCESSFULLY QUEUED (.*)"
```

This is a diff disguised as a task: file paths, line numbers, exact
strings. No AC, no agent assignment. Recommended shape (drop into
`tasks/TASK-remark-5-prefix.md`):

```
**Components:** `backend` (primary fix), `domain` (verification)
**Depends on:** —

## Problem
Three call sites embed the vendor command prefix `5` in event-content
constants, parsers, and tests. Generators and parsers are internally
consistent so the bug is invisible in production.

## Acceptance Criteria
- [ ] Group code verification accepts `.GROUP-<brand>` from vendor
      without a fallback branch
- [ ] After-hours queued event round-trips as `<event-msg>`
      through both generator and parser
- [ ] `FeatureServiceTest` routes `.CODE-A-` and `Y/-CODE/` without the
      `5` prefix
- [ ] `mvn -pl :example-backend test -Dtest="FeatureServiceTest,VerificationServiceTest,GeneratorTest"` passes
```

The exact file/line table stays in the PR description, not the task.
Note: the header has no `Phase:` (this is a hygiene fix, not a phased
deliverable) and no `Parallel with:` — `/lead` decides parallelism at
execution time based on worktree load.

---

## Feedback channels & shared state

- **`steering-docs/project-kb/`** — exists, comprehensive. Feeds BA +
  domain-expert + all code agents. The workspace's strongest asset.
- **`steering-docs/aila-code-doc/<repo>/*/PATTERNS.md`** — declared,
  status unverified. Every code-agent prompt names this file as the
  place to record non-obvious scan results. Worth checking whether any
  agent has actually written to them; if empty across the board after
  several weeks, the protocol isn't firing and should be simplified or
  removed.
- **`steering-docs/qa/scenarios/`** — 2 of ~30 stories covered. Either
  commit to the format (and backfill) or retire it; the current state
  reads as an abandoned experiment.
- **Changelog of shipped scope — missing.** Add `specs/CHANGELOG.md`
  with an `## Unreleased` section and one entry per STORY-* story as it
  ships, referencing the story ID and primary agent.
- **Execution plan — missing.** `REQUIREMENTS.md` § Development Stages
  lists Stage 0–6 by epic but nothing maps the ~30 stories to agents
  or to a sequence the lead can walk. A `specs/00-overview.md` with an
  agent-assignment matrix would close this gap.

---

## Other gaps

- `REQUIREMENTS.md` stories lack a per-story header block (Components /
  Depends on) — add one inline per story.
- `tasks/TASK-myproj-catalog-command.md` Technical Notes section leaks
  file paths into the task body — move to PR description.
- `prompts/myproj-lead.md` references `jira_get_issue` but no MCP config
  for Jira is visible in `.mcp.json`; confirm or remove.
- `myproj-qa` tech stack section says "Tests: `e2e/` or `tests/`" — pick
  one and document the actual location.
- `catalog-schema.md` and `sdk-skill.md` prompts are ~12 lines each;
  fine as stubs, but consider merging into one SDK-utility agent if
  neither is used.

---

## Format notes (not part of the report)

The sample above shows the target voice and density. When generating a
report:

- The **Critical elements tree** is the structural orientation device.
  Use it to call out orphans, missing index entries, or auto-generated
  artifacts inline as `# comment`s.
- **Workspace type** is binary: `Artisyn SDK` or `Not Artisyn SDK`. The
  detail follows from the tag, not from prose.
- **Scope** is a short categorized count (agents · skills · commands ·
  scope files · …). Add categories the workspace has, omit the rest.
- **Summary** absorbs all framing — workspace character, audit mode,
  headline drift. Do not duplicate this in a separate intro paragraph.
- One distinct drift per Summary bullet. Do not merge "TASK-14 missing
  header AND TASK-15 has line numbers" into one bullet.
- Per-agent bullets start with **Add** / **Adjust** / **Trim** / **Remove**.
- For Artisyn SDK workspaces, the per-rewrite "How to apply" line names
  the source-of-truth path and the regenerate command.
- A clean WHAT-focused workspace produces a short audit with empty
  per-agent and ticket-organization sections — that is the right
  output, not a five-page report padded with positive findings.
