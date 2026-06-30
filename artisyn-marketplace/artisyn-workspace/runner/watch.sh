#!/usr/bin/env bash
#
# artisyn-workspace-runner WATCH mode — long-running auto-poller.
#
# Every POLL_INTERVAL seconds query the configured tracker for tickets that a
# human has explicitly authorized for autonomous processing (ticket is at the
# Development entry status AND carries the require-label AND is assigned to a
# known agent) and run the configured lead agent dispatch for each, sequentially.
#
# Started as the artisyn-watch compose service:
#   docker compose up -d artisyn-watch
# Or via the slash-command watch mode:
#   /artisyn-workspace:run --watch [--tracker specs|jira|gitlab]
#
# Tracker design (ADR-0008 — GitLab-first, thin pluggable seam; ADR-0009 — specs
# backend; ADR-0010 — workflow status model and stage→status mapping):
#   - TRACKER_TYPE=gitlab  — GitLab REST API (GET /projects/:id/issues?...)
#   - TRACKER_TYPE=specs   — local specs/STORIES/*.md (ADR-0009)
#   - TRACKER_TYPE=jira    — reserved; seam present, no driver in v1 (STORY-0026 deferred)
#
# HITL gate (ADR-0010 §3):
#   For the specs backend: ticket status == TRACKER_READY_STATUS AND its Assignee
#   names a known agent AND (when TRACKER_REQUIRE_LABEL is set) the ticket carries
#   that label. All three conditions must hold (STORY-0025).
#
# Stage-aware dispatch (ADR-0010 §2, STORY-0025):
#   The dispatch prompt names the story, the stage (Development), the assignee,
#   and the configured transition statuses (In Progress → In Review). It instructs
#   the lead to delegate implementation test-first and open a PR to main.
#
# KPI signals (STORY-0027):
#   The dispatch prompt instructs the agent to emit *[<agent>]* prefix and
#   Cost: X USD / Y tokens line (matching workspace-cg collect_status_kpi.py).
#   After a successful dispatch, a JSONL record is appended to SPECS_LEDGER_FILE.
#
# Dequeue:
#   Natural — content hash recorded so an unchanged already-dispatched story is
#   not re-dispatched. An in-process INFLIGHT guard prevents re-dispatch of the
#   same key within the container's lifetime.
#
# Daemon resilience:
#   NOT `set -e` — one bad poll or dispatch is logged and the loop continues.
set -uo pipefail
source "${RUNNER_LIB:-/usr/local/bin/lib.sh}"

# ---------------------------------------------------------------------------
# Configuration — override in runner/.env (nothing engagement-specific here)
# ---------------------------------------------------------------------------

POLL_INTERVAL="${POLL_INTERVAL:-300}"          # seconds between polls

# Tracker type: "specs" | "gitlab" | "jira" (jira: seam only, no driver in v1)
TRACKER_TYPE="${TRACKER_TYPE:-gitlab}"

# GitLab: base URL, project numeric ID (or URL-encoded path), ready label,
# assignee account ID (numeric), and personal / project access token.
GITLAB_URL="${GITLAB_URL:-https://gitlab.dataart.com}"
GITLAB_PROJECT_ID="${GITLAB_PROJECT_ID:-}"           # REQUIRED: numeric ID or URL-encoded path
TRACKER_READY_LABEL="${TRACKER_READY_LABEL:-ready-for-agent}"
TRACKER_ASSIGNEE_ID="${TRACKER_ASSIGNEE_ID:-}"       # REQUIRED: GitLab user ID of the runner account
GITLAB_TOKEN="${GITLAB_TOKEN:-}"                     # scoped api/read_api token

# Maximum issues to fetch per poll (keep low to avoid pagination complexity).
TRACKER_MAX_RESULTS="${TRACKER_MAX_RESULTS:-50}"

# Specs tracker (TRACKER_TYPE=specs): scan local specs/ story files instead of a
# remote tracker. The HITL gate is Status==TRACKER_READY_STATUS AND Assignee names
# a generated agent AND (when set) the story carries TRACKER_REQUIRE_LABEL (ADR-0010 §3).
SPECS_STORIES_DIR="${SPECS_STORIES_DIR:-specs/STORIES}"
SPECS_AGENTS_DIR="${SPECS_AGENTS_DIR:-.claude/agents}"
# Default is the legacy gate value for backward compat (ADR-0009/ADR-0010).
# The workspace renders the configured Development entry status into the workspace
# .env.example and the compose environment block so the watch loop sees the right
# value from workspace-profile.yaml — no status name is baked here.
TRACKER_READY_STATUS="${TRACKER_READY_STATUS:-Ready-for-agent}"
# Use ${VAR-default} (no colon) so an explicitly-set empty string disables the label gate.
TRACKER_REQUIRE_LABEL="${TRACKER_REQUIRE_LABEL-adlc-auto}"
SPECS_TRACKER_BIN="${SPECS_TRACKER_BIN:-/usr/local/bin/specs_tracker.py}"
SPECS_STATE_FILE="${SPECS_STATE_FILE:-/artisyn/state/dispatched.json}"
SPECS_LEDGER_FILE="${SPECS_LEDGER_FILE:-/artisyn/state/dispatch-ledger.jsonl}"

# STORY-0054: closeout intents file (agent-comms dir; writable output mount, ADR-0007/ADR-0015).
CLOSEOUT_INTENTS_FILE="${CLOSEOUT_INTENTS_FILE:-/artisyn/state/closeout-intents.jsonl}"
# STORY-0054: set to 0 to disable MR recording after dispatch.
MR_RECORD_ENABLED="${MR_RECORD_ENABLED:-1}"

# Canonical status names (ADR-0010 §1) — read from env vars rendered by
# workspace.py generate from automation.statuses.* in workspace-profile.yaml.
# Defaults match the cg vocabulary with BA Review naming.
STATUS_NEW="${STATUS_NEW:-New}"
STATUS_TRIAGE="${STATUS_TRIAGE:-Triage}"
STATUS_BA_REVIEW="${STATUS_BA_REVIEW:-BA Review}"
STATUS_SPRINT_READY="${STATUS_SPRINT_READY:-Sprint Ready}"
STATUS_IN_PROGRESS="${STATUS_IN_PROGRESS:-In Progress}"
STATUS_IN_REVIEW="${STATUS_IN_REVIEW:-In Review}"
STATUS_QA_READY="${STATUS_QA_READY:-QA Ready}"
STATUS_QA_IN_PROGRESS="${STATUS_QA_IN_PROGRESS:-QA In Progress}"
STATUS_UAT="${STATUS_UAT:-UAT}"
STATUS_READY_FOR_DEPLOY="${STATUS_READY_FOR_DEPLOY:-Ready for Deploy}"
STATUS_DONE="${STATUS_DONE:-Done}"
STATUS_DISCARDED="${STATUS_DISCARDED:-Discarded}"

# Dry-run dispatch: validate detect→mark loop without firing claude (e2e/testing).
RUNNER_DISPATCH_DRYRUN="${RUNNER_DISPATCH_DRYRUN:-0}"

# STORY-0047 AC4: Maximum wall-clock for a single dispatch (empty = no timeout).
# Set to seconds, e.g. DISPATCH_TIMEOUT=3600 for a 1-hour cap.
DISPATCH_TIMEOUT="${DISPATCH_TIMEOUT:-}"

# ---------------------------------------------------------------------------
# Startup gate info — call once after validation to surface the active gate
# ---------------------------------------------------------------------------

# Emit the active tracker + gate configuration so the operator can confirm
# what the loop will pick up on first poll (STORY-0024 AC3).
log_watch_gate_info() {
  case "$TRACKER_TYPE" in
    specs)
      local label_info
      if [ -n "${TRACKER_REQUIRE_LABEL:-}" ]; then
        label_info="label='${TRACKER_REQUIRE_LABEL}'"
      else
        label_info="label=<none — disabled>"
      fi
      log "tracker=specs | entry-status='${TRACKER_READY_STATUS}' | ${label_info} | interval=${POLL_INTERVAL}s"
      ;;
    gitlab)
      log "tracker=gitlab | url=${GITLAB_URL} | project=${GITLAB_PROJECT_ID} | label='${TRACKER_READY_LABEL}' | assignee=${TRACKER_ASSIGNEE_ID} | interval=${POLL_INTERVAL}s"
      ;;
    jira)
      log "tracker=jira | (no driver in v1 — STORY-0026 deferred)" >&2
      ;;
    *)
      log "tracker=${TRACKER_TYPE} | (unknown)" >&2
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Tracker: thin seam — one function per tracker type.
# Returns issue identifiers (iid or key), one per line, oldest first.
# ---------------------------------------------------------------------------

# Build the GitLab REST query URL — deterministic, unit-testable, no I/O.
# Usage: gitlab_query_url
# Outputs the full URL with query parameters (token NOT included).
gitlab_query_url() {
  local base="${GITLAB_URL%/}"
  local project
  # URL-encode the project path if it contains slashes; numeric IDs need no encoding.
  project=$(python3 -c "
import sys, urllib.parse
raw = sys.argv[1]
# If it's purely numeric, pass through; otherwise percent-encode each path segment
# but keep the slashes (GitLab accepts %2F in project IDs in newer versions), or
# alternatively just pass the whole thing URL-encoded for the path component.
# Simplest safe approach: encode the entire string as a single value.
print(urllib.parse.quote(raw, safe=''))
" "${GITLAB_PROJECT_ID}")
  echo "${base}/api/v4/projects/${project}/issues?labels=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "${TRACKER_READY_LABEL}")&assignee_id=${TRACKER_ASSIGNEE_ID}&state=opened&order_by=created_at&sort=asc&per_page=${TRACKER_MAX_RESULTS}"
}

# List ready+assigned GitLab issue IIDs via REST (ADR-0008 REST fallback path,
# used here because gitlab-da MCP cannot be driven from an unattended shell loop).
# Tokens are redacted in logs; the token is passed via HTTP header, not the URL.
gitlab_ready_keys() {
  local url
  url="$(gitlab_query_url)"
  # Call REST; pass token in header (never in URL) to avoid credential leakage in logs.
  curl -s -w $'\n%{http_code}' \
    -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    "${url}" \
  | python3 -c '
import sys, json
raw = sys.stdin.read().rstrip("\n")
body, _, code = raw.rpartition("\n")
if code.strip() != "200":
    sys.stderr.write("[runner] GitLab issues REST HTTP %s: %s\n" % (code.strip(), body[:300]))
    sys.exit(0)
try:
    issues = json.loads(body)
except Exception:
    sys.stderr.write("[runner] GitLab issues REST: unparseable response\n")
    sys.exit(0)
if not isinstance(issues, list):
    sys.stderr.write("[runner] GitLab issues REST: expected list, got %s\n" % type(issues).__name__)
    sys.exit(0)
for issue in issues:
    iid = issue.get("iid")
    if iid is not None:
        print(str(iid))
'
}

# List ready+assigned story keys (one per line) from local specs/ files.
# Passes --require-label so the gate is config-driven, not hardcoded (STORY-0025).
specs_ready_keys() {
  python3 "$SPECS_TRACKER_BIN" ready \
    --stories-dir "$SPECS_STORIES_DIR" \
    --agents-dir "$SPECS_AGENTS_DIR" \
    --ready-status "$TRACKER_READY_STATUS" \
    --state-file "$SPECS_STATE_FILE" \
    ${TRACKER_REQUIRE_LABEL:+--require-label "$TRACKER_REQUIRE_LABEL"} \
  | cut -f1
}

# Resolve a story file path for a key (empty if not found).
specs_story_path() {
  python3 "$SPECS_TRACKER_BIN" path \
    --stories-dir "$SPECS_STORIES_DIR" --key "$1" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# STORY-0047 AC2 — No-push failure detection helpers
# ---------------------------------------------------------------------------

# Print all remote-tracking branch names from every git repo under CODE_DIR.
# One branch refname per line. Non-fatal: repos that fail are silently skipped.
# Used by STORY-0054 MR detection (specs_find_new_branch).
_snapshot_remote_branches() {
  local code_dir="${CODE_DIR:-/artisyn/code-repo}"
  for git_dir in "${code_dir}"/*/.git; do
    [ -d "$git_dir" ] || continue
    local repo_dir="${git_dir%/.git}"
    git -C "$repo_dir" branch -r --format='%(refname:short)' 2>/dev/null || true
  done
}

# Return 0 (true) if any line from _snapshot_remote_branches is absent from
# before_file (i.e. a new branch was pushed since the snapshot was taken).
# Return 1 (false) if no new branch was found.
_has_new_remote_branch() {
  local before_file="$1"
  local found_new=1   # default: no new branch
  while IFS= read -r branch; do
    [ -z "$branch" ] && continue
    if ! grep -qxF "$branch" "$before_file" 2>/dev/null; then
      found_new=0
      break
    fi
  done < <(_snapshot_remote_branches)
  return "$found_new"
}

# ---------------------------------------------------------------------------
# BUG-0057 — Robust push detection via direct origin query
# ---------------------------------------------------------------------------
#
# The before/after _snapshot_remote_branches diff (STORY-0047) is fragile when
# BUG-0053's pre-dispatch refresh_code_repos has run: the container's git clone
# (initialised via `git clone` which fetches ALL remote refs) may already have
# the agent's working branch in its remote-tracking refs if that branch existed
# on origin from a previous container session.  In that case the branch name
# never appears "new" even though the agent pushed to it (advancing the SHA).
#
# Fix: use git ls-remote --heads to query origin DIRECTLY — bypassing local
# remote-tracking ref state — and compare "<sha> origin/<branch>" tuples.  This
# detects both new branches (new refname) AND advanced branches (same refname,
# different SHA), making push detection robust to the pre-dispatch fetch.
#
# _snapshot_origin_state: query origin live; output "<sha> origin/<branch>"
#   per line, sorted.  Non-fatal per repo.
# _origin_has_push: return 0 when any (sha, branch) pair in after_file differs
#   from before_file; return 1 when origin is unchanged.
# ---------------------------------------------------------------------------

# Query origin heads directly and emit "<sha> origin/<branch>" per line, sorted.
# Non-fatal: repos that fail (e.g. network error) are silently skipped.
_snapshot_origin_state() {
  local code_dir="${CODE_DIR:-/artisyn/code-repo}"
  for git_dir in "${code_dir}"/*/.git; do
    [ -d "$git_dir" ] || continue
    local repo_dir="${git_dir%/.git}"
    # git ls-remote --heads outputs "<sha>\trefs/heads/<branch>".
    # Reformat to "<sha> origin/<branch>" for a compact, grep-able key.
    git -C "$repo_dir" ls-remote --heads origin 2>/dev/null \
      | sed 's|	refs/heads/| origin/|' \
      | sort \
      || true
  done
}

# Return 0 (true) if origin's state changed between before_file and after_file.
# A change is: any "<sha> origin/<branch>" pair in after_file that is absent
# from before_file (covers both new branches AND SHA-advanced existing branches).
# Return 1 (false) when both files represent the same state.
_origin_has_push() {
  local before_file="$1" after_file="$2"
  local found=1   # default: no change
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! grep -qxF "$line" "$before_file" 2>/dev/null; then
      found=0
      break
    fi
  done < "$after_file"
  return "$found"
}

# Stage-aware dispatch prompt for a specs story (STORY-0025, STORY-0027, ADR-0010,
# ADR-0018).
#
# Instructs the lead to:
#   1. Delegate implementation to the story's assigned agent (test-first).
#   2. Consult lead/ba/domain as needed.
#   3. Transition the story: entry_status → In Progress → In Review.
#   4. MR-aware dispatch (ADR-0018 / STORY-0061): before branching, detect whether an
#      open MR already exists for the story; if so REUSE its branch and amend the MR
#      (no new branch, no new PR); otherwise take the fresh new-branch + new-PR path.
#   5. Open/update a PR to main (merge stays human; ADR-0010 §4).
#   6. Emit KPI-compatible signals in the PR description (STORY-0027):
#        *[<agent>]* prefix line
#        Cost: X USD / Y tokens line
specs_dispatch_prompt() {
  local key="$1" path assignee entry_status in_progress in_review
  path="$(specs_story_path "$key")"
  assignee="$(python3 "$SPECS_TRACKER_BIN" ready \
    --stories-dir "$SPECS_STORIES_DIR" --agents-dir "$SPECS_AGENTS_DIR" \
    --ready-status "$TRACKER_READY_STATUS" \
    ${TRACKER_REQUIRE_LABEL:+--require-label "$TRACKER_REQUIRE_LABEL"} \
    | awk -F'\t' -v k="$key" '$1==k{print $2}')"
  entry_status="${TRACKER_READY_STATUS}"
  in_progress="${STATUS_IN_PROGRESS:-In Progress}"
  in_review="${STATUS_IN_REVIEW:-In Review}"

  cat <<PROMPT
Stage: Development — dispatch story ${key} (file: ${path}).

Assignee: ${assignee}. Delegate implementation to that agent.
Consulting artisyn-lead, artisyn-ba, artisyn-domain as needed for clarification.

Workflow (ADR-0010 §4):
  1. Transition story from '${entry_status}' → '${in_progress}' (mark work started).
  2. MR-AWARE BRANCHING (ADR-0018): before creating any branch, first check whether
     an OPEN merge request already exists for this story. Detect it with the GitLab
     MR tooling — an open merge request whose source branch name contains the story
     key '${key}', or whose description carries a 'Refs:' or 'Closes' line naming
     '${key}' (the STORY-0054 story↔MR binding). This distinguishes a rework re-arm
     (the story was re-set to '${entry_status}' after review) from fresh work.
       a. IF an open merge request EXISTS → REUSE it (rework). Do NOT create a new branch
          and do NOT open a new PR. Check out its existing source branch:
            git fetch origin
            git checkout <existing-mr-source-branch>
          Implement the rework on this branch; you will push back to it to UPDATE
          the existing MR.
       b. IF NO open merge request exists → FRESH work. Create a new working branch
          from the LATEST origin/<base-branch> — NOT from a stale local branch
          (BUG-0053):
            git fetch origin
            git checkout -b <branch-name> origin/<base-branch>
          where <base-branch> is the repo's configured default (usually 'main').
  3. Implement test-first: write failing tests, then implement, then make them pass.
  4. ISOLATED code review (gate — before any PR): once the implementation is
     complete and tests pass, dispatch a FRESH code-review subagent via the Agent
     tool — a clean, isolated context, NOT your own — over the working diff, at
     high effort, using the 'code-review' skill. Then act on its findings:
       - Fix EVERY Critical and High finding, then re-run the tests.
       - Record Medium/Low findings in the PR description (non-blocking).
     Run at most TWO review→fix rounds:
       - After round 2: if no Critical findings remain, proceed to the PR (record
         any remaining High/Medium/Low as non-blocking notes in the PR description).
       - If a Critical finding still remains after round 2, stop with
         'BLOCKED: <reason>' and do NOT open a PR.
     Do NOT proceed to the PR while any Critical finding remains after the first
     round. (Bounds the loop so a story can't iterate indefinitely.)
  5. PRE-MR REBASE (BUG-0053): before pushing, rebase your working branch onto the
     latest origin/<base-branch> to ensure the MR is individually mergeable:
       git fetch origin
       git rebase origin/<base-branch>
     If the rebase hits a conflict you cannot cleanly resolve, STOP immediately
     with 'BLOCKED: rebase conflict on <files> — cannot open a clean MR' and do
     NOT push. Do NOT commit a conflicted state.
  6. Transition story from '${in_progress}' → '${in_review}'.
  7. PUBLISH (MR-aware, ADR-0018):
       - REUSE path (an open MR existed in step 2): push to the EXISTING MR's source
         branch — this UPDATES the existing MR in place. Do NOT open a new PR. Add a
         note to the existing MR summarising the rework.
       - FRESH path (no open MR in step 2): push the new branch and open a new PR to
         main.
     Merge is HUMAN-GATED in both paths (strong-HITL; ADR-0010 §4).

In the PR description, emit KPI-compatible signals (STORY-0027):
  *[${assignee}]*
  Cost: X USD / Y tokens
  Code review: <C> Critical / <H> High fixed; <M> Medium / <L> Low noted

The agent must replace X and Y with the actual token cost figures from the session.
If cost data is unavailable, emit: Cost: unknown USD / unknown tokens
PROMPT
}

# Resolve the assignee for a ready story key (the actor for transition events).
specs_assignee_for() {
  python3 "$SPECS_TRACKER_BIN" ready \
    --stories-dir "$SPECS_STORIES_DIR" --agents-dir "$SPECS_AGENTS_DIR" \
    --ready-status "$TRACKER_READY_STATUS" \
    ${TRACKER_REQUIRE_LABEL:+--require-label "$TRACKER_REQUIRE_LABEL"} \
    2>/dev/null | awk -F'\t' -v k="$1" '$1==k{print $2}'
}

# Record one status-transition KPI event (STORY-0030, ADR-0012 §3). Non-fatal.
specs_record_transition() {
  local key="$1" from="$2" to="$3" assignee
  assignee="$(specs_assignee_for "$key")"
  python3 "$SPECS_TRACKER_BIN" transition \
    --story-key "$key" \
    --ledger-file "${SPECS_LEDGER_FILE}" \
    --from-status "$from" --to-status "$to" \
    --actor "${assignee:-${LEAD_AGENT:-unknown}}" --actor-kind agent \
    --stage "development" \
  2>/dev/null || log "WARN: failed to append transition ${from}->${to} for ${key} (non-fatal)"
}

# Before a real dispatch: record entry_status -> in_progress so In-Progress dwell
# is measured across the dispatch. Skipped in dryrun (no real work happened).
specs_on_dispatch_start() {
  [ "${RUNNER_DISPATCH_DRYRUN:-0}" = "1" ] && return 0
  specs_record_transition "$1" "${TRACKER_READY_STATUS}" "${STATUS_IN_PROGRESS:-In Progress}"
}

# After a successful dispatch, persist the dispatch state (key -> content hash of
# the story AS DETECTED BEFORE dispatch) to the named volume so the dequeue survives
# container restarts. Also append a JSONL record to the dispatch ledger (STORY-0027)
# and the in_progress -> in_review transition event (STORY-0030).
#
# STORY-0047 AC1/AC3 — durable dequeue root-cause fix:
#   Pass the pre-dispatch hash (Sprint Ready content) as $2 so the recorded hash
#   matches the content that sync_specs restores, not the post-dispatch "In Progress"
#   content. When $2 is empty, the hash is computed from the current file (old behaviour).
# STORY-0054: also records the new branch + MR ref to the ledger when MR_RECORD_ENABLED=1.
specs_on_dispatched() {
  local key="$1" pre_dispatch_hash="${2:-}" path assignee
  path="$(specs_story_path "$key")"
  [ -n "$path" ] || return 0
  assignee="$(specs_assignee_for "$key")"
  mkdir -p "$(dirname "$SPECS_STATE_FILE")"
  if [ -n "$pre_dispatch_hash" ]; then
    python3 "$SPECS_TRACKER_BIN" record --path "$path" --state-file "$SPECS_STATE_FILE" \
      --content-hash "$pre_dispatch_hash"
  else
    python3 "$SPECS_TRACKER_BIN" record --path "$path" --state-file "$SPECS_STATE_FILE"
  fi
  # Append a KPI ledger record (STORY-0027 + STORY-0048): timestamp, story key, stage,
  # and cost/token data from the parsed JSON result (non-null when available).
  local _cost_arg="" _tokens_arg=""
  [ -n "${__dispatch_cost_usd:-}" ] && _cost_arg="--cost-usd ${__dispatch_cost_usd}"
  [ -n "${__dispatch_tokens:-}" ] && _tokens_arg="--tokens ${__dispatch_tokens}"
  # shellcheck disable=SC2086
  python3 "$SPECS_TRACKER_BIN" ledger \
    --story-key "$key" \
    --ledger-file "${SPECS_LEDGER_FILE}" \
    --stage "Development" \
    ${_cost_arg} ${_tokens_arg} \
  2>/dev/null || log "WARN: failed to append ledger record for ${key} (non-fatal)"
  # Record the completion transition (STORY-0030 + STORY-0048): pass real cost.
  local _trans_cost_arg="" _trans_tokens_arg=""
  [ -n "${__dispatch_cost_usd:-}" ] && _trans_cost_arg="--cost-usd ${__dispatch_cost_usd}"
  [ -n "${__dispatch_tokens:-}" ] && _trans_tokens_arg="--tokens ${__dispatch_tokens}"
  [ "${RUNNER_DISPATCH_DRYRUN:-0}" = "1" ] || \
    specs_record_transition "$key" "${STATUS_IN_PROGRESS:-In Progress}" "${STATUS_IN_REVIEW:-In Review}"
  # STORY-0054: record the new branch + MR ref (non-fatal, gated by MR_RECORD_ENABLED
  # and requires GITLAB_TOKEN, GITLAB_URL, GITLAB_PROJECT_ID to be non-empty).
  if [ "${MR_RECORD_ENABLED:-1}" = "1" ] && [ "${RUNNER_DISPATCH_DRYRUN:-0}" != "1" ] \
     && [ -n "${GITLAB_TOKEN:-}" ] && [ -n "${GITLAB_URL:-}" ] && [ -n "${GITLAB_PROJECT_ID:-}" ]; then
    local new_branch mr_iid mr_url
    new_branch="$(specs_find_new_branch "${__before_snap_for_mr:-}" 2>/dev/null || true)"
    # BUG-0064: strip the "origin/" prefix if specs_find_new_branch returned a
    # remote-tracking ref name.  Both specs_lookup_mr and specs_record_mr must
    # receive the bare branch name; specs_lookup_mr also strips it internally as a
    # defence-in-depth measure, but the canonical strip lives here so the bare name
    # is recorded in the ledger as well.
    new_branch="${new_branch#origin/}"
    if [ -n "$new_branch" ]; then
      read -r mr_iid mr_url < <(specs_lookup_mr "$new_branch" 2>/dev/null || true)
      if [ -n "$mr_iid" ]; then
        specs_record_mr "$key" "$new_branch" "$mr_iid" "$mr_url"
      else
        log "WARN: dispatch #${key}: new branch '${new_branch}' found but no open MR yet — record-mr skipped (non-fatal)" >&2
      fi
    fi
  fi
}

# ---------------------------------------------------------------------------
# STORY-0054 — Branch detection, MR lookup, MR record, reconcile/apply
# ---------------------------------------------------------------------------

# Print the first new or SHA-advanced remote branch name that appeared since the
# before-snapshot.  before_snap_file: path to the file written by
# _snapshot_remote_branches before dispatch (branch names like "origin/<branch>").
#
# BUG-0057: primary path uses _snapshot_origin_state (git ls-remote --heads) to
# detect both NEW branches and ADVANCED existing branches (same name, different
# SHA).  _snapshot_origin_state outputs "<sha> origin/<branch>" per line.  We
# compare the branch name part ("origin/<branch>") against before_file to detect:
#   (a) branch name NOT in before_file → new branch → push detected
#   (b) branch name IS in before_file → check if the SHA changed → push detected
# The branch name (with "origin/" prefix) is returned so specs_lookup_mr can query
# GitLab for the open MR on that source branch.
#
# Fallback (when ls-remote output is empty, e.g. origin unreachable): fall back to
# the original _snapshot_remote_branches diff so a transient network error does not
# suppress MR recording.
#
# Empty output when before_snap_file is absent or no new/advanced branch was found.
specs_find_new_branch() {
  local before_file="${1:-}"
  [ -n "$before_file" ] && [ -f "$before_file" ] || return 0

  # Primary path: query origin directly (BUG-0057).
  local origin_after_file
  origin_after_file="$(mktemp 2>/dev/null || true)"
  if [ -n "$origin_after_file" ]; then
    _snapshot_origin_state > "$origin_after_file" 2>/dev/null || true
  fi

  if [ -n "$origin_after_file" ] && [ -s "$origin_after_file" ]; then
    # before_file contains "origin/<branch>" lines (from _snapshot_remote_branches).
    # origin_after_file contains "<sha> origin/<branch>" lines.
    # For each after-line, extract "origin/<branch>" and compare to before_file:
    #   - if "origin/<branch>" is NOT in before_file → new branch → report it
    #   - if "origin/<branch>" IS in before_file, the branch existed pre-dispatch;
    #     check SHA change by looking for "<sha> origin/<branch>" absence from a
    #     sha-keyed before-state (we don't have SHAs in before_file, so any branch
    #     in origin_after that was already in before_file by name must be treated
    #     as possibly-advanced — report it only if its line changed vs. origin_snap
    #     which is the companion ls-remote before-snapshot in do_dispatch).
    # Note: __before_snap_for_mr (before_file here) is branch-name-only; we cannot
    # detect SHA advances from it alone.  New-branch detection is sufficient for MR
    # recording (the MR is new per-dispatch, so the branch must be new to this dispatch).
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      # line format: "<sha> origin/<branch>"
      local branch_with_remote
      branch_with_remote="${line#* }"   # "origin/<branch>"
      # If this branch name was NOT in before_file, it's a new branch pushed during
      # this dispatch — report it for MR lookup.
      if ! grep -qxF "$branch_with_remote" "$before_file" 2>/dev/null; then
        rm -f "$origin_after_file"
        printf '%s\n' "$branch_with_remote"
        return 0
      fi
    done < "$origin_after_file"
    rm -f "$origin_after_file"
    return 0
  fi

  # Fallback: local remote-tracking ref diff (STORY-0047 original approach).
  rm -f "$origin_after_file"
  _snapshot_remote_branches 2>/dev/null | while IFS= read -r branch; do
    [ -z "$branch" ] && continue
    if ! grep -qxF "$branch" "$before_file" 2>/dev/null; then
      printf '%s\n' "$branch"
      break
    fi
  done
}

# Query GitLab for an MR whose source_branch matches the given branch.
# Prints "<iid> <url>" on success, nothing if not found or on error.
# Token passed via PRIVATE-TOKEN header — never in the URL (ADR-0008).
#
# BUG-0064: strip any "origin/" prefix from the branch name before querying
# GitLab.  specs_find_new_branch returns the remote-tracking ref name
# ("origin/<branch>") but GitLab's source_branch field stores the bare name.
# Also query state=all (not state=opened only) so an MR that was already
# merged before record-mr runs is still found and recorded (BUG-0064 AC2).
specs_lookup_mr() {
  local branch="$1"
  # BUG-0064: strip the "origin/" prefix if present (git remote-tracking ref
  # format) so the GitLab source_branch query uses the bare branch name.
  branch="${branch#origin/}"
  local base="${GITLAB_URL%/}"
  local project
  project="$(python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=''))" "${GITLAB_PROJECT_ID}" 2>/dev/null || true)"
  [ -n "$project" ] || return 0
  local encoded_branch
  encoded_branch="$(python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$branch" 2>/dev/null || printf '%s' "$branch")"
  # BUG-0064 AC2: query state=all so a recently-merged MR is not missed.
  local url="${base}/api/v4/projects/${project}/merge_requests?source_branch=${encoded_branch}&state=all"
  curl -s -w $'\n%{http_code}' \
    -H "PRIVATE-TOKEN: ${GITLAB_TOKEN:-}" \
    "$url" \
  | python3 -c '
import sys, json
raw = sys.stdin.read().rstrip("\n")
body, _, code = raw.rpartition("\n")
if code.strip() != "200":
    sys.exit(0)
try:
    mrs = json.loads(body)
except Exception:
    sys.exit(0)
if not isinstance(mrs, list) or not mrs:
    sys.exit(0)
mr = mrs[0]
iid = mr.get("iid", "")
url = mr.get("web_url", "")
if iid:
    print(str(iid) + " " + str(url))
' 2>/dev/null || true
}

# Record branch + MR IID/URL to the dispatch ledger (non-fatal wrapper).
specs_record_mr() {
  local key="$1" branch="$2" mr_iid="$3" mr_url="$4"
  python3 "$SPECS_TRACKER_BIN" record-mr \
    --story-key "$key" \
    --ledger-file "${SPECS_LEDGER_FILE}" \
    --branch "$branch" \
    --mr-iid "$mr_iid" \
    --mr-url "$mr_url" \
  2>/dev/null || log "WARN: failed to record MR for ${key} (non-fatal)" >&2
}

# Run the reconcile pass: query merged MRs and emit closeout intents (non-fatal).
# Called once per poll iteration from the main watch loop (specs tracker only).
specs_reconcile_pass() {
  python3 "$SPECS_TRACKER_BIN" reconcile \
    --ledger-file "${SPECS_LEDGER_FILE}" \
    --intents-file "${CLOSEOUT_INTENTS_FILE}" \
    --gitlab-url "${GITLAB_URL}" \
    --project-id "${GITLAB_PROJECT_ID:-}" \
    --token "${GITLAB_TOKEN:-}" \
    --stories-dir "${SPECS_STORIES_DIR}" \
  2>/dev/null || log "WARN: reconcile pass failed (non-fatal)" >&2
}

# Apply pending closeout intents to story files (non-fatal).
# Called once per poll iteration from the main watch loop (specs tracker only).
specs_apply_closeout() {
  python3 "$SPECS_TRACKER_BIN" apply-closeout \
    --intents-file "${CLOSEOUT_INTENTS_FILE}" \
    --stories-dir "${SPECS_STORIES_DIR}" \
  2>/dev/null || log "WARN: apply-closeout failed (non-fatal)" >&2
}

# Dispatch prompt for one issue — the lead receives the issue IID.
# Override TRACKER_DISPATCH_TEMPLATE to change the wording.
TRACKER_DISPATCH_TEMPLATE="${TRACKER_DISPATCH_TEMPLATE:-dispatch issue #%s}"

tracker_dispatch_prompt() {
  local key="$1"
  case "$TRACKER_TYPE" in
    specs) specs_dispatch_prompt "$key" ;;
    *)     printf "${TRACKER_DISPATCH_TEMPLATE}" "$key" ;;
  esac
}

# Dispatch one item via the lead, unless dry-run. Returns the dispatch rc.
# STORY-0047 AC1/AC3: sets __pre_dispatch_hash in the caller's scope on success
# (available as the second argument to tracker_on_dispatched).
do_dispatch() {
  local agent="$1" key="$2" dispatch rc before_snap origin_snap
  dispatch="$(tracker_dispatch_prompt "$key")"
  if [ "${RUNNER_DISPATCH_DRYRUN:-0}" = "1" ]; then
    log "[DRYRUN] would dispatch #${key} to ${agent}; skipping claude"
    log "[DRYRUN] prompt: ${dispatch}"
    return 0
  fi

  # STORY-0048: initialize cost globals so they're always clean for this dispatch.
  # Also create a cost-output temp file for the background-subshell (DISPATCH_TIMEOUT) path
  # so the subshell can persist cost globals before it exits (H1 fix: subshell variables
  # are silently discarded on exit; the parent reads them back after wait).
  __dispatch_cost_usd=""
  __dispatch_tokens=""
  __dispatch_cost_label="unknown USD / unknown tokens"
  local _cost_out_file
  _cost_out_file="$(mktemp)"
  # BUG-0067: dedicated rc file for the DISPATCH_TIMEOUT subshell path.
  # The subshell's last statement is 'printf ... || true' (cost-globals persistence),
  # which always exits 0 — so 'wait "$_dispatch_pid"' returns 0 regardless of
  # run_claude's real exit code.  We fix this by having the subshell write
  # run_claude's rc to _dispatch_rc_file and reading it back after wait.
  local _dispatch_rc_file
  _dispatch_rc_file="$(mktemp)"
  # RETURN trap covers _cost_out_file + _dispatch_rc_file on all exit paths (including
  # early returns below). before_snap / origin_snap have their own RETURN trap set
  # further down — the two traps chain correctly because the second trap registration
  # replaces the first in bash, so we combine them.
  trap '[ -n "${_cost_out_file:-}" ] && rm -f "${_cost_out_file}"; [ -n "${_dispatch_rc_file:-}" ] && rm -f "${_dispatch_rc_file}"; [ -n "${before_snap:-}" ] && rm -f "${before_snap}"; [ -n "${origin_snap:-}" ] && rm -f "${origin_snap}"' RETURN

  # STORY-0047 AC1: capture the pre-dispatch hash (Sprint Ready content) before
  # the dispatched agent can rewrite the story to "In Progress".
  # Scoped to specs tracker only (other trackers manage dequeue themselves).
  local story_file
  __pre_dispatch_hash=""
  if [ "${TRACKER_TYPE:-}" = "specs" ]; then
    story_file="$(specs_story_path "$key" 2>/dev/null || true)"
    if [ -n "$story_file" ] && [ -f "$story_file" ]; then
      __pre_dispatch_hash="$(python3 "$SPECS_TRACKER_BIN" hash --path "$story_file" 2>/dev/null || true)"
      # Validate: must be a 64-char lowercase hex string (SHA-256). If not, discard
      # to avoid recording a garbage value (e.g. an error message) in dispatched.json.
      if [ -n "$__pre_dispatch_hash" ] && ! [[ "$__pre_dispatch_hash" =~ ^[0-9a-f]{64}$ ]]; then
        log "WARN: pre-dispatch hash for #${key} is malformed — dequeue will use file-time hash" >&2
        __pre_dispatch_hash=""
      fi
    fi
  fi

  # STORY-0047 AC2: snapshot remote branches BEFORE dispatch to detect new pushes.
  # before_snap uses local remote-tracking refs (fast, no network); used as fallback.
  # origin_snap queries origin directly via git ls-remote (BUG-0057): captures
  # "<sha> origin/<branch>" so we can detect both new branches AND advances to
  # existing branches (the case where the agent pushes to a branch that already
  # existed on origin from a previous session — see BUG-0057 root cause).
  before_snap="$(mktemp)"
  origin_snap="$(mktemp)"
  # Belt-and-suspenders cleanup: explicit rm -f calls below cover normal paths;
  # the RETURN trap (set earlier, covering _cost_out_file, before_snap, origin_snap)
  # catches any path not guarded by an explicit rm (e.g. a signal between cleanup lines).
  _snapshot_remote_branches > "$before_snap" 2>/dev/null || true
  _snapshot_origin_state > "$origin_snap" 2>/dev/null || true

  # STORY-0047 AC4: enforce wall-clock timeout via background+watchdog.
  # timeout(1) cannot exec a shell function (it execvp's an external binary);
  # use a background process group + watchdog subshell instead.
  if [ -n "${DISPATCH_TIMEOUT:-}" ] && [ "${DISPATCH_TIMEOUT}" != "0" ]; then
    # Run run_claude in a background subshell so we can kill it by PID.
    # H1 fix: cost globals set inside the subshell are lost when it exits; persist
    # them to _cost_out_file so the parent can read them back after wait.
    # BUG-0067 fix: capture run_claude's real rc and write it to _dispatch_rc_file
    # BEFORE writing cost globals.  The last statement of the subshell ('printf ... ||
    # true') always exits 0, so 'wait "$_dispatch_pid"' cannot be trusted to return
    # run_claude's rc.  The parent reads it back from _dispatch_rc_file after wait.
    (
      run_claude "$agent" "$dispatch"
      _rc_inside=$?
      # BUG-0067: persist run_claude's real rc so the parent can read it after wait.
      printf '%s\n' "${_rc_inside}" > "${_dispatch_rc_file}" 2>/dev/null || true
      # Persist cost globals to the output file so the parent can read them after wait.
      printf '%s\n%s\n%s\n' \
        "${__dispatch_cost_usd:-}" \
        "${__dispatch_tokens:-}" \
        "${__dispatch_cost_label:-unknown USD / unknown tokens}" \
        > "${_cost_out_file}" 2>/dev/null || true
    ) &
    local _dispatch_pid=$!

    # Watchdog: after DISPATCH_TIMEOUT seconds, if the dispatch is still running,
    # log the "timed out" message and kill the process group.
    (
      sleep "$DISPATCH_TIMEOUT"
      if kill -0 "$_dispatch_pid" 2>/dev/null; then
        echo "[runner] WARN: dispatch #${key} timed out after ${DISPATCH_TIMEOUT}s — recorded as failure (STORY-0047 AC4)" >&2
        kill -TERM "$_dispatch_pid" 2>/dev/null || true
        sleep 2
        kill -KILL "$_dispatch_pid" 2>/dev/null || true
      fi
    ) &
    local _watchdog_pid=$!

    wait "$_dispatch_pid" 2>/dev/null
    local _subshell_rc=$?

    # Kill the watchdog if dispatch finished before timeout.
    kill "$_watchdog_pid" 2>/dev/null || true
    wait "$_watchdog_pid" 2>/dev/null || true

    # Read cost globals back from the subshell output file (STORY-0048 H1 fix).
    if [ -f "${_cost_out_file}" ]; then
      { IFS= read -r __dispatch_cost_usd
        IFS= read -r __dispatch_tokens
        IFS= read -r __dispatch_cost_label
      } < "${_cost_out_file}" 2>/dev/null || true
    fi

    # rc 143 = SIGTERM (timed out); rc 137 = SIGKILL (hard timeout).
    # These signal-based exit codes come from the subshell being killed by the watchdog.
    if [ "$_subshell_rc" -eq 143 ] || [ "$_subshell_rc" -eq 137 ]; then
      log "WARN: dispatch #${key} timed out after ${DISPATCH_TIMEOUT}s — recorded as failure (STORY-0047 AC4)" >&2
      rm -f "$before_snap" "$origin_snap"
      return 1
    fi

    # BUG-0067 fix: read run_claude's real rc from _dispatch_rc_file.
    # The subshell's 'printf ... || true' always exits 0, so _subshell_rc is
    # unreliable for non-signal exits.  _dispatch_rc_file was written by the
    # subshell before the cost-globals printf, and contains only run_claude's rc.
    rc="$_subshell_rc"
    if [ -f "${_dispatch_rc_file}" ] && [ -s "${_dispatch_rc_file}" ]; then
      local _rc_from_file
      IFS= read -r _rc_from_file < "${_dispatch_rc_file}" 2>/dev/null || true
      # Validate: must be an integer (the rc may be absent if the subshell was
      # killed before writing — in that case fall back to _subshell_rc).
      if [[ "${_rc_from_file}" =~ ^[0-9]+$ ]]; then
        rc="${_rc_from_file}"
      fi
    fi
  else
    run_claude "$agent" "$dispatch"
    rc=$?
  fi

  if [ "$rc" -ne 0 ]; then
    rm -f "$before_snap" "$origin_snap"
    return "$rc"
  fi

  # BUG-0057 + STORY-0047 AC2 (BUG-0050 AC3): after a clean exit, verify that the
  # agent actually pushed a branch to origin.
  #
  # Robust detection (BUG-0057): query origin directly via git ls-remote --heads
  # (stored in origin_snap_after) and compare to origin_snap (taken before dispatch,
  # also via git ls-remote).  This detects both NEW branches and SHA-ADVANCED existing
  # branches — closing the false-negative window where the agent's working branch
  # already existed on origin from a prior container session (so it was present in
  # origin_snap), but was pushed/advanced during this dispatch.
  #
  # Fallback (BUG-0050 AC3 / STORY-0047): if git ls-remote is unavailable or returns
  # empty (e.g. origin unreachable), fall back to the local remote-tracking ref diff
  # (before_snap vs _snapshot_remote_branches) so a transient network error on the
  # check itself doesn't falsely block a successful dispatch.
  #
  # Count repos first; skip the check when there are none (backward compat with
  # dryrun / no-repo setups). The `[ -d "$git_dir" ]` guard also handles the case
  # where the glob does not expand (nullglob not set) — the unexpanded literal
  # string fails the -d test, so repo_count stays 0 safely.
  local repo_count=0
  local code_dir="${CODE_DIR:-/artisyn/code-repo}"
  if [ -d "$code_dir" ]; then
    for git_dir in "${code_dir}"/*/.git; do
      [ -d "$git_dir" ] && repo_count=$((repo_count + 1))
    done
  fi

  if [ "$repo_count" -gt 0 ]; then
    local origin_snap_after
    origin_snap_after="$(mktemp)"
    _snapshot_origin_state > "$origin_snap_after" 2>/dev/null || true

    local push_detected=0
    if [ -s "$origin_snap_after" ] && [ -s "$origin_snap" ]; then
      # Primary path (BUG-0057): ls-remote before vs after.
      _origin_has_push "$origin_snap" "$origin_snap_after" && push_detected=1
    elif [ -s "$origin_snap_after" ] && [ ! -s "$origin_snap" ]; then
      # Before-snap was empty (origin unreachable before dispatch) but we have
      # after data — conservatively assume a push happened rather than blocking.
      push_detected=1
    else
      # ls-remote unavailable (both empty) — fall back to local tracking-ref diff.
      _has_new_remote_branch "$before_snap" && push_detected=1
    fi
    rm -f "$origin_snap_after"

    if [ "$push_detected" -eq 0 ]; then
      log "WARN: dispatch #${key} exited zero but no branch was pushed — recorded as failure (BUG-0050 AC3)" >&2
      rm -f "$before_snap" "$origin_snap"
      return 1
    fi
  fi

  rm -f "$before_snap" "$origin_snap"
  return 0
}

# Pre-dispatch hook: backend-specific side effects just before dispatch starts.
tracker_on_dispatch_start() {
  case "$TRACKER_TYPE" in
    specs) specs_on_dispatch_start "$1" ;;
    *)     : ;;   # gitlab: the dispatched lead transitions the issue
  esac
}

# Post-dispatch hook: backend-specific side effects after a successful dispatch.
# STORY-0047 AC1: $2 is the pre-dispatch hash (set by do_dispatch in __pre_dispatch_hash);
# passed through to specs_on_dispatched for durable dequeue correctness.
tracker_on_dispatched() {
  case "$TRACKER_TYPE" in
    specs) specs_on_dispatched "$1" "${2:-}" ;;
    *)     : ;;   # gitlab: the dispatched lead transitions the issue
  esac
}

# Wrapper: call the right tracker backend, return keys one per line.
tracker_ready_keys() {
  case "$TRACKER_TYPE" in
    gitlab) gitlab_ready_keys ;;
    specs)  specs_ready_keys ;;
    jira)
      log "ERROR: TRACKER_TYPE=jira has no driver in v1 (STORY-0026 deferred). Use specs or gitlab." >&2
      return 1
      ;;
    *)
      log "ERROR: unsupported TRACKER_TYPE=${TRACKER_TYPE}. Supported: specs, gitlab (jira: deferred)" >&2
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------

require_gitlab_config() {
  local ok=1
  if [ -z "${GITLAB_PROJECT_ID:-}" ]; then
    log "ERROR: GITLAB_PROJECT_ID is not set." >&2
    log "       Set it in runner/.env (numeric ID or URL-encoded path, e.g. 'my-group%2Fmy-repo')." >&2
    ok=0
  fi
  if [ -z "${TRACKER_ASSIGNEE_ID:-}" ]; then
    log "ERROR: TRACKER_ASSIGNEE_ID is not set." >&2
    log "       Set it to the GitLab user ID of the runner's account (found in your profile settings)." >&2
    ok=0
  fi
  if [ -z "${GITLAB_TOKEN:-}" ]; then
    log "ERROR: GITLAB_TOKEN is not set." >&2
    log "       Set it to a scoped GitLab token (api or read_api scope) in runner/.env." >&2
    ok=0
  fi
  [ "$ok" -eq 0 ] && exit 5
}

require_specs_config() {
  local ok=1
  if [ ! -d "$SPECS_STORIES_DIR" ]; then
    log "ERROR: SPECS_STORIES_DIR='$SPECS_STORIES_DIR' is not a directory." >&2
    ok=0
  fi
  if [ ! -d "$SPECS_AGENTS_DIR" ]; then
    log "ERROR: SPECS_AGENTS_DIR='$SPECS_AGENTS_DIR' is not a directory." >&2
    ok=0
  fi
  if [ ! -f "$SPECS_TRACKER_BIN" ]; then
    log "ERROR: SPECS_TRACKER_BIN='$SPECS_TRACKER_BIN' not found." >&2
    ok=0
  fi
  [ "$ok" -eq 0 ] && exit 5
  mkdir -p "$(dirname "$SPECS_STATE_FILE")"
  # Warn (non-fatal) when MR_RECORD_ENABLED=1 but GitLab config is incomplete.
  # MR recording and reconcile pass will be skipped at runtime for missing vars.
  if [ "${MR_RECORD_ENABLED:-1}" = "1" ]; then
    local missing=""
    [ -z "${GITLAB_TOKEN:-}" ]      && missing="$missing GITLAB_TOKEN"
    [ -z "${GITLAB_URL:-}" ]        && missing="$missing GITLAB_URL"
    [ -z "${GITLAB_PROJECT_ID:-}" ] && missing="$missing GITLAB_PROJECT_ID"
    if [ -n "$missing" ]; then
      log "WARN: MR_RECORD_ENABLED=1 but missing env vars:${missing} — MR recording and reconcile pass will be skipped" >&2
    fi
  fi
}

# ---------------------------------------------------------------------------
# Main watch loop
# ---------------------------------------------------------------------------

main() {
  banner
  log "watch mode starting (tracker=${TRACKER_TYPE})"
  sync_workspace
  require_claude_auth

  case "$TRACKER_TYPE" in
    gitlab)
      require_gitlab_config
      ;;
    specs)
      require_specs_config
      ;;
    jira)
      log "ERROR: TRACKER_TYPE=jira has no driver in v1 (STORY-0026 deferred). Set to specs or gitlab." >&2
      exit 5
      ;;
    *)
      log "ERROR: unsupported TRACKER_TYPE=${TRACKER_TYPE}. Supported: specs, gitlab (jira: deferred)" >&2
      exit 5
      ;;
  esac

  # Surface the active gate so the operator can confirm what will be picked up.
  log_watch_gate_info
  [ "${RUNNER_DISPATCH_DRYRUN:-0}" = "1" ] && log "DISPATCH DRY-RUN mode: will log dispatch prompt without invoking claude"

  LEAD_AGENT="$(discover_lead_agent)"
  log "lead agent: ${LEAD_AGENT}"
  prepare_code_repos
  banner

  # INFLIGHT guard: track keys dispatched this container lifetime so a failed
  # dispatch (that does not remove the ready label) is not re-tried in-session.
  declare -A INFLIGHT=()

  while true; do
    # --- Re-sync specs/ from the host mount each poll (BUG-0042) ---
    # For the specs backend the in-container view is a snapshot taken at startup;
    # re-sync specs/ now so story edits made on the host since startup are visible
    # to tracker_ready_keys this iteration.  Scoped to specs/ only (cheap) and
    # gated to TRACKER_TYPE=specs so the GitLab path is unaffected.
    [ "$TRACKER_TYPE" = "specs" ] && sync_specs

    # STORY-0054: run the reconcile + apply-closeout pass each poll iteration
    # (specs tracker only; non-fatal). Runs after sync_specs so the current story
    # states are visible. Runs BEFORE dispatch so a just-merged story is not
    # re-dispatched in the same poll where it was closed.
    # Reconcile requires GitLab config; skip gracefully when vars are absent.
    if [ "$TRACKER_TYPE" = "specs" ]; then
      if [ -n "${GITLAB_TOKEN:-}" ] && [ -n "${GITLAB_URL:-}" ] && [ -n "${GITLAB_PROJECT_ID:-}" ]; then
        specs_reconcile_pass
      fi
      specs_apply_closeout
    fi

    # --- Poll --- (failures here are logged and the loop continues; not `set -e`)
    # mapfile always succeeds (it captures whatever tracker_ready_keys prints, even
    # on error the function prints to stderr and exits 0 so the array is just empty).
    local keys=()
    mapfile -t keys < <(tracker_ready_keys 2>/dev/null || true)

    [ "${#keys[@]}" -gt 0 ] && log "ready+assigned issues: ${keys[*]}"

    for key in "${keys[@]}"; do
      [ -z "$key" ] && continue

      # INFLIGHT guard.
      if [ -n "${INFLIGHT[$key]:-}" ]; then
        log "skip #${key} (already dispatched this session; still labeled ready — check it)"
        continue
      fi
      INFLIGHT[$key]=1

      banner
      log "dispatching issue #${key}"
      # BUG-0053: re-fetch and reset base branches before each dispatch so the
      # agent always branches off the latest origin/<base>, not a stale local copy
      # from a previous poll iteration (when human-gated MRs advance main behind
      # the container).
      refresh_code_repos
      tracker_on_dispatch_start "$key"
      __pre_dispatch_hash=""   # STORY-0047: populated by do_dispatch

      # STORY-0054 / BUG-0057: snapshot remote branches before dispatch so
      # specs_find_new_branch can detect the new branch after dispatch.
      # Use _snapshot_remote_branches (branch-name-only; fast, no network) so that
      # specs_find_new_branch can compare by branch name in both primary (ls-remote)
      # and fallback paths. Non-fatal; empty file is safe.
      __before_snap_for_mr="$(mktemp 2>/dev/null || true)"
      [ -n "$__before_snap_for_mr" ] && _snapshot_remote_branches > "$__before_snap_for_mr" 2>/dev/null || true

      do_dispatch "$LEAD_AGENT" "$key"
      rc=$?
      if [ "$rc" -eq 0 ]; then
        log "dispatch #${key} finished successfully"
        tracker_on_dispatched "$key" "${__pre_dispatch_hash:-}"
      else
        log "WARN: dispatch #${key} exited non-zero (rc=${rc}); left for human review — not retried this session" >&2
      fi
      # Clean up the before-snapshot temp file (shared via __before_snap_for_mr global).
      [ -n "${__before_snap_for_mr:-}" ] && rm -f "$__before_snap_for_mr"
      __before_snap_for_mr=""
      banner
    done

    sleep "$POLL_INTERVAL"
  done
}

# Run only when executed directly; allow sourcing for unit-testing tracker helpers.
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main
