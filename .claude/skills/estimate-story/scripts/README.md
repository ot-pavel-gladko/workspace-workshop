# estimate-story: harness scripts

These scripts implement the ADR-0006 evidence-gated skill-refinement harness
for the `estimate-story` skill (STORY-0018).

## Scripts

| Script | Purpose |
|--------|---------|
| `record_estimate.py` | Record an estimation run or post-delivery outcome (AC1) |
| `evaluate_guidance.py` | Score current guidance BHR/MAE_b over held-out set (AC2) |
| `propose_change.py` | Propose a guidance change, run the gate, stage for review (AC3/4/5) |

## Record store

Records are persisted to:

    artisyn_skill_library/skills/estimate-story/data/estimation_records.jsonl
    artisyn_skill_library/skills/estimate-story/data/staged_proposals.jsonl
    artisyn_skill_library/skills/estimate-story/data/rejected_proposals.jsonl

These files are git-tracked (live-record stores are committed when records
are added by the workspace owner).

## Typical workflow

### 1. After running estimate-story on a story

```bash
python scripts/record_estimate.py estimate \
    --story-id STORY-0019 \
    --story-title "Title here" \
    --estimated-date 2026-06-14 \
    --scores scope=2,module_touch_breadth=2,schema_contract_impact=1,uncertainty=2,integration_risk=1 \
    --notes "scope=Small new sub-capability,module_touch_breadth=Two modules" \
    --estimated-sp 2
```

### 2. After the story is delivered

```bash
python scripts/record_estimate.py deliver \
    --story-id STORY-0019 \
    --delivery-date 2026-06-20 \
    --actual-sp 3 \
    --outcome-notes "Slightly harder than expected; discovery in module B."
```

### 3. Evaluate guidance accuracy

```bash
python scripts/evaluate_guidance.py
# Expected now: "insufficient data — 0 delivered record(s); need >= 8."
```

### 4. Propose a guidance change (once >= 8 delivered records exist)

```bash
python scripts/propose_change.py \
    --target-file anchors \
    --declared-changes 1 \
    --diff-summary "Add STORY-0019 as 3-SP anchor."
```

If the gate ACCEPTs, the proposal is staged in `data/staged_proposals.jsonl`
for human review.  The human applies the diff manually to
`specs/estimation-anchors.md` (or `references/rubric.md`) and calls:

```python
from artisyn_skill_library.estimate_story_harness.staging import StagingArea
sa = StagingArea()
sa.mark_applied(
    proposal_id="PROP-20260620-120000-abc12345",
    evidence_back_ref="eval-run fingerprint: STORY-0011:2026-06-01|...",
)
```

## Post-delivery outcome capture in story files

The story file template (`specs/STORIES/0000-template.md`) should carry a
**Post-delivery outcome** section.  Required field (see STORY-0018 AC1):

```markdown
## Post-delivery outcome

| Field | Value |
|---|---|
| Delivery date | <!-- YYYY-MM-DD --> |
| Actual SP (felt complexity) | <!-- Fibonacci SP: 1/2/3/5/8/13/21 --> |
| Outcome notes | <!-- What was harder/easier than estimated? --> |
```

> **Note:** The canonical story template lives in `specs/STORIES/0000-template.md`
> in the meta-repo (workspace-artisyn), which is untracked from the platform
> repo.  The platform repo cannot edit that file directly.  The workspace owner
> must add the Post-delivery outcome section to the template manually.
> See STORY-0018 report for details.

## ADR-0006 protocol encoded

| ADR-0006 rule | Where encoded |
|---|---|
| §1 BHR / MAE_b scorer | `estimate_story_harness/scorer.py::score_guidance` |
| §2 Held-out split (last 30%, delivery order) | `scorer.py::split_held_out` |
| §2 No label leakage | scorer uses only `rubric_sum`; `actual_sp` is answer key only |
| §3 Strict-improvement gate | `estimate_story_harness/gate.py::run_gate` |
| §3 Rejected-proposals record | `staging.py::StagingArea.rejected_path` |
| §4 Edit-bound | `estimate_story_harness/bounds.py::check_edit_bound` |
| §5 Human-review staging | `staging.py::StagingArea.staged_path` (no auto-apply) |
| §5 Evidence back-reference | `staging.py::StagingArea.mark_applied(evidence_back_ref=...)` |
| §6 N=8 insufficient-data | `records.py::MIN_DELIVERED_FOR_EVAL = 8` |
| §7 Secret-free, reproducible | pure functions of rubric_sum + actual_sp; no model call |
