---
name: author-story
description: |
  Author a single orphan user Story spec from a refined ask — a Story that
  arrived without a parent Epic and therefore did not flow through
  decompose-epic. Instantiates the bundled references/story-template.md, fills it from
  inputs, cites patterns, flags ADR triggers, then chains to estimate-story.
  Returns SP + a draft Story file ready to push to the tracker.
  Implementer-neutral: the Story shape is the same regardless of who ships it.
  Triggers: "author this story", "draft a Story for this ask", "write a Story
  for this tracker mention", "create the spec for this refined inbound",
  "new orphan Story".
license: Proprietary - DataArt Core IP.
metadata:
  category: requirements-management
  level: "200"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-06-02"
  tags: [story-authoring, orphan-story, invest, business-analysis, requirements-management]
---

# Author Story v1.0.0

Produces a single, well-shaped Story spec under `specs/STORIES/` from a refined
inbound ask. Used when the ask is Story-classified (one user-visible change,
fits in < 1 sprint, INVEST-shaped) and has **no parent Epic** — i.e. it did not
arrive through `decompose-epic`.

## When to invoke

- **Orphan Story.** The ask passed Story classification but has no parent Epic.
- **Sub-Story from a SPLIT.** `estimate-story` returned SPLIT and the caller
  wants to instantiate the proposed sub-Stories one at a time.
- **Story migrated from a tracker mention.** A stakeholder created a ticket
  directly; the BA back-fills a spec, then links both ways.

**Do not invoke** for:

- Stories that belong to an Epic — use `decompose-epic` so the Epic's story
  register and decomposition rationale stay correct.
- Bugs — use `author-bug` (different template, no spec file, different chain).
- Initiatives or Epics — use `decompose-initiative` / `decompose-epic`.
- Questions / clarifications — log to the open-questions list. Authoring is for
  units of work, not answers.

This skill does **not** re-classify the inbound. If unsure whether the ask is a
Story, an Epic, or an Initiative, run the classification step first.

## Inputs

- **Inbound ask** — at minimum: the capability requested, the user role asking,
  the observable outcome. If the ask is one sentence, stop and surface the gap.
- **Story template** — `references/story-template.md`, bundled with this skill
  (loaded by this skill; do not author Stories outside it).
- **Project KB** — `FEATURES.md` (feature area), `GLOSSARY.md` (canonical
  terms — the prose must use them), `PROJECT_GOALS.md` (candidate NFRs),
  `INTEGRATIONS.md` (if the Story crosses an external system).
- **Domain KB** — `domain-kb/PATTERNS.md` and any relevant topic file.
- **Existing ADRs + Story register** — `specs/ADRS/` (are the design decisions
  already pinned?) and `specs/STORIES/` (next free `STORY-NNNN`).

## Output

- One draft Story at `specs/STORIES/STORY-NNNN-<slug>.md` from the template,
  with: Title (imperative, business language), Parent epic = orphan disclaimer,
  Statement (`As X, I want Y, so that Z`), Acceptance criteria (3–8 black-box,
  testable behaviours), Capabilities affected (business prose — no module/file
  leaks), Story-specific NFRs, explicit Out-of-scope, Depends-on, Triggers ADR,
  Cites patterns, and an Estimation section filled via `estimate-story`.
- A user-facing report (see below). The Story is `New`, ready to push to the
  tracker.

## Process (follow exactly)

### Step 1 — Verify Story-shape
Confirm: single user-observable change, fits < 1 sprint, INVEST-shaped. If
multi-capability/multi-sprint → `decompose-epic`. If vague/un-Valuable → clarify
with the stakeholder first (log a question).

### Step 2 — Read the supporting KB
Load the feature-area slice of `FEATURES.md`, the relevant `GLOSSARY.md` terms,
the `INTEGRATIONS.md` row for any external system, the pattern catalogue, and
recent accepted ADRs touching the same capability. The point: match the
workspace's vocabulary and reuse existing patterns rather than inventing.

### Step 3 — Allocate the next STORY-NNNN id
Scan `specs/STORIES/`; pick the next 4-digit id; form `STORY-NNNN-<slug>`.

### Step 4 — Draft from the template
Title in business language (no module names / file paths / code terms). Status
`New`. Statement in one sentence. **Acceptance criteria**: 3–8 black-box,
test-assertable behaviours — read each aloud; if you hear an implementation hint
("the API returns …"), rewrite to user-observable shape ("the user sees …").
Capabilities affected in plain prose a non-repo-reader can follow. NFRs only
those that constrain *this* Story. Out-of-scope explicit (a contract, not a
wish-list). Depends-on other Stories / external readiness.

### Step 5 — Cite patterns and flag ADR triggers
Walk `domain-kb/PATTERNS.md` and cite the patterns the implementation will apply
(this is the pattern-reuse hook). Flag decisions needing an ADR before
implementation (first persistence touch, first new-vendor touch, new state
machine, new cross-component contract). List them in `Triggers ADR:`; the lead
authors the ADRs via `author-adr` **before** the implementer branches.

### Step 6 — Lint the spec
Capabilities-affected has no module/file references. AC are black-box (no HTTP
verbs, table names, module boundaries). NFRs are Story-specific. Out-of-scope is
explicit. Fix leaks inline.

### Step 7 — Estimate
Invoke `estimate-story` on the draft. If it returns a number, record the SP and
fill the Estimation section. If it returns **SPLIT** (sum ≥ 23), do **not**
record a number — capture the proposed sub-Stories, stop, and surface to the
caller (who decides whether to accept the split or fold the work into an Epic).

### Step 8 — Surface gaps and tradeoffs
Report ADRs triggered, patterns cited, blocking questions, and dependencies.
The Story is ready to push to the tracker; this skill does **not** push it.

## Output report (to the user)

```
STORY-NNNN drafted — <date>

Source:   <inbound-ask reference>
Spec:     specs/STORIES/STORY-NNNN-<slug>.md
Estimate: <N> SP   (via estimate-story; anchor: <anchor-id>)
Status:   New (ready to create the tracker ticket)

Acceptance criteria: <count> black-box behaviours.
ADRs triggered (write before implementation): ADR-NNNN (<topic>)
Patterns cited: P-NNN <name>
Dependencies:   STORY-MMMM (<why>) | <external readiness>
Open questions (if any): <Q-ID: summary>

Next step: create the tracker ticket, then refine AC with stakeholders.
```

## Variable outputs

- **SPLIT outcome.** The Story stays a draft; the report lists the proposed
  sub-Stories. The caller re-invokes this skill per accepted sub-Story.
- **Blocking question.** The Story may be drafted with a noted blocker; do not
  push to the tracker until it resolves.

## Anti-patterns

- Authoring an orphan Story that is Epic-shaped — if the AC sketch exceeds ~13
  SP, stop; this is `decompose-epic` work.
- Module-shaped titles ("Build the inbox ingestor") — Stories are
  capability-shaped ("Surface new records in triage").
- Implementation-leaked AC ("the endpoint returns 200") — use user-observable
  shape.
- Skipping `estimate-story` — an un-estimated Story cannot be sized or committed.
- Authoring a Bug as a Story — switch to `author-bug`.
- Inventing patterns instead of citing existing ones.

## References

- `references/story-template.md` — the bundled template this skill fills.

**Workspace I/O** (read/written, not bundled with the skill):

- `specs/STORIES/` — where the Story is written.
- `steering-docs/project-kb/{FEATURES,GLOSSARY,INTEGRATIONS}.md` — vocabulary
  and feature map, if present; `steering-docs/domain-kb/PATTERNS.md` — patterns.

**Related skills** (compose loosely; no file dependency): `estimate-story`
(invoked at Step 7), `decompose-epic` (entry point when the inbound has Epic
context), `author-adr` (authors the ADRs flagged in `Triggers ADR:`).
