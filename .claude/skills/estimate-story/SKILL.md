---
name: estimate-story
description: |
  Score a user story against a fixed 5-dimension rubric and map the sum
  to a Fibonacci story-point bucket. Implementer-neutral: measures
  intrinsic complexity, not author-specific effort, so agentic and
  human cost-per-SP are comparable.
  Outputs SP + per-dimension scores + nearest anchor + rationale.
  Returns SPLIT when sum >= 23.
  Triggers: "estimate this story", "score the story", "what's the SP",
  "re-estimate after scope change".
license: Proprietary - DataArt Core IP.
metadata:
  category: requirements-management
  level: "200"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-05-19"
  tags: [estimation, story-points, fibonacci, rubric, calibration, business-analysis]
---

# Estimate Story v1.0.0

Produces a **Fibonacci story-point estimate** for a single user story by
scoring it against a fixed five-dimension rubric and comparing it to a
per-workspace calibration anchor set.

## When to invoke

- A new Story is drafted and needs an initial estimate.
- A Story's scope changed (acceptance criteria added/removed; out-of-scope
  shrank) — re-estimate.
- Comparing implementers (agentic vs human) on the same yardstick.
- After implementation: comparing felt complexity against the estimated
  one, to surface anchor-update candidates.

**Do not invoke** for:

- ADR decisions (ADRs aren't sized in SP).
- Conversation-scoped sub-tasks (use `TaskCreate` instead).
- Initiatives or Epics (they aggregate Story SP; they don't have their
  own SP).

## Why this rubric is implementer-neutral

The five dimensions measure **intrinsic complexity** of the Story —
scope, module-touch breadth, schema impact, uncertainty, integration
risk. None of them ask "how long does Claude take" or "how many lines
of code." This is deliberate: cost-per-SP must be comparable across
implementers for the agentic-vs-human analysis to be meaningful.

Implementation cost (tokens, hours, dollars) is a *separate*,
post-delivery field in the Story file — see the Story template's
`Implementation cost` section.

## Inputs

- **Story file** (or draft text) — at minimum: title, statement,
  acceptance criteria, capabilities affected, NFRs, out-of-scope.
- **Rubric** — `references/rubric.md` (loaded by this skill).
- **Anchor set** — per-workspace at `specs/estimation-anchors.md`. The
  workspace authors and maintains this file; the skill never edits it.
- **Optional**: prior estimates for related Stories (to maintain
  consistency).

## Output

Update the Story file's **Estimation** section:

```markdown
## Estimation

| Dimension | Score | Note |
|---|---|---|
| Scope | 2 | One new user-observable capability. |
| Module-touch breadth | 3 | Touches db + projects + activity. |
| Schema / contract impact | 4 | New tables; first migration after baseline. |
| Uncertainty | 2 | Patterns exist (P-002, P-004); no new research. |
| Integration risk | 1 | Internal-only; no vendor crossing. |
| **Sum** | **12** | → bucket 11–13 → **3 SP** |

**Anchor reference:** Anchor C (3 SP — "Project status enum").

**Rationale:** Sum lands at the top of the 3-SP bucket. Schema impact
score (4) dominated; uncertainty was low because the activity-log shape
is already pinned by P-004. Could climb to 5 SP if the dev discovers a
non-trivial backfill requirement during planning.
```

If sum ≥ 23, the skill **does not assign a value** — instead it returns
`SPLIT` and proposes 2–3 candidate sub-stories.

## Process (follow exactly)

### Step 1 — Read the Story

Read the Story file in full. If estimating from a draft, the draft must
include the Statement, Acceptance criteria, Capabilities affected, and
Out-of-scope sections at minimum. **Stop** if any of those are
placeholder text — the estimate would be wrong.

### Step 2 — Read the rubric

Open `references/rubric.md`. Don't guess the per-dimension scale — read
it. Skim the anchors at `specs/estimation-anchors.md` to load the
calibration context before scoring.

### Step 3 — Score each dimension

Walk through the five dimensions in order. For each dimension, write a
**one-sentence note** explaining the score. The note matters more than
the number — it makes the estimate auditable.

### Step 4 — Sum and map to Fibonacci

| Sum (5–25) | Fibonacci SP |
|---|---|
| 5–7 | **1** |
| 8–10 | **2** |
| 11–13 | **3** |
| 14–16 | **5** |
| 17–19 | **8** |
| 20–22 | **13** |
| 23–25 | **21 — SPLIT** |

A sum at the **edge of a bucket** (e.g., 13 or 14) deserves a sentence
in the rationale explaining which side you chose and why. Edge calls are
where calibration drift creeps in.

### Step 5 — Compare to the nearest anchor

Look at the SP bucket you landed in. Find the anchor at that bucket in
`specs/estimation-anchors.md`. Ask honestly: *"Is the Story I just
scored roughly the same complexity as this anchor?"*

- **Yes** → record the anchor ID in the Estimation section. Done.
- **No, this feels lighter** → re-score the dimensions that pushed the
  sum into this bucket. You may have been pessimistic on uncertainty or
  integration risk.
- **No, this feels heavier** → same exercise the other direction. Often
  it's scope or module-touch breadth that was undercounted.

Re-score, re-sum, re-bucket. Repeat at most twice. If after two passes
the bucket still feels wrong, **flag it** in the rationale — the anchor
set may need a new entry at this size.

### Step 6 — Splits

If the sum lands in the 21-SP bucket (23–25), do not return 21. Return
`SPLIT` along with:

- 2 or 3 proposed sub-story titles and one-line scopes.
- Which acceptance criteria from the parent map to each sub-story.
- Likely dependencies between the sub-stories.

The calling agent (typically the BA via `decompose-epic`) decides
whether to accept the split, re-shape the parent into the sub-stories,
or keep it as a 21-SP outlier (rare; usually means the Story is
mis-shaped).

### Step 7 — Write the rationale

One short paragraph in the Story file's Estimation section. Cover:

- Which dimension dominated.
- Any edge-of-bucket call.
- The conditions under which the estimate would climb or drop (e.g.,
  "Could climb to 5 SP if the chosen embedding model lacks a Python SDK
  and the dev has to wrap the REST API.").

The rationale is the input for *re-estimation* later — make it clear
enough that future-you can decide whether to revise.

## Variable entry levels

This skill works regardless of where the Story came from:

- Story produced by `decompose-epic` from an Epic file.
- Standalone Story dropped in by the user (Jira ticket, single
  sentence, file). No parent Epic, no parent Initiative.
- Story split out from a SPLIT result of a prior `estimate-story` run.

In all cases, the input is **the Story file alone**. Parent Epic /
Initiative context is not used in scoring — that's what keeps the
rubric implementer-neutral.

## Anti-patterns

- ❌ "I feel like a 5" without scoring the rubric. Refuse.
- ❌ Re-scoring a single dimension repeatedly to land at a preferred SP.
  The rubric is the rubric.
- ❌ Estimating without reading the anchors. Calibration drift starts
  here.
- ❌ Returning anything for sum ≥ 23. Always SPLIT.
- ❌ Mixing implementer-specific concerns ("Claude will need 3 tries")
  into any dimension. Those go in the Variance section after delivery,
  not the Estimate.
- ❌ Estimating an Epic or Initiative. SP is for Stories only.

## References

- `references/rubric.md` — the per-dimension scoring scale.
- `specs/estimation-anchors.md` — per-workspace calibration anchors.
- `specs/STORIES/0000-template.md` — where the Estimation section
  lives in each Story.
- Parent `specs/EPICS/EPIC-NNNN.md` — where the Story's estimate gets
  reflected in the Epic register's `SP` column.
