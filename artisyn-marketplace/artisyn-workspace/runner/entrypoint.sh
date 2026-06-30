#!/usr/bin/env bash
#
# artisyn-workspace-runner entrypoint — ONE-SHOT manual dispatch.
#
#   docker compose run --rm artisyn-lead "dispatch TICKET-123"
#   docker compose run --rm artisyn-lead "what's next"
#   docker compose run --rm -e RUNNER_DRYRUN=1 artisyn-lead
#
# Watch mode (STORY-0007b) will be added as a separate entrypoint/mode.
# Shared steps (workspace sync, repo prep, persona, dispatch) live in lib.sh.
set -euo pipefail
source /usr/local/bin/lib.sh

# 1: writable workspace copy (all agents present; the lead orchestrates them).
sync_workspace

# Dry run: stop after the sync so the workspace mount can be verified without
# a Claude token or a real dispatch.
if [ "${RUNNER_DRYRUN:-0}" = "1" ]; then
  log "DRY RUN — agents available to the lead:"
  ls -1 .claude/agents/ 2>/dev/null | sed 's/^/  /'
  if [ -d "$SRC_HOST" ]; then
    log "DRY RUN — code folders discovered under src/:"
    for path in "$SRC_HOST"/*/; do
      [ -d "$path" ] || continue
      n="$(basename "$path")"; case "$n" in .*) continue ;; esac
      if [ -d "$path/.git" ]; then
        b="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
        echo "  [repo] $n  (base: $b)"
      else
        echo "  [ro]   $n"
      fi
    done
  else
    log "DRY RUN — no src mount at $SRC_HOST (will use TARGET_REPO_URL fallback if set)."
  fi
  exit 0
fi

# 2: auth check.
require_claude_auth

if [ "$#" -eq 0 ]; then
  log "No dispatch prompt given." >&2
  log "Usage: docker compose run --rm artisyn-lead \"dispatch TICKET-123\"" >&2
  log "       docker compose run --rm artisyn-lead \"what's next\"" >&2
  exit 2
fi
DISPATCH="$*"

# 3: discover the lead agent (searches .claude/agents/ for a *lead* agent).
LEAD_AGENT="$(discover_lead_agent)"
log "lead agent: ${LEAD_AGENT}"

# 4: prepare the container's own code repo clones (one per src/ folder), then dispatch.
prepare_code_repos

log "launching ${LEAD_AGENT} orchestrator (permission-mode=${CLAUDE_PERMISSION_MODE:-acceptEdits}, verbose=${RUNNER_VERBOSE:-1}) ..."
log "dispatch: ${DISPATCH}"
banner
run_claude "$LEAD_AGENT" "$DISPATCH"
