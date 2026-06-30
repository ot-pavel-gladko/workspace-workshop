---
name: author-adr
description: |
  Author a single Architecture Decision Record under specs/ADRS/ from a
  trigger — typically a Story's "Triggers ADR: ADR-NNNN" field surfaced by
  decompose-epic, but also a direct lead-initiated decision that must be
  pinned before implementation can start.
  Instantiates the bundled references/adr-template.md, fills Context / Decision /
  Consequences / Alternatives from the lead's input, resolves linked open
  questions, updates the spec register, and emits a draft in Proposed
  status. Human review flips Status to Accepted; the skill never accepts
  on its own.
  Triggers: "author ADR-NNNN", "draft ADR for <decision>", "write the ADR
  that gates STORY-NNNN", "supersede ADR-NNNN", "pin the decision for <topic>".
license: Proprietary - DataArt Core IP.
metadata:
  category: architecture-management
  level: "200"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-06-02"
  tags: [adr, architecture-decision-record, lead, gating-decision, requirements-management]
---

# Author ADR v1.0.0

Produces a single, well-shaped ADR file under `specs/ADRS/` from a triggering
Story / Epic (or a direct lead-initiated need). Used when an architecture
decision must be pinned **before** implementation can start — the ADR gates
whichever Stories carry it in their `Triggers ADR:` field.

This is the ADR-authoring follow-up in the `lead-orchestration` flow.

## When to invoke

- **Story trigger.** `decompose-epic` (or `author-story`) emitted a Story with
  `Triggers ADR: ADR-NNNN`. The lead reads the Story, picks up the trigger, and
  runs this skill to author the ADR before dispatching the implementer.
- **Lead-initiated decision.** Review surfaces an unrecorded architecture
  choice (cross-cutting contract, vendor selection, state machine). The lead
  pins it via this skill **before** approving the merge.
- **Supersession.** A later decision invalidates a prior ADR. The lead authors
  the successor, then updates both files' `Supersedes:` / `Superseded by:`
  headers and the register row.

**Do not invoke** for:

- Stories — use `author-story` or `decompose-epic`. ADRs gate Stories; they are
  not Stories.
- Open questions — log them to the workspace's open-questions list. A question
  is resolved either inside an ADR (when the answer is an architecture choice)
  or by stakeholder discussion (when the answer is a fact).
- Documentation of already-in-force, ungated decisions — write those into the
  relevant `steering-docs/` page. ADRs are for decisions whose acceptance
  unblocks downstream work.

## Inputs

- **Trigger** — a Story file with the `Triggers ADR` field, an Epic whose
  dependencies list this ADR, a direct lead ask, or a predecessor ADR being
  superseded.
- **ADR template** — `references/adr-template.md`, bundled with this skill
  (loaded by this skill; do not author ADRs outside the template).
- **The lead's decision substance** — what the chosen approach is, why it beat
  the alternatives, and the consequences. The skill **structures** the lead's
  input; it does not invent the decision.
- **Project / domain KB** — `steering-docs/project-kb/` (integrations,
  constraints/NFRs) and `steering-docs/domain-kb/PATTERNS.md` (patterns to cite).
- **Open questions** — for each question linked to the trigger, the ADR either
  resolves it or explicitly defers it.
- **Existing ADRs + register** — `specs/ADRS/` and `specs/REGISTER.md` for prior
  decisions, supersession candidates, and the next free ID.

## Output

- One draft ADR at `specs/ADRS/ADR-NNNN-<slug>.md`, instantiated from the
  template, with: Title (imperative), Status = `Proposed`, triggering spec,
  Supersedes/Superseded-by (if applicable), Context, Decision drivers, Decision
  (one imperative paragraph), Consequences (positive/negative/neutral),
  Alternatives considered (≥1 row), open questions resolved/deferred, References.
- Updated `specs/REGISTER.md` ADR row.
- A user-facing report (see below). The ADR is in `Proposed` state, ready for
  human review; review flips it to `Accepted`.

## Process (follow exactly)

### Step 1 — Read the trigger and lock the scope
One decision per ADR. If the trigger implies two separable decisions, pause and
ask whether they should be two ADRs. Confirm the decision is a genuine
architecture choice (cross-cutting, hard to reverse, gates downstream work) and
is **not already recorded** — search `specs/ADRS/` first; an existing Accepted
ADR on the topic means supersession, not a duplicate.

### Step 2 — Allocate or confirm the ADR number
Use the ID named in the trigger's `Triggers ADR:` field if present; otherwise
allocate the next free four-digit ID and add the register row. Form the slug
`ADR-NNNN-<kebab-slug>` from the Title.

### Step 3 — Read the supporting KB
Load the relevant project-kb (integrations, goals) and `domain-kb/PATTERNS.md`
plus prior ADRs on the same area. The point: match workspace vocabulary, cite
existing patterns rather than inventing, reuse prior decisions rather than
re-litigating.

### Step 4 — Resolve linked open questions
For each linked question: record the answer (resolved), apply a documented
default if the stakeholder is unreachable (note it as a provisional default), or
**stop** if it is genuinely blocking and has no defensible default — surface the
gap with what stakeholder decision is needed.

### Step 5 — Draft the ADR from the template
Fill Title (imperative, specific), Status `Proposed`, Context, Decision drivers
(3–6 constraining bullets — drop any that exclude no alternative), Decision (one
imperative paragraph — "We will …", specific; no "we will consider"),
Consequences (include **negatives** — every decision has costs), Alternatives
(≥1 row with a specific rejection reason), questions resolved/deferred,
References. Keep the body ASCII-only.

### Step 6 — Lint the draft
Decision is a commitment, not a deliberation. Alternatives are recorded, not
hand-waved. Consequences include negatives. Drivers are constraining. Fix any
softness inline.

### Step 7 — Update the register and verify cross-links
Edit the `specs/REGISTER.md` ADR row (Title, Status `Proposed`, Gates). Walk the
back-links: the triggering Story's `Triggers ADR:` cites this ID; the Epic's
dependencies list it with required state `Accepted`. On supersession, update the
predecessor's `Superseded by:` header and register status. **Do not silently
edit Story/Epic files** — flag drift in the report.

### Step 8 — Surface gaps and tradeoffs
In the report, call out: Status is `Proposed` (gated Stories cannot start until
Accepted), questions resolved/deferred, spec drift detected, and any pending
downstream sync (e.g. a separate Confluence-publishing skill on the Accepted flip).

## Output report (to the user)

```
ADR-NNNN drafted — <date>

Trigger:  <STORY-NNNN | EPIC-NNNN | lead-initiated>
Spec:     specs/ADRS/ADR-NNNN-<slug>.md
Status:   Proposed (review and flip to Accepted to unblock gated work)

Title:    <one-line title>
Decision: <one imperative sentence>

Open questions resolved:  <Q-ID: answer>  /  deferred: <Q-ID: target>
Spec drift detected:      (none) | <what needs reconciling>
Gates:                    STORY-NNNN — cannot start until this ADR is Accepted

Next step: review the draft and flip to Accepted to unblock the gated Stories.
```

## Variable outputs

- **Supersession.** Report adds a "Supersedes ADR-NNNN" line; predecessor's
  register row flips to `Superseded` and its header gains `Superseded by:`.
- **Blocking question.** If Step 4 finds an unanswerable, default-less question,
  the skill **stops** without authoring and names the blocker.
- **Duplicate detection.** If Step 1 finds an Accepted ADR on the same topic,
  the skill **stops** and asks whether this is a supersession.

## Anti-patterns

- Authoring an ADR for an implementation preference (style, naming, tooling) —
  those go in `steering-docs/`.
- Multi-decision ADRs — if you cannot summarise the Decision in one paragraph,
  split it.
- Skipping Alternatives — recording ≥1 rejected option is what makes the ADR
  useful in six months.
- Empty Consequences.Negative — every decision has costs.
- Authoring in `Accepted` status — the skill always emits `Proposed`; human
  review is the governance gate.
- Silent spec edits — flag drift; do not auto-fix Story/Epic files.
- Authoring an ADR for a question — questions go to the open-questions log first.

## References

- `references/adr-template.md` — the bundled template this skill fills.

**Workspace I/O** (read/written, not bundled with the skill):

- `specs/ADRS/` — where the ADR is written; `specs/REGISTER.md` — the cross-spec
  index this skill updates.
- `steering-docs/domain-kb/PATTERNS.md` — pattern catalogue to cite, if present.

**Related skills** (compose loosely; no file dependency): `lead-orchestration`
(upstream flow), `decompose-epic` (emits Stories with `Triggers ADR:`),
`author-story` (orphan-Story authoring).
