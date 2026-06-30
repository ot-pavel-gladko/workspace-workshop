#!/usr/bin/env bash
#
# artisyn-workspace-runner UI sidecar entrypoint (STORY-0008).
#
# Starts the Chainlit browser chat app that drives the SAME lead-dispatch path
# as the headless artisyn-lead service.  Requires the "ui" compose profile.
#
# The UI is OPTIONAL — this entrypoint is ONLY used by the artisyn-ui service
# (profiles: ["ui"]). The headless artisyn-lead and artisyn-watch services use
# entrypoint.sh and watch.sh respectively and have NO dependency here.
#
# Steps:
#   1. Sync the read-only workspace mount into a writable copy (same as headless).
#   2. Install the pinned UI requirements (Chainlit + Langfuse) via uv/pip.
#   3. Start the Chainlit server on 0.0.0.0:8000.
set -euo pipefail
source /usr/local/bin/lib.sh

UI_DIR="${UI_DIR:-/artisyn/ui}"
CHAINLIT_HOST="${CHAINLIT_HOST:-0.0.0.0}"
CHAINLIT_PORT="${CHAINLIT_PORT:-8000}"

# 1: Sync workspace so the lead agent files are visible to the UI sidecar.
sync_workspace

# 1b: Prepare the per-repo code clones (one per src/ folder) + SSH identity, so
# chat-driven dispatches can make code changes via the SAME path as the headless
# runner. Idempotent: clone on first start, fast-forward on restart.
prepare_code_repos

log "UI sidecar starting (Chainlit ${CHAINLIT_HOST}:${CHAINLIT_PORT}) ..."

# 2: UI requirements live in a venv baked at image-build time (see Dockerfile).
# Reuse it. Only fall back to a runtime install if the venv is missing (e.g. the
# image predates the build-time venv) — that path needs network and may be slow.
UI_VENV="${UI_VENV:-/artisyn/ui-venv}"
REQ="${UI_DIR}/requirements.txt"
CHAINLIT_BIN="$UI_VENV/bin/chainlit"
if [ ! -x "$CHAINLIT_BIN" ]; then
  log "WARN: prebuilt UI venv not found at ${UI_VENV}; installing at runtime ..." >&2
  uv venv "$UI_VENV" 2>/dev/null || true
  if [ -f "$REQ" ]; then
    uv pip install --python "$UI_VENV/bin/python" -r "$REQ" --quiet
  else
    log "ERROR: ${REQ} not found and no prebuilt venv; cannot start Chainlit." >&2
    exit 1
  fi
fi

# 3: Launch Chainlit from the venv.
APP_PY="${UI_DIR}/app.py"
if [ ! -f "$APP_PY" ]; then
  log "ERROR: Chainlit app not found at ${APP_PY}" >&2
  exit 1
fi

log "launching Chainlit app: ${APP_PY}"
exec "$CHAINLIT_BIN" run "$APP_PY" \
  --host "$CHAINLIT_HOST" \
  --port "$CHAINLIT_PORT" \
  --headless
