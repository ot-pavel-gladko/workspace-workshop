#!/usr/bin/env python3
"""evaluate_guidance.py — Score current guidance accuracy (AC2, ADR-0006 §1-2).

Loads all delivered-with-actual records from the record store, applies the
held-out split, and reports BHR + MAE_b.

Usage:
    python evaluate_guidance.py [--store-path PATH]

Expected output when there are < 8 delivered records (live state):
    RESULT: insufficient data — 0 delivered record(s); need >= 8.
    No acceptance verdict issued (ADR-0006 §6).

Expected output once >= 8 records exist:
    RESULT: BHR=0.8000, MAE_b=0.2667
    over 3 held-out / 8 total delivered records.
    Held-out fingerprint: STORY-0001:2026-07-01|STORY-0002:2026-07-02|...
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).parent.resolve()
_PKG_ROOT = _SCRIPTS_DIR.parent.parent.parent.parent.parent  # packages/skill-library/
if str(_PKG_ROOT) not in sys.path:
    sys.path.insert(0, str(_PKG_ROOT))

from artisyn_skill_library.estimate_story_harness.records import RecordStore
from artisyn_skill_library.estimate_story_harness.scorer import score_guidance


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Evaluate current estimation guidance accuracy (ADR-0006 §1-2)."
    )
    parser.add_argument(
        "--store-path",
        default=None,
        help="Path to estimation_records.jsonl (default: skill data dir)",
    )
    args = parser.parse_args()

    store = RecordStore(path=Path(args.store_path) if args.store_path else None)
    delivered = store.delivered_records()
    result = score_guidance(delivered)

    if result.insufficient_data:
        print(
            f"RESULT: insufficient data — {result.total_delivered} delivered "
            f"record(s); need >= 8."
        )
        print("No acceptance verdict issued (ADR-0006 §6).")
        return 2  # Exit 2 = insufficient data (not an error)

    print(
        f"RESULT: BHR={result.bhr:.4f}, MAE_b={result.mae_b:.4f}"
    )
    print(
        f"over {result.held_out_count} held-out / "
        f"{result.total_delivered} total delivered records."
    )
    print(f"Held-out fingerprint: {result.held_out_fingerprint}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
