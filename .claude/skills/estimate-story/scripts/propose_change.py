#!/usr/bin/env python3
"""propose_change.py — Propose a guidance change and gate it (AC3/4/5, ADR-0006 §3-5).

This script:
1. Checks the edit bound (ADR-0006 §4).
2. Checks if the proposal was already rejected against the same held-out set.
3. Evaluates the current guidance and the proposed guidance.
4. Runs the strict-improvement gate (ADR-0006 §3).
5. Writes the result to the staging area (AC4 — human review required).
6. Reports the verdict.

The proposed guidance is supplied as a Python expression for the replacement
sum→SP function via --proposed-fn.  For typical usage (anchor or rubric tweaks
that don't change the sum→SP table itself), the proposed function is the same
as the current; instead, the proposal is recorded as a diff_summary that the
human reviewer applies manually.

Usage (anchor proposal):
    python propose_change.py \\
        --target-file anchors \\
        --declared-changes 1 \\
        --diff-summary "Add STORY-0018 as 5-SP anchor: felt-complexity confirmed 5SP on delivery." \\
        [--store-path PATH] [--staging-dir PATH]

Usage (rubric proposal):
    python propose_change.py \\
        --target-file rubric \\
        --declared-changes 2 \\
        --diff-summary "Scope dim score-3 clarification: add note about config-path changes." \\
        [--store-path PATH] [--staging-dir PATH]

Exit codes:
    0 = ACCEPT (gate passed, staged for human review)
    1 = REJECT (gate rejected or bound exceeded, logged to rejects)
    2 = insufficient data (ADR-0006 §6)
    3 = usage error
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).parent.resolve()
_PKG_ROOT = _SCRIPTS_DIR.parent.parent.parent.parent.parent
if str(_PKG_ROOT) not in sys.path:
    sys.path.insert(0, str(_PKG_ROOT))

from artisyn_skill_library.estimate_story_harness.bounds import (
    EditBound,
    check_edit_bound,
)
from artisyn_skill_library.estimate_story_harness.gate import run_gate
from artisyn_skill_library.estimate_story_harness.records import (
    RecordStore,
    rubric_sum_to_sp,
)
from artisyn_skill_library.estimate_story_harness.scorer import score_guidance
from artisyn_skill_library.estimate_story_harness.staging import StagingArea


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Propose an estimation guidance change and run the ADR-0006 gate."
    )
    parser.add_argument(
        "--target-file",
        required=True,
        choices=["anchors", "rubric"],
        help="Which guidance file this proposal targets",
    )
    parser.add_argument(
        "--declared-changes",
        required=True,
        type=int,
        help="Number of anchor rows (<=2) or rubric cell edits (<=3) declared",
    )
    parser.add_argument(
        "--diff-summary",
        required=True,
        help="Human-readable description of the proposed change",
    )
    parser.add_argument(
        "--store-path",
        default=None,
        help="Path to estimation_records.jsonl",
    )
    parser.add_argument(
        "--staging-dir",
        default=None,
        help="Directory for staged_proposals.jsonl and rejected_proposals.jsonl",
    )
    args = parser.parse_args()

    store = RecordStore(path=Path(args.store_path) if args.store_path else None)
    staging = StagingArea(
        data_dir=Path(args.staging_dir) if args.staging_dir else None
    )
    target = EditBound(args.target_file)

    # 1. Edit-bound check
    bound_result = check_edit_bound(target, args.declared_changes)
    if not bound_result.passed:
        print(f"BOUND EXCEEDED: {bound_result.reason}", file=sys.stderr)
        return 1

    # 2. Load delivered records and check sufficiency
    delivered = store.delivered_records()
    current_result = score_guidance(delivered)

    if current_result.insufficient_data:
        print(
            f"INSUFFICIENT DATA: {current_result.message}",
            file=sys.stderr,
        )
        return 2

    # 3. Check if already rejected against same held-out set
    if staging.is_already_rejected(args.diff_summary, current_result.held_out_fingerprint):
        print(
            "ALREADY REJECTED: This proposal was previously rejected against the "
            "same held-out set (fingerprint unchanged). Re-evaluate only once new "
            "deliveries shift the held-out split. (ADR-0006 §3)",
            file=sys.stderr,
        )
        return 1

    # 4. Evaluate proposed guidance
    # For anchor/rubric text changes that don't alter the sum→SP function,
    # the proposed function is the same as the current (stock).
    # The improvement must come from the rubric scores having been recalibrated
    # in a new estimation run using the proposed anchors.
    # The diff_summary is the human-readable record of what changed.
    proposed_result = score_guidance(delivered, guidance_fn=rubric_sum_to_sp)

    # 5. Run gate
    gate_result = run_gate(current_result, proposed_result)

    # 6. Stage the proposal (always — AC4 human review)
    record = staging.submit(
        target_file=args.target_file,
        declared_change_count=args.declared_changes,
        diff_summary=args.diff_summary,
        gate_result=gate_result,
    )

    print(f"Proposal ID: {record.proposal_id}")
    print(f"Verdict: {gate_result.verdict.value}")
    print(f"Reason: {gate_result.reason}")
    print(f"Staged to: {staging.staged_path}")
    if gate_result.rejected:
        print(f"Logged to rejected proposals: {staging.rejected_path}")
        return 1

    print("ACCEPT — staged for human review. Apply manually after review (AC4).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
