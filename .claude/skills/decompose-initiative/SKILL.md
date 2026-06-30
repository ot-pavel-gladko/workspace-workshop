---
name: decompose-initiative
description: |
  Convert an Initiative (release-sized or quarter-sized strategic
  container) into 1..N Epics, each with a business outcome statement,
  scope, out-of-scope contract, and dependency notes.
  Skip this skill when the inbound work is already a scoped feature
  (Jira epic, PRD section, Confluence feature spec) — go directly to
  decompose-epic.
  Triggers: "decompose this initiative", "break this theme into epics",
  "what are the epics for this quarter".
license: Proprietary - DataArt Core IP.
metadata:
  category: requirements-management
  level: "200"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-05-19"
  tags: [decomposition, initiative, epic-authoring, strategic-planning, business-analysis]
---

# Decompose Initiative v1.0.0

Converts an Initiative — a vague theme, a quarter target, a strategic
ask — into a sequenced list of Epic drafts, each ready for
`decompose-epic` to break into Stories.

## When to invoke

- **The inbound work is a theme**, not a scoped feature.
  Examples: "rework onboarding", "make memory work", "ship the
  document-ingest delivery for v1.A".
- **The inbound work is a quarter-sized commitment** that needs
  splitting into ship-able Epics.
- **A new Initiative file landed** with `Status: Proposed` and no
  Decomposition table filled.

**Do not invoke** for:

- A single Jira epic or Confluence feature spec. Those *are* the Epic.
  Skip to `decompose-epic`.
- A single Story or Jira ticket. Skip both decomposition skills; go
  directly to `estimate-story`.
- Refinement of an existing Initiative's Epic list. That's hand-edit
  work on the Initiative file, not a re-decomposition (unless the
  strategic outcome itself changed).

## Variable entry levels

The Initiative → Epic → Story hierarchy is **optional**. Only invoke
this skill when the input genuinely needs Initiative-level shaping.
Most inbound work to a BA agent skips this step:

| Inbound | Entry level | Skill invoked |
|---|---|---|
| Vague theme: "rework auth" | Initiative | `decompose-initiative` (this skill) → `decompose-epic` → `estimate-story` |
| Jira epic / scoped feature | Epic | `decompose-epic` → `estimate-story` |
| Single Jira story / file / sentence | Story | `estimate-story` directly |

When in doubt, ask the user: *"Is this a single feature (jump to Epic
decomposition) or a multi-feature initiative (start here)?"*

## Inputs

- **Initiative file**: `specs/INITIATIVES/INI-NNNN.md`. The
  Initiative's `Why this initiative exists`, `Strategic outcome`,
  `Constraints`, and `In scope / out of scope` sections must be
  filled.
- **Project goals**: `steering-docs/project-kb/PROJECT_GOALS.md` —
  the Initiative must serve at least one stated goal.
- **Feature map**: `steering-docs/project-kb/FEATURES.md` — existing
  feature areas that the Initiative will create Epics within or beside.
- **Existing Initiatives & Epics**: `specs/REGISTER.md` plus the
  files under `specs/INITIATIVES/` and `specs/EPICS/`. Avoid
  reinventing an Epic that already exists.

## Output

- 1..N draft Epic files under `specs/EPICS/EPIC-NNNN-<slug>.md`,
  each following `specs/EPICS/0000-template.md`.
- Updated `specs/INITIATIVES/INI-NNNN.md`:
  - `Decomposition` table populated with the Epic IDs.
  - `Decomposition rationale` paragraph filled.
- Updated `specs/REGISTER.md` — Initiative and Epics added/updated.
- User-facing report (see "Output report" section).

Every draft Epic has:

- Title (imperative, business language).
- Status (= `Backlog`).
- Parent Initiative (this one).
- Business outcome (one paragraph in user / operator language).
- Scope — the acceptance gates the Epic owns.
- Out of scope — explicit deferrals.
- Dependencies — on other Epics, ADRs, externals.
- NFRs at the Epic level (not Story-specific ones).
- Empty Story register (`decompose-epic` fills it later).

## Process (follow exactly)

### Step 1 — Read the Initiative and the supporting KB

1. The Initiative file in full — `Why this initiative exists`,
   `Strategic outcome`, `Constraints`, `In scope / out of scope`,
   `Open questions`.
2. `PROJECT_GOALS.md` — confirm the Initiative serves a stated goal.
   If it doesn't, flag it to the user before decomposing.
3. `FEATURES.md` — locate where the Initiative's Epics will sit in
   the feature map. Are they extensions of existing feature areas, or
   a new feature area?
4. `specs/REGISTER.md` and existing Epic files — avoid duplication.
   If an Epic already covers part of this Initiative's scope, the
   right move is to *re-parent* that Epic to this Initiative, not to
   draft a new one.

### Step 2 — Cluster the Initiative's scope into Epics

Group the Initiative's in-scope capability areas by **shipping
boundary**: two capabilities belong to the same Epic if and only if
they sensibly *ship together as one named release of business value*.

Different from `decompose-epic`'s clustering rule — at the Initiative
level, the question is *"what's a coherent thing to release?"*, not
*"what's a coherent Story?"*. An Epic can span weeks of work.

Heuristics:

- **One business outcome per Epic.** If you find yourself writing
  "this Epic ships A *and* B", and A and B serve different outcomes,
  that's two Epics.
- **Vendor / system boundaries.** A capability that crosses one new
  vendor surface is typically its own Epic — the vendor is the natural
  shipping unit.
- **Operator-visible vs internal-only.** Infrastructure that supports
  multiple user-visible features is often its own Epic (a foundation
  Epic), shipped before the consumer Epics.
- **Reversibility.** An Epic whose decisions are hard to revert
  (schema baselines, vendor lock-in, embedding-model choice) deserves
  its own ship boundary so the calibration is recorded.

### Step 3 — Shape each Epic

For each cluster, draft an Epic by instantiating
`specs/EPICS/0000-template.md`. Fill:

- **Business outcome** — one short paragraph. What changes for the
  user / business / operator once every Story in this Epic ships.
- **Scope** — the acceptance gates the Epic owns. **3–8 gates** is the
  sweet spot. <3 → probably should be a Story instead. >8 → probably
  two Epics.
- **Out of scope** — explicit deferrals. Critical: name *where each
  deferred capability lives instead* (another Epic? a future
  Initiative? not in plan?).
- **Dependencies** — on other Epics (in this Initiative or others), on
  ADRs, on externals (vendor approval, infra readiness, contract).
- **NFRs at the Epic level** — constraints that apply to *every*
  Story in this Epic. Story-specific NFRs come later.

### Step 4 — Sequence the Epics

In the parent Initiative's `Decomposition` table, sort the Epics by
**intended delivery order**. The constraints:

1. **Hard dependencies first.** Foundation Epics ship before consumer
   Epics. ADR-gated Epics ship after the ADR is `Accepted`.
2. **De-risk early.** Epics with high `Uncertainty` (in the Story
   rubric's sense — research-heavy, vendor-new) earlier rather than
   later, so the calibration data lands before downstream commitments.
3. **Strategic outcome alignment.** Epics that the Initiative's
   `Strategic outcome` sentence depends on most ship first.

Add a brief `Sequencing notes` paragraph on the Initiative file when
anything is non-obvious.

### Step 5 — Identify cross-Epic / cross-Initiative dependencies

For each draft Epic, list the Epics it depends on:

- Within this Initiative — populate the Epic's `Dependencies` table.
- In other Initiatives — same; this is how the cross-Initiative
  dependency graph emerges.
- On ADRs — same.
- On externals — same.

### Step 6 — Surface gaps and tradeoffs

In your reply, explicitly call out:

- **Scope from the Initiative that no Epic covers.** Either the
  Initiative's `In scope` needs to be updated or a missing Epic needs
  to be added.
- **Epics that probably shouldn't ship this Initiative** (because their
  dependencies aren't ready or their outcomes belong to a future
  Initiative).
- **ADR-gated Epics** — what work *cannot start* until the lead
  authors the ADR.
- **Open questions** unresolved at decomposition time. These block the
  next phase (`decompose-epic`) on the affected Epic.

### Step 7 — Write the rationale

On the Initiative file's `Decomposition rationale` paragraph, cover:

- Why this set of Epics, not a different set.
- What groupings were considered and rejected.
- What dependencies forced the slicing.
- What unknowns dominated.

This is the artefact you re-read when revisiting the Initiative's
shape later.

## Output report (to the user)

```
Initiative INI-NNNN decomposition — <date>

Source: specs/INITIATIVES/INI-NNNN.md
Epics created: <N> (in specs/EPICS/)

Epics in delivery order:
  1. EPIC-NNNN — <title>  (depends on: —, ADRs: —)
  2. EPIC-NNNN — <title>  (depends on: EPIC-MMMM, ADRs: ADR-XXXX)
  …

ADRs to author (gate the early Epics):
  - ADR-XXXX (<topic>) — triggered by EPIC-NNNN
  …

Initiative scope without Epic coverage:
  - <area>: needs EPIC-NNNN, drafting…
  - <area>: defer to a future Initiative

Open questions blocking next steps:
  - <question> — needs answer from <stakeholder>

Next step: review the Epic drafts, confirm the sequencing, ask the lead
to author the gating ADRs before invoking decompose-epic on EPIC-NNNN.
```

## Anti-patterns

- ❌ Decomposing every inbound request into Epics. A single Jira ticket
  is a Story, not an Initiative.
- ❌ Epics with no clear business outcome. "Foundation work" is not an
  outcome; "the system can persist user data across restarts" is.
- ❌ Epics that span multiple vendors with no reason. Vendor crossings
  are natural shipping boundaries.
- ❌ Re-creating Epics that already exist under another Initiative.
  Re-parent instead.
- ❌ Sequencing by "easy first" rather than dependency-and-risk first.
  De-risking high-uncertainty Epics early protects the rest of the
  Initiative.

## References

- `specs/INITIATIVES/0000-template.md` — Initiative template.
- `specs/EPICS/0000-template.md` — Epic template (the output shape).
- `.claude/skills/decompose-epic/SKILL.md` — downstream skill on each
  emitted Epic.
- `steering-docs/project-kb/PROJECT_GOALS.md` — the goals the
  Initiative must serve.
- `steering-docs/project-kb/FEATURES.md` — feature map.
- `specs/REGISTER.md` — cross-level index.
