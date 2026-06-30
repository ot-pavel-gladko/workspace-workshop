#!/usr/bin/env python3
"""specs_tracker — local specs/ story tracker backend for the watch daemon.

Stdlib-only (runs in the runner image, which has no pip-installed deps). Scans
specs/STORIES/*.md and reports stories a human has authorized for autonomous
processing: Status == entry_status AND Assignee names a known agent AND (when
require_label is set) the story carries that label. The assignee+status+label
triple is the HITL gate (ADR-0009/ADR-0010).

STORY-0025: generalized gate — entry_status + assignee + optional label.
STORY-0027: dispatch ledger (append_ledger) for KPI-compatible signal trail.
STORY-0054: reconcile pass — auto-mark dispatched stories Done on MR merge
  (record_dispatch_mr, load_dispatch_mrs, query_mr_state, emit_closeout_intent,
  load_pending_intents, mark_intent_applied, apply_closeout_intent,
  apply_closeout_intents, reconcile_pass).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.request
import warnings
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote


def content_hash_for(path) -> str:
    """Return SHA-256 hex digest of the story file's text."""
    return hashlib.sha256(Path(path).read_text(encoding="utf-8").encode("utf-8")).hexdigest()


def load_dispatched(state_file) -> dict:
    """Return {key: hash} from state_file, or {} if missing/empty/malformed."""
    p = Path(state_file)
    if not p.exists():
        return {}
    text = p.read_text(encoding="utf-8").strip()
    if not text:
        return {}
    try:
        data = json.loads(text)
        # Ensure the loaded data is a dict; return {} if not
        if not isinstance(data, dict):
            return {}
        return data
    except json.JSONDecodeError:
        return {}


def record_dispatched(state_file, key: str, content_hash: str) -> None:
    """Merge {key: content_hash} into state_file (create parent dirs as needed)."""
    p = Path(state_file)
    p.parent.mkdir(parents=True, exist_ok=True)
    data = load_dispatched(p)
    data[key] = content_hash
    p.write_text(json.dumps(data), encoding="utf-8")


def _field_re(name: str) -> re.Pattern:
    # Matches a markdown bullet field like:  - **Status:** Ready-for-agent
    return re.compile(r"^\s*[-*]\s*\*\*" + name + r":\*\*\s*(.+?)\s*$", re.IGNORECASE)


_STATUS_RE = _field_re("Status")
_ASSIGNEE_RE = _field_re("Assignee")
_LABELS_RE = _field_re("Labels")
_H1_KEY_RE = re.compile(r"^#\s+(STORY-\d+)", re.IGNORECASE)
_COMMENT_RE = re.compile(r"\s*<!--.*?-->\s*$")


def _clean(value: str | None) -> str | None:
    if value is None:
        return None
    return _COMMENT_RE.sub("", value).strip()


def _first(text: str, regex: re.Pattern) -> str | None:
    for line in text.splitlines():
        m = regex.match(line)
        if m:
            return m.group(1)
    return None


def parse_story(path) -> dict:
    text = Path(path).read_text(encoding="utf-8")
    return {
        "key": _clean(_first(text, _H1_KEY_RE)) or Path(path).stem,
        "status": _clean(_first(text, _STATUS_RE)),
        "assignee": _clean(_first(text, _ASSIGNEE_RE)),
        "labels": _clean(_first(text, _LABELS_RE)),
        "path": str(path),
    }


def _norm(s: str | None) -> str:
    return (s or "").strip().lower()


def _has_label(story_labels: str | None, require_label: str) -> bool:
    """Return True when require_label appears as one of the comma-separated labels."""
    if not story_labels:
        return False
    req = require_label.strip().lower()
    return any(lbl.strip().lower() == req for lbl in story_labels.split(","))


def discover_agents(agents_dir) -> list[str]:
    d = Path(agents_dir)
    if not d.is_dir():
        return []
    return sorted(p.stem for p in d.glob("*.md"))


def ready_stories(
    stories_dir,
    ready_status: str,
    known_agents,
    dispatched=None,
    *,
    require_label: str | None = None,
) -> list[dict]:
    """Return stories ready for the Development stage (STORY-0025, ADR-0010 §3).

    Gate conditions (ALL must hold):
      1. status == ready_status (the configured entry status for Development)
      2. assignee names a known agent
      3. when require_label is non-empty: the story's Labels: field contains it
      4. content hash has not been recorded in dispatched (dequeue)
    """
    ready = _norm(ready_status)
    known = {_norm(a) for a in known_agents}
    if dispatched is None:
        dispatched = {}
    label_gate = bool(require_label and require_label.strip())
    out: list[dict] = []
    for p in sorted(Path(stories_dir).glob("*.md")):
        if p.name.startswith("0000"):       # skip the story template
            continue
        s = parse_story(p)
        if _norm(s["status"]) != ready:
            continue
        if not s["assignee"] or _norm(s["assignee"]) not in known:
            continue
        # Label gate (ADR-0010 §3): skip unless the story carries the required label.
        if label_gate and not _has_label(s["labels"], require_label):
            continue
        # Skip if already dispatched with the same content hash (unchanged).
        if dispatched.get(s["key"]) == content_hash_for(p):
            continue
        out.append(s)
    return out


def mark_status(path, new_status: str) -> bool:
    """Rewrite the Status bullet to new_status. Returns True iff the file changed."""
    p = Path(path)
    lines = p.read_text(encoding="utf-8").splitlines(keepends=True)
    for i, line in enumerate(lines):
        if _STATUS_RE.match(line):
            indent = line[: len(line) - len(line.lstrip())]
            new_line = f"{indent}- **Status:** {new_status}\n"
            if lines[i] == new_line:
                return False
            lines[i] = new_line
            p.write_text("".join(lines), encoding="utf-8")
            return True
    return False


def story_path(stories_dir, key: str) -> str | None:
    for p in sorted(Path(stories_dir).glob("*.md")):
        if p.name.startswith("0000"):
            continue
        if parse_story(p)["key"].lower() == key.strip().lower():
            return str(p)
    return None


# ---------------------------------------------------------------------------
# STORY-0027 — Dispatch ledger
# ---------------------------------------------------------------------------

def append_ledger(
    ledger_path,
    story_key: str,
    *,
    stage: str = "Development",
    cost_usd=None,
    tokens=None,
    timestamp: str | None = None,
) -> None:
    """Append one JSONL record to the per-dispatch ledger (STORY-0027, ADR-0009 §5).

    Record shape:
      {"timestamp": <ISO-8601>, "story_key": <str>, "stage": <str>,
       "cost_usd": <float|null>, "tokens": <int|null>}

    Missing or unparseable cost data degrades gracefully: a warning is emitted
    to stderr and the record is written with cost_usd=null / tokens=null (the
    cg warn-only posture; STORY-0027 AC4).
    """
    p = Path(ledger_path)
    p.parent.mkdir(parents=True, exist_ok=True)

    ts = timestamp or datetime.now(timezone.utc).isoformat()

    # Validate cost fields — warn and nullify if unparseable.
    safe_cost: float | None = None
    safe_tokens: int | None = None
    try:
        if cost_usd is not None:
            safe_cost = float(cost_usd)
    except (TypeError, ValueError):
        warnings.warn(
            f"[specs_tracker] append_ledger: cost_usd={cost_usd!r} is not numeric — omitted from ledger",
            stacklevel=2,
        )
        sys.stderr.write(
            f"[runner] WARN: dispatch ledger cost_usd={cost_usd!r} is not numeric; omitted\n"
        )
    try:
        if tokens is not None:
            safe_tokens = int(tokens)
    except (TypeError, ValueError):
        warnings.warn(
            f"[specs_tracker] append_ledger: tokens={tokens!r} is not an integer — omitted from ledger",
            stacklevel=2,
        )
        sys.stderr.write(
            f"[runner] WARN: dispatch ledger tokens={tokens!r} is not an integer; omitted\n"
        )

    record = {
        "timestamp": ts,
        "story_key": story_key,
        "stage": stage,
        "cost_usd": safe_cost,
        "tokens": safe_tokens,
    }
    with p.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record) + "\n")


def append_transition(
    ledger_path,
    story_key: str,
    *,
    from_status: str,
    to_status: str,
    actor: str,
    stage: str,
    actor_kind: str = "agent",
    cost_usd=None,
    tokens=None,
    timestamp: str | None = None,
) -> None:
    """Append a status-transition record to the ledger (STORY-0030, ADR-0012 §3).

    Extends the STORY-0027 ledger format with a ``record_type=transition`` record
    so status transition events are captured alongside the existing dispatch
    records, enabling the SpecsProvider to yield normalized TransitionEvents.

    Record shape (additional fields beyond STORY-0027 dispatch record):
      {"record_type": "transition", "timestamp": <ISO-8601>,
       "story_key": <str>, "from_status": <str>, "to_status": <str>,
       "actor_kind": <str>, "actor": <str>, "stage": <str>,
       "cost_usd": <float|null>, "tokens": <int|null>}

    Two call points in the watch loop (ADR-0012 §3 specs provider):
      - START: entry_status → in_progress  (cost usually unknown; omit = null)
      - DONE:  in_progress → in_review     (cost known from the dispatch output)

    The record is append-only and backward-compatible with the existing
    dispatch record shape (different record_type distinguishes them).

    Missing or unparseable cost data degrades gracefully: a warning is emitted
    and the record is written with cost_usd=null / tokens=null (AC3).

    Statuses are the generic profile names read from env vars in watch.sh,
    NOT hardcoded literals (AC4, ADR-0012 §1).
    """
    p = Path(ledger_path)
    p.parent.mkdir(parents=True, exist_ok=True)

    ts = timestamp or datetime.now(timezone.utc).isoformat()

    # Validate cost fields — warn and nullify if unparseable (same posture as append_ledger).
    safe_cost: float | None = None
    safe_tokens: int | None = None
    try:
        if cost_usd is not None:
            safe_cost = float(cost_usd)
    except (TypeError, ValueError):
        warnings.warn(
            f"[specs_tracker] append_transition: cost_usd={cost_usd!r} is not numeric — omitted",
            stacklevel=2,
        )
        sys.stderr.write(
            f"[runner] WARN: transition ledger cost_usd={cost_usd!r} is not numeric; omitted\n"
        )
    try:
        if tokens is not None:
            safe_tokens = int(tokens)
    except (TypeError, ValueError):
        warnings.warn(
            f"[specs_tracker] append_transition: tokens={tokens!r} is not an integer — omitted",
            stacklevel=2,
        )
        sys.stderr.write(
            f"[runner] WARN: transition ledger tokens={tokens!r} is not an integer; omitted\n"
        )

    record = {
        "record_type": "transition",
        "timestamp": ts,
        "story_key": story_key,
        "from_status": from_status,
        "to_status": to_status,
        "actor_kind": actor_kind,
        "actor": actor,
        "stage": stage,
        "cost_usd": safe_cost,
        "tokens": safe_tokens,
    }
    with p.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record) + "\n")


# ---------------------------------------------------------------------------
# STORY-0048 — Dispatch cost parsing
# ---------------------------------------------------------------------------

DEFAULT_MODEL_PRICES = {
    "claude-opus-4-8": {"input": 15.0, "output": 75.0},
    "claude-opus-4-7": {"input": 15.0, "output": 75.0},
    "claude-sonnet-4-6": {"input": 3.0, "output": 15.0},
    "claude-sonnet-4-5": {"input": 3.0, "output": 15.0},
    "claude-haiku-4-5-20251001": {"input": 0.80, "output": 4.0},
    "default": {"input": 3.0, "output": 15.0},
}


def load_model_prices(prices_path=None) -> dict:
    """Load per-model prices from a JSON config file; fall back to DEFAULT_MODEL_PRICES."""
    if prices_path is None:
        prices_path = Path(__file__).parent / "model-prices.json"
    p = Path(prices_path)
    if not p.exists():
        return DEFAULT_MODEL_PRICES
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return DEFAULT_MODEL_PRICES


def _estimate_model_cost(model_usage: dict, prices: dict) -> float:
    """
    Estimate cost for one model from its token usage.
    Formula (AC2): (input×in + output×out + cache_read×in×0.1 + cache_creation×in×1.25) / 1e6
    """
    model_name = model_usage.get("model", "default")
    p = prices.get(model_name) or prices.get("default") or {"input": 3.0, "output": 15.0}
    in_price = p.get("input", 3.0)
    out_price = p.get("output", 15.0)
    inp = model_usage.get("input_tokens", 0) or 0
    out = model_usage.get("output_tokens", 0) or 0
    cache_read = model_usage.get("cache_read_input_tokens", 0) or 0
    cache_create = model_usage.get("cache_creation_input_tokens", 0) or 0
    return (inp * in_price + out * out_price + cache_read * in_price * 0.1 + cache_create * in_price * 1.25) / 1e6


def parse_cost_from_result(result: dict, prices: dict | None = None) -> dict:
    """
    Extract cost/token data from a `claude -p --output-format json` result dict.

    The JSON result shape (STORY-0048 AC1):
      {
        "total_cost_usd": float,         # present when claude knows the cost
        "usage": {                        # aggregate token counts
          "input_tokens": int,
          "output_tokens": int,
          "cache_creation_input_tokens": int,
          "cache_read_input_tokens": int,
        },
        "modelUsage": {                   # per-model breakdown (AC4)
          "<model-id>": { same usage fields }
        }
      }

    Returns:
      {
        "cost_usd": float | None,
        "tokens": int | None,
        "label": str,          # display string for PR/ledger
        "is_estimate": bool,
      }

    Degrades gracefully (AC5): returns nulls without raising.
    """
    if prices is None:
        prices = load_model_prices()

    try:
        usage = result.get("usage") or {}
        model_usage_map = result.get("modelUsage") or {}

        # Total tokens from the aggregate usage block.
        total_tokens: int | None = None
        if usage:
            total_tokens = (
                (usage.get("input_tokens") or 0)
                + (usage.get("output_tokens") or 0)
                + (usage.get("cache_creation_input_tokens") or 0)
                + (usage.get("cache_read_input_tokens") or 0)
            ) or None

        # AC1: use total_cost_usd when present.
        if result.get("total_cost_usd") is not None:
            cost = float(result["total_cost_usd"])
            tok_str = f" / {total_tokens} tokens" if total_tokens is not None else ""
            label = f"${cost:.4f} (API-list){tok_str}"
            return {"cost_usd": cost, "tokens": total_tokens, "label": label, "is_estimate": False}

        # AC2: estimate from per-model breakdown when total_cost_usd absent.
        if model_usage_map:
            estimated = 0.0
            for model_id, mu in model_usage_map.items():
                mu_with_name = dict(mu, model=model_id)
                estimated += _estimate_model_cost(mu_with_name, prices)
            tok_str = f" / {total_tokens} tokens" if total_tokens is not None else ""
            label = f"~${estimated:.4f} (est., API-list){tok_str}"
            return {"cost_usd": estimated, "tokens": total_tokens, "label": label, "is_estimate": True}

        # AC2 fallback: aggregate usage without per-model breakdown — use default rate.
        # Handles the case where usage is present but modelUsage is absent (H4 fix).
        if usage:
            default_usage = {
                "model": "default",
                "input_tokens": usage.get("input_tokens", 0),
                "output_tokens": usage.get("output_tokens", 0),
                "cache_creation_input_tokens": usage.get("cache_creation_input_tokens", 0),
                "cache_read_input_tokens": usage.get("cache_read_input_tokens", 0),
            }
            estimated = _estimate_model_cost(default_usage, prices)
            tok_str = f" / {total_tokens} tokens" if total_tokens is not None else ""
            label = f"~${estimated:.4f} (est., API-list){tok_str}"
            return {"cost_usd": estimated, "tokens": total_tokens, "label": label, "is_estimate": True}

        # AC5: no usable data.
        return {"cost_usd": None, "tokens": total_tokens, "label": "unknown USD / unknown tokens", "is_estimate": False}

    except Exception:
        return {"cost_usd": None, "tokens": None, "label": "unknown USD / unknown tokens", "is_estimate": False}


# ---------------------------------------------------------------------------
# STORY-0054 — Reconcile pass: auto-mark dispatched stories Done on MR merge
# ---------------------------------------------------------------------------

def record_dispatch_mr(
    ledger_path,
    story_key: str,
    *,
    branch: str,
    mr_iid: int,
    mr_url: str,
    timestamp: str | None = None,
) -> None:
    """Append a dispatch_mr record to the ledger (STORY-0054).

    Record shape:
      {"record_type": "dispatch_mr", "timestamp": <ISO-8601>,
       "story_key": <str>, "branch": <str>, "mr_iid": <int>, "mr_url": <str>}
    """
    p = Path(ledger_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    ts = timestamp or datetime.now(timezone.utc).isoformat()
    record = {
        "record_type": "dispatch_mr",
        "timestamp": ts,
        "story_key": story_key,
        "branch": branch,
        "mr_iid": int(mr_iid),
        "mr_url": mr_url,
    }
    with p.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record) + "\n")


def load_dispatch_mrs(ledger_path) -> dict:
    """Read ledger, return {story_key: {branch, mr_iid, mr_url}} for the LATEST
    dispatch_mr record per story key (last-writer-wins).

    Ignores records without record_type == "dispatch_mr".
    Returns {} when ledger_path does not exist or is empty.
    """
    p = Path(ledger_path)
    if not p.exists():
        return {}
    result: dict = {}
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get("record_type") != "dispatch_mr":
            continue
        key = rec.get("story_key")
        if not key:
            continue
        result[key] = {
            "branch": rec.get("branch", ""),
            "mr_iid": rec.get("mr_iid"),
            "mr_url": rec.get("mr_url", ""),
        }
    return result


def query_mr_state(
    gitlab_url: str,
    project_id: str,
    token: str,
    mr_iid: int,
) -> dict | None:
    """Query GitLab REST API for a single MR by IID.

    Returns the parsed JSON dict on HTTP 200, or None on any error.
    The token is passed via the PRIVATE-TOKEN header — never in the URL (ADR-0008).
    Never logs the token.
    """
    base = gitlab_url.rstrip("/")
    # URL-encode the project_id in case it's a path (e.g. "group/repo")
    encoded_project = quote(str(project_id), safe="")
    url = f"{base}/api/v4/projects/{encoded_project}/merge_requests/{int(mr_iid)}"
    req = urllib.request.Request(
        url,
        headers={"PRIVATE-TOKEN": token},
        method="GET",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read()
            return json.loads(body)
    except Exception as exc:
        sys.stderr.write(f"[specs_tracker] WARN: query_mr_state MR!{mr_iid} failed: {type(exc).__name__}\n")
        return None


def emit_closeout_intent(intents_path, intent: dict) -> None:
    """Append one JSONL closeout intent record to intents_path (creates parent dirs)."""
    p = Path(intents_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(intent) + "\n")


def load_pending_intents(intents_path) -> list:
    """Read intents_path, return records where applied is not True."""
    p = Path(intents_path)
    if not p.exists():
        return []
    pending = []
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get("applied") is not True:
            pending.append(rec)
    return pending


def mark_intent_applied(intents_path, story_key: str) -> None:
    """Rewrite intents_path marking the story_key record applied=true.

    Uses a write-then-replace pattern for crash safety: writes to a .tmp file
    first, then atomically renames it over the original (os.replace).
    """
    p = Path(intents_path)
    if not p.exists():
        return
    records = []
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get("story_key") == story_key:
            rec["applied"] = True
        records.append(rec)
    # Atomic write via temp file + os.replace
    tmp = p.with_suffix(".tmp")
    tmp.write_text("\n".join(json.dumps(r) for r in records) + "\n", encoding="utf-8")
    os.replace(str(tmp), str(p))


_LABELS_FIELD_RE = re.compile(r"^(\s*[-*]\s*\*\*Labels:\*\*\s*)(.+?)\s*$", re.IGNORECASE)
_POST_DELIVERY_DATE_RE = re.compile(r"^(\s*[-*]\s*\*\*delivery_date:\*\*\s*)(.+?)\s*$", re.IGNORECASE)
_POST_DELIVERY_SP_RE = re.compile(r"^(\s*[-*]\s*\*\*actual_sp:\*\*\s*)(.+?)\s*$", re.IGNORECASE)
_POST_DELIVERY_NOTES_RE = re.compile(r"^(\s*[-*]\s*\*\*outcome_notes:\*\*\s*)(.+?)\s*$", re.IGNORECASE)


def apply_closeout_intent(intent: dict, stories_dir) -> None:
    """Apply one closeout intent to the matched story file (ADR-0015 emit-and-apply).

    Edits the story file:
      - Rewrites Status: bullet to Done.
      - Removes adlc-auto from the Labels: bullet.
      - Fills the Post-delivery outcome block with delivery_date, MR ref,
        merge commit sha (if present), cost/tokens (if present).

    Idempotent: if the story is already Done, does nothing.
    Confined to specs/STORIES/ — only writes the matched story file.
    """
    story_key = intent.get("story_key", "")
    if not story_key:
        return

    # Find the story file inside stories_dir only (never walks outside it).
    target_path = story_path(stories_dir, story_key)
    if not target_path:
        sys.stderr.write(f"[specs_tracker] WARN: apply_closeout_intent: story file not found for {story_key}\n")
        return

    p = Path(target_path)
    # Verify the path is inside stories_dir (safety guard).
    try:
        p.resolve().relative_to(Path(stories_dir).resolve())
    except ValueError:
        sys.stderr.write(f"[specs_tracker] WARN: apply_closeout_intent: path {p} is outside stories_dir — skipped\n")
        return

    lines = p.read_text(encoding="utf-8").splitlines(keepends=True)

    # Idempotency: skip if already Done.
    current_status = _clean(_first("".join(lines), _STATUS_RE))
    if (current_status or "").strip().lower() == "done":
        return

    # Build the values for the outcome block.
    delivery_date = intent.get("delivery_date", datetime.now(timezone.utc).date().isoformat())
    mr_iid = intent.get("mr_iid")
    mr_url = intent.get("mr_url", "")
    merge_commit_sha = intent.get("merge_commit_sha")
    cost_usd = intent.get("cost_usd")
    tokens = intent.get("tokens")

    # Build outcome notes from available fields.
    notes_parts = []
    mr_ref = f"MR !{mr_iid}" if mr_iid else ""
    if mr_url:
        mr_ref = f"{mr_ref} ({mr_url})" if mr_ref else mr_url
    if mr_ref:
        notes_parts.append(f"MR: {mr_ref}")
    if merge_commit_sha:
        notes_parts.append(f"merge_commit: {merge_commit_sha}")
    if cost_usd is not None:
        tok_str = f" / {tokens} tokens" if tokens is not None else ""
        notes_parts.append(f"cost: ${cost_usd:.4f}{tok_str}")
    outcome_notes = "; ".join(notes_parts) if notes_parts else "auto-closed"

    new_lines = []
    for line in lines:
        # Rewrite Status -> Done (strip inline HTML comment too).
        if _STATUS_RE.match(line):
            indent = line[: len(line) - len(line.lstrip())]
            new_lines.append(f"{indent}- **Status:** Done\n")
            continue

        # Strip adlc-auto from Labels field.
        lm = _LABELS_FIELD_RE.match(line)
        if lm:
            prefix = lm.group(1)
            raw_labels = lm.group(2)
            # Remove adlc-auto (case-insensitive) from the comma-separated list.
            labels = [lbl.strip() for lbl in raw_labels.split(",") if lbl.strip().lower() != "adlc-auto"]
            new_lines.append(f"{prefix}{', '.join(labels)}\n")
            continue

        # Fill Post-delivery outcome fields.
        dm = _POST_DELIVERY_DATE_RE.match(line)
        if dm:
            new_lines.append(f"{dm.group(1)}{delivery_date}\n")
            continue

        sm = _POST_DELIVERY_SP_RE.match(line)
        if sm:
            new_lines.append(f"{sm.group(1)}<bucket>\n")
            continue

        nm = _POST_DELIVERY_NOTES_RE.match(line)
        if nm:
            new_lines.append(f"{nm.group(1)}{outcome_notes}\n")
            continue

        new_lines.append(line)

    p.write_text("".join(new_lines), encoding="utf-8")


def apply_closeout_intents(intents_path, stories_dir) -> None:
    """Loop over pending intents, apply each, and mark it applied (idempotent)."""
    pending = load_pending_intents(intents_path)
    for intent in pending:
        story_key = intent.get("story_key")
        if not story_key:
            continue
        try:
            apply_closeout_intent(intent, stories_dir)
            mark_intent_applied(intents_path, story_key)
        except Exception as exc:
            sys.stderr.write(f"[specs_tracker] WARN: apply_closeout_intents: error applying {story_key}: {exc}\n")


def _story_id_guard(story_key: str, mr_data: dict, ledger_branch: str) -> bool:
    """Return True if the MR data from the API references the story_key (AC6, STORY-0054).

    Passes when ANY of these hold:
    - story_key.lower() appears in the MR's source_branch as returned by the API, OR
    - the MR description contains a 'Refs:' line naming the story key.

    The ledger_branch parameter is kept for logging context but is NOT used for the
    guard check — the API source_branch is the authoritative reference, since we are
    validating the MR that the GitLab API returned, not the branch we originally recorded.
    This prevents a case where the ledger branch contains the story slug but the actual
    merged MR belongs to a different story.
    """
    slug = story_key.lower()

    # Word-boundary pattern: slug not preceded or followed by a digit or word char.
    # This prevents false positives for adjacent IDs (e.g. story-0054 matching story-00540).
    _wb_pattern = r'(?<![0-9a-z])' + re.escape(slug) + r'(?![0-9a-z])'

    # Check API-returned source_branch (authoritative).
    api_branch = (mr_data.get("source_branch") or "").lower()
    if re.search(_wb_pattern, api_branch, re.IGNORECASE):
        return True

    # Check Refs: line in description.
    description = mr_data.get("description") or ""
    for line in description.splitlines():
        stripped = line.strip()
        if stripped.lower().startswith("refs:") and re.search(_wb_pattern, stripped, re.IGNORECASE):
            return True

    return False


def reconcile_pass(
    ledger_path,
    intents_path,
    gitlab_url: str,
    project_id: str,
    token: str,
    stories_dir,
) -> int:
    """Run the reconcile pass (ADR-0015 emit-and-apply, STORY-0054).

    For each dispatch_mr record in the ledger:
    1. Skip if story is already Done.
    2. Query GitLab for the MR state.
    3. If merged AND story-id guard passes: emit a closeout intent.
    4. If closed: log warning and skip.
    5. On any error: log warning, continue (non-crashing, AC5).

    Returns count of new closeout intents emitted this pass.
    """
    dispatch_mrs = load_dispatch_mrs(ledger_path)
    if not dispatch_mrs:
        return 0

    emitted = 0
    for story_key, mr_info in dispatch_mrs.items():
        mr_iid = mr_info.get("mr_iid")
        branch = mr_info.get("branch", "")
        mr_url = mr_info.get("mr_url", "")

        if mr_iid is None:
            sys.stderr.write(f"[specs_tracker] WARN: reconcile_pass: no mr_iid for {story_key} — skipped\n")
            continue

        # AC7c: skip if story is already Done (read current state from file).
        s_path = story_path(stories_dir, story_key)
        if s_path:
            try:
                text = Path(s_path).read_text(encoding="utf-8")
                current_status = (_clean(_first(text, _STATUS_RE)) or "").strip().lower()
                if current_status == "done":
                    continue
            except Exception:
                pass  # if unreadable, proceed to API check

        # AC1: query the GitLab API.
        mr_data = query_mr_state(gitlab_url, project_id, token, mr_iid)
        if mr_data is None:
            # AC5: API error — log and continue.
            sys.stderr.write(f"[specs_tracker] WARN: reconcile_pass: API error for {story_key} MR!{mr_iid} — skipped\n")
            continue

        state = mr_data.get("state", "")

        if state == "closed":
            # AC4: closed (abandoned) MR — log warning, do not mark Done.
            sys.stderr.write(f"[specs_tracker] WARN: reconcile_pass: MR!{mr_iid} for {story_key} is closed (abandoned) — left for human review\n")
            continue

        if state != "merged":
            # AC4: opened or other state — skip silently.
            continue

        # AC6: story-id guard.
        if not _story_id_guard(story_key, mr_data, branch):
            sys.stderr.write(
                f"[specs_tracker] WARN: reconcile_pass: story-id guard failed for {story_key} "
                f"vs branch={mr_data.get('source_branch','?')} description={str(mr_data.get('description',''))[:80]!r} — skipped\n"
            )
            continue

        # AC2/AC3b: emit closeout intent (ADR-0015 emit step).
        # Deduplication guard: skip if a pending (unapplied) intent already exists
        # for this story_key to prevent duplicate intents on successive polls before
        # apply_closeout runs.
        existing_pending = load_pending_intents(intents_path)
        if any(r.get("story_key") == story_key for r in existing_pending):
            continue

        intent = {
            "story_key": story_key,
            "target_status": "Done",
            "mr_iid": mr_iid,
            "mr_url": mr_url,
            "merge_commit_sha": mr_data.get("merge_commit_sha"),
            "delivery_date": datetime.now(timezone.utc).date().isoformat(),
        }
        # Include cost/tokens from the ledger if available (look in the plain
        # dispatch records; the intent carries what we know at reconcile time).
        emit_closeout_intent(intents_path, intent)
        emitted += 1

    return emitted


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="specs_tracker")
    sub = ap.add_subparsers(dest="cmd", required=True)

    r = sub.add_parser("ready")
    r.add_argument("--stories-dir", required=True)
    r.add_argument("--agents-dir", required=True)
    r.add_argument("--ready-status", required=True)
    r.add_argument("--state-file", default=None)
    r.add_argument(
        "--require-label", default="",
        help="Opt-in label gate (ADR-0010 §3). Only stories carrying this label "
             "are dispatched. Set to empty string to disable.",
    )

    pa = sub.add_parser("path")
    pa.add_argument("--stories-dir", required=True)
    pa.add_argument("--key", required=True)

    mk = sub.add_parser("mark")
    mk.add_argument("--path", required=True)
    mk.add_argument("--status", required=True)

    rec = sub.add_parser("record")
    rec.add_argument("--path", required=True)
    rec.add_argument("--state-file", required=True)
    rec.add_argument(
        "--content-hash", default=None,
        help="Pre-captured SHA-256 hex digest to record instead of computing it from --path "
             "(STORY-0047 AC1/AC3 durable dequeue fix).",
    )

    hsh = sub.add_parser("hash")
    hsh.add_argument("--path", required=True, help="Path to the file to hash.")

    ledger_cmd = sub.add_parser("ledger")
    ledger_cmd.add_argument("--story-key", required=True)
    ledger_cmd.add_argument("--ledger-file", required=True)
    ledger_cmd.add_argument("--stage", default="Development")
    ledger_cmd.add_argument("--cost-usd", default=None)
    ledger_cmd.add_argument("--tokens", default=None)

    # STORY-0048: parse cost from a claude --output-format json result file
    pc = sub.add_parser("parse-cost")
    pc.add_argument("--result-file", required=True, help="Path to JSON result file from claude -p --output-format json")
    pc.add_argument("--prices-file", default=None, help="Path to model-prices.json (optional)")

    # STORY-0030: status transition event record
    trans_cmd = sub.add_parser("transition")
    trans_cmd.add_argument("--story-key", required=True)
    trans_cmd.add_argument("--ledger-file", required=True)
    trans_cmd.add_argument("--from-status", required=True)
    trans_cmd.add_argument("--to-status", required=True)
    trans_cmd.add_argument("--actor", required=True)
    trans_cmd.add_argument("--stage", default="development")
    trans_cmd.add_argument("--actor-kind", default="agent")
    trans_cmd.add_argument("--cost-usd", default=None)
    trans_cmd.add_argument("--tokens", default=None)

    # STORY-0054: record a branch+MR IID/URL after dispatch
    rec_mr_cmd = sub.add_parser("record-mr")
    rec_mr_cmd.add_argument("--story-key", required=True)
    rec_mr_cmd.add_argument("--ledger-file", required=True)
    rec_mr_cmd.add_argument("--branch", required=True)
    rec_mr_cmd.add_argument("--mr-iid", required=True, type=int)
    rec_mr_cmd.add_argument("--mr-url", required=True)

    # STORY-0054: run the reconcile pass (emit closeout intents for merged MRs)
    recon_cmd = sub.add_parser("reconcile")
    recon_cmd.add_argument("--ledger-file", required=True)
    recon_cmd.add_argument("--intents-file", required=True)
    recon_cmd.add_argument("--gitlab-url", required=True)
    recon_cmd.add_argument("--project-id", required=True)
    recon_cmd.add_argument("--token", required=True)
    recon_cmd.add_argument("--stories-dir", required=True)

    # STORY-0054: apply pending closeout intents to story files
    apply_cmd = sub.add_parser("apply-closeout")
    apply_cmd.add_argument("--intents-file", required=True)
    apply_cmd.add_argument("--stories-dir", required=True)

    args = ap.parse_args(argv)

    if args.cmd == "ready":
        known = discover_agents(args.agents_dir)
        dispatched = load_dispatched(args.state_file) if args.state_file else {}
        for s in ready_stories(
            args.stories_dir, args.ready_status, known,
            dispatched=dispatched,
            require_label=args.require_label or None,
        ):
            print(f"{s['key']}\t{s['assignee']}")
        return 0
    if args.cmd == "path":
        p = story_path(args.stories_dir, args.key)
        if p is None:
            return 1
        print(p)
        return 0
    if args.cmd == "mark":
        mark_status(args.path, args.status)
        return 0
    if args.cmd == "record":
        s = parse_story(args.path)
        # STORY-0047 AC1/AC3: use the pre-dispatch hash when provided so the
        # recorded hash always matches the Sprint Ready content that sync_specs
        # restores — not the post-dispatch "In Progress" content.
        h = args.content_hash if args.content_hash else content_hash_for(args.path)
        record_dispatched(args.state_file, s["key"], h)
        return 0
    if args.cmd == "hash":
        # STORY-0047 AC1: print SHA-256 hex digest for watch.sh to capture
        # before dispatching (pre-dispatch hash for durable dequeue).
        print(content_hash_for(args.path))
        return 0
    if args.cmd == "ledger":
        append_ledger(
            args.ledger_file,
            args.story_key,
            stage=args.stage,
            cost_usd=args.cost_usd,
            tokens=args.tokens,
        )
        return 0
    if args.cmd == "transition":
        append_transition(
            args.ledger_file,
            args.story_key,
            from_status=args.from_status,
            to_status=args.to_status,
            actor=args.actor,
            stage=args.stage,
            actor_kind=args.actor_kind,
            cost_usd=args.cost_usd,
            tokens=args.tokens,
        )
        return 0
    if args.cmd == "parse-cost":
        result_path = Path(args.result_file)
        if not result_path.exists() or not result_path.stat().st_size:
            print(json.dumps({"cost_usd": None, "tokens": None, "label": "unknown USD / unknown tokens", "is_estimate": False}))
            return 0
        try:
            result = json.loads(result_path.read_text(encoding="utf-8"))
        except Exception:
            print(json.dumps({"cost_usd": None, "tokens": None, "label": "unknown USD / unknown tokens", "is_estimate": False}))
            return 0
        prices = load_model_prices(args.prices_file) if args.prices_file else None
        out = parse_cost_from_result(result, prices)
        print(json.dumps(out))
        return 0
    if args.cmd == "record-mr":
        record_dispatch_mr(
            args.ledger_file,
            args.story_key,
            branch=args.branch,
            mr_iid=args.mr_iid,
            mr_url=args.mr_url,
        )
        return 0
    if args.cmd == "reconcile":
        count = reconcile_pass(
            ledger_path=args.ledger_file,
            intents_path=args.intents_file,
            gitlab_url=args.gitlab_url,
            project_id=args.project_id,
            token=args.token,
            stories_dir=args.stories_dir,
        )
        print(f"reconcile: {count} new intent(s) emitted")
        return 0
    if args.cmd == "apply-closeout":
        apply_closeout_intents(args.intents_file, args.stories_dir)
        return 0
    return 2


def main(argv=None) -> int:
    """Public entrypoint — delegates to _main().

    Retained for importability as artisyn_catalog_schema.runner.specs_tracker.main()
    (STORY-0056 AC2).
    """
    return _main(argv)


if __name__ == "__main__":
    raise SystemExit(_main())
