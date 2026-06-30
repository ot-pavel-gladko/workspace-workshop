#!/usr/bin/env python3
"""record_estimate.py — Record one estimate-story run (AC1).

Usage (called by the estimate-story skill after scoring a story):

    python record_estimate.py \\
        --story-id STORY-0018 \\
        --story-title "Refine the estimation skill from recorded outcomes" \\
        --estimated-date 2026-06-13 \\
        --scores scope=3,module_touch_breadth=4,schema_contract_impact=3,uncertainty=3,integration_risk=1 \\
        --notes scope="One new capability",module_touch_breadth="Touches skill+harness+store+template",schema_contract_impact="New persisted record shape",uncertainty="Unproven protocol; ADR externalises it",integration_risk="Internal-only" \\
        --estimated-sp 5

Or update an existing record's post-delivery outcome:

    python record_estimate.py \\
        --story-id STORY-0018 \\
        --record-delivery \\
        --delivery-date 2026-06-15 \\
        --actual-sp 5 \\
        --outcome-notes "Felt about right; harness took longer than expected but within 5SP."

The record store defaults to:
    <skill-root>/data/estimation_records.jsonl

Override with --store-path <path>.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Allow running this script from the skill's scripts/ directory or from the
# repo root by resolving the package root and adding it to sys.path.
# ---------------------------------------------------------------------------
_SCRIPTS_DIR = Path(__file__).parent.resolve()
_SKILL_DIR = _SCRIPTS_DIR.parent
_SKILL_LIB_ROOT = _SKILL_DIR.parent.parent.parent  # artisyn_skill_library/../../..
# packages/skill-library/
_PKG_ROOT = _SKILL_LIB_ROOT.parent
if str(_PKG_ROOT) not in sys.path:
    sys.path.insert(0, str(_PKG_ROOT))

from artisyn_skill_library.estimate_story_harness.records import (
    EstimationRecord,
    RecordStore,
    RUBRIC_DIMENSIONS,
    rubric_sum_to_sp,
)


def parse_key_value_pairs(raw: str) -> dict:
    """Parse 'key=value,key2=value2' into a dict."""
    result = {}
    for part in raw.split(","):
        if "=" not in part:
            raise argparse.ArgumentTypeError(
                f"Expected key=value pairs, got: {part!r}"
            )
        k, _, v = part.partition("=")
        result[k.strip()] = v.strip()
    return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Record an estimate-story run (AC1, ADR-0006)."
    )
    parser.add_argument("--story-id", required=True, help="e.g. STORY-0018")
    parser.add_argument("--story-title", default="", help="Human-readable title")
    parser.add_argument(
        "--store-path",
        default=None,
        help="Path to the .jsonl record store (default: skill data dir)",
    )

    subparsers = parser.add_subparsers(dest="action")

    # -- estimate subcommand --
    est = subparsers.add_parser("estimate", help="Record a new estimation run")
    est.add_argument("--estimated-date", required=True, help="YYYY-MM-DD")
    est.add_argument(
        "--scores",
        required=True,
        help="dimension=score pairs e.g. scope=3,module_touch_breadth=4,...",
    )
    est.add_argument(
        "--notes",
        default="",
        help="dimension=note pairs (use quotes around values with spaces)",
    )
    est.add_argument(
        "--estimated-sp",
        required=True,
        help="Fibonacci SP (1/2/3/5/8/13/21) or SPLIT",
    )

    # -- deliver subcommand --
    deliv = subparsers.add_parser(
        "deliver", help="Record post-delivery outcome for a story"
    )
    deliv.add_argument("--delivery-date", required=True, help="YYYY-MM-DD")
    deliv.add_argument(
        "--actual-sp",
        required=True,
        type=int,
        help="Fibonacci SP reflecting actual felt complexity",
    )
    deliv.add_argument("--outcome-notes", default="", help="Free-text outcome notes")

    args = parser.parse_args()

    store = RecordStore(path=Path(args.store_path) if args.store_path else None)

    if args.action == "estimate":
        scores_raw = parse_key_value_pairs(args.scores)
        dimension_scores = {}
        for dim in RUBRIC_DIMENSIONS:
            if dim not in scores_raw:
                print(f"Error: missing score for dimension '{dim}'", file=sys.stderr)
                return 1
            try:
                v = int(scores_raw[dim])
            except ValueError:
                print(
                    f"Error: score for '{dim}' must be an integer, got {scores_raw[dim]!r}",
                    file=sys.stderr,
                )
                return 1
            if not 1 <= v <= 5:
                print(
                    f"Error: score for '{dim}' must be 1-5, got {v}", file=sys.stderr
                )
                return 1
            dimension_scores[dim] = v

        notes_raw = parse_key_value_pairs(args.notes) if args.notes else {}
        dimension_notes = {dim: notes_raw.get(dim, "") for dim in RUBRIC_DIMENSIONS}

        rubric_sum = sum(dimension_scores.values())
        try:
            sp_raw = args.estimated_sp.strip()
            if sp_raw.upper() == "SPLIT":
                estimated_sp: object = "SPLIT"
            else:
                estimated_sp = int(sp_raw)
        except ValueError:
            print(
                f"Error: --estimated-sp must be a Fibonacci integer or SPLIT, got {args.estimated_sp!r}",
                file=sys.stderr,
            )
            return 1

        record = EstimationRecord(
            story_id=args.story_id,
            story_title=args.story_title,
            estimated_date=args.estimated_date,
            dimension_scores=dimension_scores,
            dimension_notes=dimension_notes,
            rubric_sum=rubric_sum,
            estimated_sp=estimated_sp,
        )
        store.append(record)
        print(
            f"Recorded estimate for {args.story_id}: "
            f"sum={rubric_sum}, SP={estimated_sp}. "
            f"Store: {store.path}"
        )
        return 0

    elif args.action == "deliver":
        updated = store.update_delivery(
            story_id=args.story_id,
            delivery_date=args.delivery_date,
            actual_sp=args.actual_sp,
            outcome_notes=args.outcome_notes,
        )
        if updated == 0:
            print(
                f"Warning: no records found for {args.story_id}. "
                "Was the estimate recorded first?",
                file=sys.stderr,
            )
            return 1
        print(
            f"Updated {updated} record(s) for {args.story_id} with "
            f"delivery_date={args.delivery_date}, actual_sp={args.actual_sp}."
        )
        return 0

    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    sys.exit(main())
