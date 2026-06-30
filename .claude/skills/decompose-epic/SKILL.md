---
name: decompose-epic
description: |
  Convert an Epic's scope (business outcome + acceptance gates) into a
  sequenced list of INVEST-shaped user Stories with dependencies, ADR
  triggers, and pattern citations. Invokes estimate-story per draft;
  handles SPLIT in the same run.
  Writes Story files under specs/STORIES/ and updates the Epic's
  story register.
  Triggers: "decompose this epic", "break the epic into stories",
  "re-decompose after scope change", "what stories for EPIC-NNNN".
license: Proprietary - DataArt Core IP.
metadata:
  category: requirements-management
  level: "200"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-05-19"
  tags: [decomposition, epic, story-authoring, invest, backlog, business-analysis]
---

# Decompose Epic v1.0.0

Converts an Epic's scope into a sequenced list of well-shaped user
Stories, ready for estimation and dispatch.

## When to invoke

- **Epic start.** The Epic's acceptance gates are stable; no Stories
  exist yet for this Epic. Produces the initial backlog.
- **Scope change.** The Epic's scope grew or shrank; the existing
  Story set needs to reflect the new shape (some Stories merge, others
  split, new ones appear).
- **Lessons learned.** After shipping ≥3 Stories the lead may re-run
  the skill to reassess sequencing — sometimes the dependency order
  reveals a different decomposition than the initial one.

**Do not invoke** for:

- Individual Story refinement (acceptance-criteria tweaks, NFR evolution).
  That's hand-edit work on the Story file, not a decomposition.
- Stories that arrived standalone with no parent Epic. Skip directly to
  `estimate-story` instead.

## Variable entry levels

This skill is the **Epic-level** decomposition step. Two upstream paths
feed into it:

1. **From `decompose-initiative`** — when the inbound work is a vague
   theme that produced 1..N Epics. Each emitted Epic goes through this
   skill in turn.
2. **From the user / lead directly** — when the inbound work is already
   a scoped Epic (a Jira epic, a PRD section, a Confluence feature
   spec). No Initiative-level decomposition needed; start here.

Either way, the input is **a single Epic file** under `specs/EPICS/`.
The output never depends on Initiative context.

## Inputs

- **Epic file**: `specs/EPICS/EPIC-NNNN.md`. The Epic's business
  outcome, scope (acceptance gates), and out-of-scope must be filled.
- **Module dependency order**: the workspace's code KB, typically
  `steering-docs/code-kb/<repo>/MODULES.md`. Constrains Story
  *sequencing*, not Story *boundaries*.
- **Feature map**: `steering-docs/project-kb/FEATURES.md` — groups
  acceptance gates by feature area, useful during clustering.
- **Project goals**: `steering-docs/project-kb/PROJECT_GOALS.md` —
  success criteria here often become NFRs on individual Stories.
- **Existing Stories** (if re-decomposing): everything currently in
  `specs/STORIES/` whose `Parent epic` is this Epic.
- **Patterns + ADRs**: `steering-docs/domain-kb/PATTERNS.md`,
  `steering-docs/project-kb/devops/PATTERNS.md`, `specs/adr/`
  (or wherever the workspace stores ADRs).

## Output

- 1..N draft Story files under `specs/STORIES/STORY-NNNN-<slug>.md`,
  each following `specs/STORIES/0000-template.md`.
- Updated `specs/EPICS/EPIC-NNNN.md`:
  - `Story register` table populated.
  - `Decomposition rationale` paragraph filled.
- A user-facing report (see "Output report" section below).

Every draft Story has:

- Title (imperative, business language; no module / file references).
- Statement (`As X, I want Y, so that Z`).
- Acceptance criteria (3–8 black-box behaviours).
- Capabilities affected (business prose).
- NFRs (only Story-specific ones).
- Out-of-scope.
- Initial estimate via `estimate-story`.
- Dependencies on other Stories.
- ADRs triggered (cross-referenced).
- Patterns cited.

## Process (follow exactly)

### Step 1 — Read the Epic and the supporting KB

1. The Epic file's **Business outcome**, **Scope**, **Out of scope**,
   **NFRs**, **Dependencies** sections. Note every acceptance gate
   verbatim — gates become **traceability targets**.
2. The workspace's code-KB **module dependency order**. Constrains
   sequencing.
3. **FEATURES.md** — helps cluster acceptance gates by feature area.
4. **PROJECT_GOALS.md** success criteria — candidate NFRs on
   individual Stories.

If anything in the Epic's scope is vague (e.g., "User receives a daily
brief" without specifying what's in the brief), **stop and surface the
gap** to the calling agent. Do not decompose around an undefined
acceptance gate.

### Step 2 — Cluster acceptance gates into capabilities

Group the Epic's acceptance gates by **user-observable capability**,
not by module. The rule: two gates belong to the same Story if and only
if their acceptance criteria would be tested in the *same* end-to-end
flow.

The rule is *capability shape*, not gate count. Three gates can be one
Story; one gate can become three Stories.

### Step 3 — Apply shape constraints (INVEST)

Every candidate Story must be:

- **Independent**: ships and tests alone (acknowledging strict
  dependency-ordering — Story-B can depend on Story-A, but Story-A
  doesn't need Story-B to ship).
- **Negotiable**: capabilities can be trimmed at planning without
  invalidating the Story's identity.
- **Valuable**: the user can describe what *they* get out of it without
  saying "infrastructure for X."
- **Estimable**: enough detail in the draft that `estimate-story`
  lands in a real bucket, not SPLIT.
- **Small**: targets the 1–13 SP range. Anything that estimates to 21
  SP must split *here*, not be deferred to estimation.
- **Testable**: the acceptance criteria can be asserted in integration
  tests.

**Foundational infrastructure is a special case.** "Schema baseline +
migrations" doesn't deliver user-observable value alone. Allow *at
most one* foundation Story per Epic, framed in business terms:
"As the user, I want my data to survive restarts and be migratable
under version control, so that I can trust the system to remember
across days." Past that, infrastructure folds into the feature Stories
that need it.

### Step 4 — Identify dependencies

For each candidate Story, list its dependencies on:

1. **Module readiness** — derived from the code-KB dependency order. A
   Story whose primary capability is in module *M* needs *M*'s
   dependencies at `partial` or `implemented`.
2. **Other Stories** in this Epic. Especially: foundation → feature →
   ambient. Foundation Stories unblock the rest.
3. **ADRs**. A Story that *triggers* an ADR must wait for that ADR
   to reach `Accepted`.
4. **Other Epics**. Cross-Epic dependencies belong on the Epic file's
   `Dependencies` section, not the Story.

Dependencies go in the Story's `Depends on:` and `Triggers ADR:`
fields. Reflect them in the Epic's `Story register` table.

### Step 5 — Cite patterns and trigger ADRs

For each draft Story, walk through the workspace's pattern catalogues
(`domain-kb/PATTERNS.md`, `project-kb/devops/PATTERNS.md`). Cite the
patterns the implementation will apply (`P-NNN` / `DP-NNN`). This is
the *planning-stage* hook for pattern reuse — saves the dev from
rediscovering them.

Identify decisions that need an ADR before implementation. Common
triggers:

| Story-shape | ADR likely needed |
|---|---|
| First touch on persistence | ADR for engine flavour, schema baseline. |
| First touch on a new vendor | ADR for auth flow, scope, error model. |
| First touch on a classifier / LLM call | ADR for model + prompt envelope. |
| First touch on a state machine | ADR for states + transitions + invariants. |

List triggered ADRs in the Story file. The lead writes the actual ADRs
*before* the dev branches.

### Step 6 — Draft each Story from the template

For each candidate, instantiate `specs/STORIES/0000-template.md`. Fill
in:

- Title, Parent Epic, Parent Initiative (if any), Status (= `Backlog`).
- Statement (`As X, I want Y, so that Z`) — business language only.
- Acceptance criteria — black-box, testable, mapped back to the Epic's
  acceptance gates.
- Capabilities affected — plain prose. **Read this section out loud
  to yourself.** If you hear a module name, file path, or code term,
  rewrite it.
- NFRs — only the ones that constrain *this* Story. Drop generic ones.
- Out-of-scope — explicit, especially when a related capability lives in
  another Story.
- Depends on — populated from Step 4.
- Triggers ADR — populated from Step 5.
- Cites patterns — populated from Step 5.

### Step 7 — Estimate each Story

Invoke `estimate-story` on each draft. Use its output to:

- Populate the Story's Estimation section.
- Identify SPLIT outcomes — split the Story now (Step 7a) before
  registering.

### Step 7a — Handle SPLITs

If `estimate-story` returned SPLIT for a Story, decompose it into 2–3
sub-Stories in this same skill run. Re-draft (Step 6), re-estimate
(Step 7). Repeat until all candidate Stories estimate at 1–13 SP.

### Step 8 — Update the Epic's Story register

Append a row per Story to the parent Epic's `Story register` table:

| ID | Title | Status | SP | Depends on | Triggers ADR | Cites |

Sort the table by **intended sequence** (foundation → modules in
dependency order → ambient). This is the working backlog for this
Epic.

Add `Sequencing notes` to the Epic file if anything non-obvious — e.g.,
"STORY-0007 depends on ADR-0004 being Accepted, which the lead should
author *before* opening STORY-0007's task brief."

Write the **Decomposition rationale** paragraph on the Epic file: why
this set of Stories, what groupings were considered and rejected, what
dependencies forced the slicing.

### Step 9 — Surface gaps and tradeoffs

In your reply (the user-facing report), explicitly call out:

- Acceptance gates from the Epic that *no Story covers*. These are
  scope gaps — either the Epic needs to be updated or a missing Story
  needs to be added.
- Stories that are technically in-scope but realistically should be
  deferred (because their dependencies aren't ready).
- ADR-gated Stories — what work *cannot start* until the lead authors
  the ADR.
- Implementer-neutral note: every Story is shaped to be implementable
  agentically *or* by a human. The estimate is intrinsic;
  cost-tracking records the actuals.

## Output report (to the user)

```
EPIC-NNNN decomposition — <date>

Source: specs/EPICS/EPIC-NNNN.md
Stories created: <N> (in specs/STORIES/)
Estimated total SP: <sum>

Backlog order (by dependency):
  1. STORY-NNNN — <title> — <SP> SP
  2. STORY-NNNN — <title> — <SP> SP
  …

ADRs triggered (write before dependent Stories start):
  - ADR-NNNN (<topic>) — triggered by STORY-NNNN
  …

Epic acceptance gates without coverage:
  - <gate>: needs STORY-NNNN, drafting…
  - <gate>: out of scope for this Epic, defer

Sequencing notes:
  - …

Next step: review the drafts, confirm the sequencing, approve the ADRs
that gate the early Stories.
```

## Anti-patterns

- ❌ One Story per acceptance gate. Acceptance gates are *requirements*,
  not *stories*. A Story often satisfies multiple gates.
- ❌ Stories named after modules ("Build the `inbox` module"). Stories
  are named after capabilities ("Surface new emails as triage
  candidates").
- ❌ Foundation Stories that are >1 in an Epic. If the work feels like
  three foundation Stories, fold two of them into the feature Stories
  that need the foundation.
- ❌ Skipping estimation. A Story in the register without an SP is
  half-baked.
- ❌ Quietly creating Stories larger than 13 SP. Always SPLIT before
  registering.
- ❌ Story prose that leaks code-shape. "The InboxItem table gains a
  routed_to_project_id column" is not a Story; "Emails surface with a
  project assignment proposed" is.
- ❌ Decomposing without reading the Epic's `Out of scope`. Re-deriving
  the boundary wastes the Epic author's work and risks scope creep.

## References

- `specs/STORIES/0000-template.md` — Story template.
- `specs/EPICS/0000-template.md` — Epic template (where the
  Story register lives).
- `.claude/skills/estimate-story/SKILL.md` — invoked per Story.
- `.claude/skills/decompose-initiative/SKILL.md` — upstream skill
  when starting from an Initiative.
- `steering-docs/code-kb/<repo>/MODULES.md` — module dependency
  order constraint.
- `steering-docs/project-kb/FEATURES.md` — feature map for clustering.
- `steering-docs/project-kb/PROJECT_GOALS.md` — success criteria,
  candidate NFRs.
- `steering-docs/domain-kb/PATTERNS.md` and
  `steering-docs/project-kb/devops/PATTERNS.md` — pattern catalogues.
