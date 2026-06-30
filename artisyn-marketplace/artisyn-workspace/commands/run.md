---
description: Run the workspace in a local Docker container — one-shot manual dispatch, autonomous watch mode (--watch) that polls the configured tracker for authorized tickets, or opt-in browser UI sidecar (--ui) with Chainlit chat and Langfuse dashboard.
argument-hint: '"dispatch <ticket>" | "what''s next" | --dryrun | --watch [--tracker specs|jira|gitlab] | --ui'
allowed-tools: Bash
---

Move the current Artisyn workspace into a local Docker container and run it
headlessly. The host workspace is mounted **read-only**; a writable copy lives
inside the container. The configured **lead agent** is the sole entry point —
it orchestrates whichever specialists the work needs.

The container discovers the **code repos** by scanning your workspace's sibling
`../src` tree: every git-backed folder is cloned **fresh** into its own persistent
named volume (never your local working copy) and fast-forwarded to that repo's own
current branch; non-git folders are mounted **read-only** as reference material.
On completion the implementer's push **auto-opens a merge request** per changed
repo, each targeting that repo's own base branch. Git auth uses your **host SSH
identity** (`~/.ssh` mounted read-only) — no Personal Access Token required for
SSH remotes.

**Watch mode** (`--watch`) starts a long-running poller that reads the configured
tracker every `POLL_INTERVAL` seconds for tickets that meet the stage gate: status
equals the Development entry status (`TRACKER_READY_STATUS`, default `Sprint Ready`),
the ticket is assigned to a known agent, and — when configured — it carries the
`TRACKER_REQUIRE_LABEL` label (default `adlc-auto`). Use `--tracker` to override
the backend for this run. Each authorized ticket is dispatched to the lead agent
sequentially with a **stage-aware** prompt (names the story, the Development stage,
the assignee, and instructs test-first implementation ending with a PR to `main`).
Failed dispatches are left for human review; a single failure does not stop the daemon.

**UI sidecar** (`--ui`) is **opt-in** and starts a browser chat (Chainlit,
Apache-2.0) and a self-hosted activity dashboard (Langfuse, MIT) alongside the
existing runtime. The headless `artisyn-lead` and `artisyn-watch` services work
fully without the UI sidecar — the runtime takes **no dependency** on it.
The chat drives the **same dispatch path** as the headless runner (no second
orchestrator around the lead). The Langfuse dashboard provides agent trace replay;
the `adlc` cockpit / OpenObserve KPIs are surfaced as links — not reimplemented.

For setup and configuration options see `runner/.env.example` in the workspace
marketplace directory, or the README at `artisyn-marketplace/artisyn-workspace/runner/README.md`.

## Prerequisites

1. **Docker Desktop** (or Docker Engine) running locally.
2. **Claude auth token** — generate once: `claude setup-token` and put the
   printed token in `runner/.env` as `CLAUDE_CODE_OAUTH_TOKEN`.
3. **Host SSH access to your git remotes** — the runner mounts your `~/.ssh`
   read-only and clones over SSH using your existing keys + config. Make sure
   you can `git clone` your repos over SSH on the host. (Optional: set `GIT_TOKEN`
   in `runner/.env` only as an HTTPS fallback.)
4. **Code repos in `../src`** — the runner scans your workspace's sibling
   `../src` tree automatically; each git folder becomes a clonable target, each
   non-git folder a read-only reference. No per-repo config needed. (Optional:
   `TARGET_REPO_URL`/`TARGET_BASE_BRANCH` are used only if `../src` is empty.)
5. **Watch mode only** — set `TRACKER_TYPE` in `runner/.env` to `specs`, `gitlab`,
   or `jira` (gitlab and jira also require their respective credentials; see
   Configuration below). Override for a single run with `--tracker`.
6. **UI sidecar only** — optionally set `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`,
   and `ADLC_COCKPIT_URL` in `runner/.env` (see UI Sidecar Configuration below).

## Usage

```
/artisyn-workspace:run "dispatch <ticket>"              # dispatch one ticket
/artisyn-workspace:run "what's next"                    # ask the lead what to pick up
/artisyn-workspace:run --dryrun                         # verify workspace mount + list agents, no dispatch
/artisyn-workspace:run --watch                          # start watch loop using configured tracker
/artisyn-workspace:run --watch --tracker specs          # watch local specs/ backlog
/artisyn-workspace:run --watch --tracker gitlab         # watch GitLab issues
/artisyn-workspace:run --watch --tracker jira           # watch Jira (driver deferred; seam present)
/artisyn-workspace:run --ui                             # start opt-in UI sidecar (chat + dashboard)
```

## Execute

All steps are guarded — stop and report any non-zero exit.

### Step 0 — Verify Docker is available

```bash
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not on PATH. Install Docker Desktop (https://docs.docker.com/desktop/) and ensure the daemon is running." >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon is not responding. Start Docker Desktop and retry." >&2
  exit 1
fi
echo "OK: Docker is available."
```

### Step 1 — Locate the runner directory

The Docker assets live in the workspace marketplace alongside this command.
Find them relative to the Claude plugin root.

```bash
RUNNER_DIR="${CLAUDE_PLUGIN_ROOT}/runner"
if [ ! -f "${RUNNER_DIR}/docker-compose.yml" ]; then
  echo "ERROR: runner assets not found at ${RUNNER_DIR}." >&2
  echo "       Re-run 'workspace.py generate' to emit them, then retry." >&2
  exit 1
fi
echo "Runner directory: ${RUNNER_DIR}"
```

### Step 2 — Ensure runner/.env exists

```bash
ENV_FILE="${RUNNER_DIR}/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "==> No runner/.env found. Copying .env.example as a starting template..."
  cp "${RUNNER_DIR}/.env.example" "$ENV_FILE"
  echo "    Edit ${ENV_FILE} and fill in CLAUDE_CODE_OAUTH_TOKEN, then re-run."
  echo "    Code repos are auto-discovered from ../src and cloned over your host SSH (~/.ssh)."
  echo "    For --watch mode: set TRACKER_TYPE (specs|gitlab|jira) and required credentials."
  echo "    For --ui mode also fill in LANGFUSE_PUBLIC_KEY, LANGFUSE_SECRET_KEY (after first Langfuse login)."
  exit 0
fi
echo "OK: ${ENV_FILE} exists."
```

### Step 3 — Build the image (skip if up to date)

```bash
cd "${RUNNER_DIR}"
echo "==> Building artisyn-workspace-runner image (uses cache when unchanged)..."
docker compose build
```

### Step 4 — Parse --tracker flag (watch mode only)

When `--watch` is present, check for an optional `--tracker` flag that overrides
`TRACKER_TYPE` for this run.

Supported values: `specs`, `jira`, `gitlab`. Any other value is a hard error.

```bash
cd "${RUNNER_DIR}"

ARG="${ARGUMENTS:-}"
TRACKER_OVERRIDE=""
WATCH_MODE=0

# Split args: extract --watch and --tracker <value> from ARG
REMAINING_ARG=""
set -- $ARG
while [ "$#" -gt 0 ]; do
  case "$1" in
    --watch)
      WATCH_MODE=1
      shift
      ;;
    --tracker)
      shift
      if [ "$#" -eq 0 ]; then
        echo "ERROR: --tracker requires a value. Supported: specs, gitlab, jira" >&2
        exit 1
      fi
      TRACKER_OVERRIDE="$1"
      shift
      ;;
    --tracker=*)
      TRACKER_OVERRIDE="${1#--tracker=}"
      shift
      ;;
    *)
      REMAINING_ARG="${REMAINING_ARG} $1"
      shift
      ;;
  esac
done
REMAINING_ARG="${REMAINING_ARG# }"

# Validate --tracker value if provided
if [ -n "$TRACKER_OVERRIDE" ]; then
  case "$TRACKER_OVERRIDE" in
    specs|gitlab|jira) ;;
    *)
      echo "ERROR: unsupported --tracker value '${TRACKER_OVERRIDE}'." >&2
      echo "       Supported values: specs, gitlab, jira" >&2
      exit 1
      ;;
  esac
fi

# Reconstruct ARG for the legacy single-arg path below
if [ "$WATCH_MODE" -eq 1 ]; then
  ARG="--watch"
elif [ -n "$REMAINING_ARG" ]; then
  ARG="$REMAINING_ARG"
fi
```

### Step 5 — Dispatch, Watch, or UI sidecar

Parse the argument:

- `--dryrun` or no argument → dry run (list agents, no dispatch, no token required).
- `--watch` → start the autonomous watch loop (long-running; runs in the background).
  When `--tracker` was given, override `TRACKER_TYPE` for this run.
- `--ui` → start the opt-in UI sidecar (Chainlit chat + Langfuse dashboard) using compose profile "ui".
- Any other string → the dispatch instruction sent to the lead (one-shot).

```bash
cd "${RUNNER_DIR}"

# Read the configured tracker (from .env if present, else the compose default)
CURRENT_TRACKER="${TRACKER_TYPE:-gitlab}"
if [ -n "$TRACKER_OVERRIDE" ]; then
  CURRENT_TRACKER="$TRACKER_OVERRIDE"
fi

if [ -z "$ARG" ] || [ "$ARG" = "--dryrun" ]; then
  echo "==> DRY RUN — verifying workspace mount and listing available agents..."
  docker compose run --rm -e RUNNER_DRYRUN=1 artisyn-lead
elif [ "$ARG" = "--watch" ]; then
  # Determine the active gate for the start-up message
  ACTIVE_STATUS="${TRACKER_READY_STATUS:-Sprint Ready}"
  ACTIVE_LABEL="${TRACKER_REQUIRE_LABEL:-adlc-auto}"
  echo "==> Starting watch mode (artisyn-watch service)..."
  echo "    Tracker:      ${CURRENT_TRACKER}"
  echo "    Entry status: ${ACTIVE_STATUS}"
  if [ -n "$ACTIVE_LABEL" ]; then
    echo "    Label gate:   ${ACTIVE_LABEL}"
  else
    echo "    Label gate:   <disabled>"
  fi
  echo "    Interval:     ${POLL_INTERVAL:-300}s"
  echo "    Tail logs: docker compose -f ${RUNNER_DIR}/docker-compose.yml logs -f artisyn-watch"
  echo "    Stop:      docker compose -f ${RUNNER_DIR}/docker-compose.yml stop artisyn-watch"
  if [ -n "$TRACKER_OVERRIDE" ]; then
    docker compose up -d -e TRACKER_TYPE="${CURRENT_TRACKER}" artisyn-watch
  else
    docker compose up -d artisyn-watch
  fi
  echo "==> artisyn-watch started. Polling ${CURRENT_TRACKER} for ready stories."
elif [ "$ARG" = "--ui" ]; then
  echo "==> Starting UI sidecar (compose profile 'ui') — Chainlit chat + Langfuse dashboard..."
  echo "    This starts: artisyn-ui (Chainlit, Apache-2.0), artisyn-langfuse (MIT), artisyn-langfuse-db."
  echo "    The headless artisyn-lead and artisyn-watch services are NOT affected."
  docker compose --profile ui up -d
  echo ""
  echo "==> UI sidecar started:"
  echo "    Chainlit chat:      http://localhost:${UI_PORT:-8000}"
  echo "    Langfuse dashboard: http://localhost:${LANGFUSE_PORT:-3000}"
  echo ""
  echo "    First-time Langfuse setup:"
  echo "      1. Open http://localhost:${LANGFUSE_PORT:-3000} and create an account + project."
  echo "      2. Copy the public and secret keys into runner/.env as:"
  echo "           LANGFUSE_PUBLIC_KEY=<pk-...>"
  echo "           LANGFUSE_SECRET_KEY=<sk-...>"
  echo "      3. Restart: docker compose --profile ui restart artisyn-ui"
  echo ""
  echo "    Stop UI sidecar: docker compose --profile ui down"
  echo "    Tail logs:       docker compose --profile ui logs -f artisyn-ui"
else
  echo "==> Dispatching: ${ARG}"
  docker compose run --rm artisyn-lead "${ARG}"
fi
```

After the run (one-shot), report:
- Whether the dispatch completed successfully (exit code 0) or failed (non-zero exit).
- On success: remind the user to check for an auto-opened merge request in the
  target repository.
- On failure: show the last lines of output and suggest checking `runner/.env`
  (token, repo URL, base branch) and retrying with `--dryrun` first.

For watch mode, report that the daemon is running and show the tail/stop commands.

For UI sidecar mode, report the Chainlit and Langfuse URLs and the first-time
Langfuse setup steps.

Re-running is safe; the container uses a persistent named volume for the code
repo clone, so subsequent runs only fast-forward rather than full clone.
To start over from a fresh clone: `docker compose down -v` (wipes the volume).

## Watch Mode Configuration

Watch mode (`--watch`) polls the configured tracker for tickets that meet the
Development stage gate: status equals `TRACKER_READY_STATUS` AND the ticket is
assigned to a known agent AND (when set) the ticket carries `TRACKER_REQUIRE_LABEL`.
All three conditions must hold (ADR-0010 §3).

The `--tracker` flag overrides the backend for a single run without editing `.env`.

### Tracker backends

| Backend | `--tracker` value | Status |
|---|---|---|
| Local `specs/` stories | `specs` | Built — scans `specs/STORIES/*.md` |
| GitLab REST API | `gitlab` | Built — polls `GET /projects/:id/issues?...` |
| Jira | `jira` | Deferred (STORY-0026) — seam present, no driver in v1 |

### Configuration variables (set in `runner/.env`)

| Variable | Default | Description |
|---|---|---|
| `TRACKER_TYPE` | `gitlab` | Default tracker backend (`specs`\|`gitlab`\|`jira`) |
| `TRACKER_READY_STATUS` | `Sprint Ready` | Development stage entry status (ADR-0010 §2) |
| `TRACKER_REQUIRE_LABEL` | `adlc-auto` | Required label; set empty to disable the label gate |
| `POLL_INTERVAL` | `300` | Seconds between polls |
| **GitLab only** | | |
| `GITLAB_URL` | `https://gitlab.dataart.com` | GitLab base URL |
| `GITLAB_PROJECT_ID` | _(required)_ | GitLab project numeric ID or URL-encoded path |
| `TRACKER_READY_LABEL` | `ready-for-agent` | GitLab label that marks a ticket ready |
| `TRACKER_ASSIGNEE_ID` | _(required)_ | GitLab user ID of the runner's own account |
| `GITLAB_TOKEN` | _(required)_ | Scoped GitLab token (`api` or `read_api` scope) |
| `TRACKER_MAX_RESULTS` | `50` | Maximum issues fetched per poll |
| **Specs only** | | |
| `SPECS_STORIES_DIR` | `specs/STORIES` | Directory containing story markdown files |
| `SPECS_AGENTS_DIR` | `.claude/agents` | Directory of agent markdown files |
| `SPECS_STATE_FILE` | `/artisyn/state/dispatched.json` | Dequeue state (content hashes) |
| `SPECS_LEDGER_FILE` | `/artisyn/state/dispatch-ledger.jsonl` | Per-dispatch KPI ledger (STORY-0027) |

**Stage gate:** a ticket is picked up for the Development stage only when ALL hold:
1. `status == TRACKER_READY_STATUS` (configured entry status)
2. `assignee` names a known generated agent
3. (when `TRACKER_REQUIRE_LABEL` is non-empty) the ticket carries that label

**Dispatch prompt:** each dispatched ticket receives a stage-aware prompt that names
the story, the stage (Development), the assignee, and instructs the lead to delegate
implementation test-first, pass code review, and open a PR to `main`. Merge is
always human-gated (ADR-0010 §4 strong-HITL).

**KPI signals (STORY-0027):** the dispatch prompt instructs the agent to emit in
the PR description:
```
*[<agent-name>]*
Cost: X USD / Y tokens
```
These match the `workspace-cg` `collect_status_kpi.py` parser so automated tickets
appear in existing delivery KPIs without any collector change. The specs backend
also appends a JSONL record to `SPECS_LEDGER_FILE` for local audit.

**Dequeue:** for the specs backend, a content hash is recorded after each dispatch
so an unchanged, already-dispatched story is not re-dispatched even across container
restarts. An in-process guard prevents re-dispatch within the container's lifetime.

**GitLab dequeue:** the dispatched lead removes the ready label / transitions the
issue so it drops from the next poll.

**Implementation note (GitLab):** the `gitlab-da` MCP is preferred for interactive
GitLab access but cannot be driven from an unattended shell poll daemon. Watch mode
therefore uses the GitLab REST API directly, passing the token via HTTP header —
the ADR-0008-sanctioned REST fallback.

## UI Sidecar Configuration

UI sidecar (`--ui`) is opt-in. It starts a Chainlit browser chat and a self-hosted
Langfuse activity dashboard. The headless runtime continues to work without it.

| Variable | Default | Description |
|---|---|---|
| `UI_PORT` | `8000` | Host port for the Chainlit browser chat |
| `LANGFUSE_PORT` | `3000` | Host port for the self-hosted Langfuse dashboard |
| `LANGFUSE_PUBLIC_KEY` | _(optional)_ | Langfuse project public key (enables trace recording) |
| `LANGFUSE_SECRET_KEY` | _(optional)_ | Langfuse project secret key |
| `LANGFUSE_HOST` | `http://artisyn-langfuse:3000` | Langfuse server URL (internal docker network) |
| `NEXTAUTH_SECRET` | _(dev default)_ | Langfuse NextAuth secret — CHANGE for production |
| `LANGFUSE_SALT` | _(dev default)_ | Langfuse password-hashing salt — CHANGE for production |
| `ADLC_COCKPIT_URL` | _(optional)_ | adlc/OpenObserve dashboard URL — surfaced as a link in the chat (AC4) |

**Chat dispatch:** the Chainlit app calls the same `claude -p ... --append-system-prompt
<lead_persona>` path as the headless runner. A browser message is equivalent to
`docker compose run --rm artisyn-lead "<message>"`. There is no second orchestrator.

**Multimodal:** image and file attachments are accepted via the Chainlit file-upload
widget and passed into the dispatch prompt.

**Activity dashboard:** Langfuse records each dispatch as a trace with input (dispatch
prompt), output (result snippet), and metadata (lead agent, exit code). The Langfuse
UI at `http://localhost:3000` provides the running-agents activity view with per-step
trace replay. The `adlc`/OpenObserve delivery KPIs are surfaced as a link — not
reimplemented here.

**Bases (ADR-0004):** Chainlit 2.5.5 (Apache-2.0) + Langfuse 3.0.3 (MIT), consumed
as version-pinned dependencies (not vendored, not forked). See `runner/ui/requirements.txt`.
