# artisyn-workspace-runner

Run the current Artisyn workspace headlessly inside a local Docker container.
The container adopts the workspace's **configured lead agent** as the top-level
session and delegates to whichever specialists the work needs. One container,
one `claude` process.

Two modes share one image and one persistent clone volume:
- **Manual dispatch** (`artisyn-lead` service) — one-shot dispatch per invocation.
- **Watch mode** (`artisyn-watch` service) — long-running: polls GitLab for
  authorized tickets and dispatches them sequentially, autonomously.

Generated into every Artisyn workspace by `workspace.py generate`. Invoke via
`/artisyn-workspace:run` (the marketplace slash-command) rather than running
`docker compose` directly.

---

## How it works

- The entrypoint copies the workspace into a writable in-container tree (the
  host workspace is **never modified** — it is mounted read-only).
- The container clones the **target code repo** into a persistent named Docker
  volume (`artisyn_code_repo`). On each run it fast-forwards to the configured
  base branch; the implementer branches from there.
- `push.pushOption` is preconfigured so the implementer's `git push` **auto-opens
  a merge request** against the base branch.
- Auth uses a long-lived **subscription OAuth token** (`CLAUDE_CODE_OAUTH_TOKEN`),
  so restarts need no re-login. `--bare` is intentionally NOT used (it would
  skip the workspace hooks/agents).
- Permission mode defaults to `acceptEdits` (honours `settings.json` allow/deny).
  Switch to `bypassPermissions` for fully unattended runs — safe because the
  host repos are read-only and only the code volume is writable.

### Watch mode (`artisyn-watch` / `--watch`)

`watch.sh` is a long-running poll daemon that:
1. Calls the GitLab REST API every `POLL_INTERVAL` seconds for issues that are
   **both** labeled `TRACKER_READY_LABEL` **and** assigned to `TRACKER_ASSIGNEE_ID`.
2. For each authorized issue, dispatches the lead agent with the configured prompt
   (default: `dispatch issue #<iid>`).
3. Keeps an in-process INFLIGHT guard — a failed dispatch (that leaves the label
   intact) is NOT retried this session and is left for human review.
4. Survives individual bad polls and failed dispatches — the daemon is not `set -e`.

**HITL gate (ADR-0007 §5):** both conditions must hold — labeled ready AND assigned
to the runner's account. Assigning a ticket to that account is the human's explicit
per-ticket authorization. Nothing else is auto-dispatched.

**Tracker poll mechanism (ADR-0008):** the `gitlab-da` MCP is preferred for
interactive GitLab sessions but cannot be driven from an unattended shell daemon.
Watch mode therefore uses the GitLab REST API directly
(`GET /projects/:id/issues?labels=...&assignee_id=...&state=opened`), passing the
token via HTTP header (never in the URL). This is the ADR-0008-sanctioned REST
fallback path for unattended poll contexts.

**Dequeue:** the dispatched lead is expected to remove the ready label / transition
the issue so it drops from the next poll. The in-process INFLIGHT guard backs this up.

---

## One-time setup

1. **Generate the Claude auth token** on the host (activation-URL + code flow):
   ```bash
   claude setup-token
   ```
   Copy the printed token.

2. **Create `runner/.env`** from the template and fill it in:
   ```bash
   cp .env.example .env
   # CLAUDE_CODE_OAUTH_TOKEN=<paste from step 1>
   # GIT_TOKEN=<GitLab/GitHub PAT with read_repository + write_repository>
   # TARGET_REPO_URL=https://gitlab.example.com/your-org/your-repo.git
   ```
   For watch mode, also add:
   ```bash
   # GITLAB_PROJECT_ID=<numeric ID or URL-encoded path, e.g. 123 or my-group%2Fmy-repo>
   # TRACKER_ASSIGNEE_ID=<GitLab user ID of the runner account>
   # GITLAB_TOKEN=<scoped GitLab token with api or read_api scope>
   ```
   (`runner/.env` is gitignored.)

3. **Build the image:**
   The `/artisyn-workspace:run` command builds automatically. To build manually:
   ```bash
   docker compose build
   ```
   > **Rebuild note:** only the `artisyn-lead` service defines the image `build:`;
   > `artisyn-watch` / `artisyn-ui` reuse the same `artisyn-workspace-runner:latest`
   > image. Always rebuild with bare `docker compose build` (or
   > `docker compose build artisyn-lead`). `docker compose build artisyn-watch` is a
   > no-op ("No services to build") and silently leaves a **stale** image — e.g. one
   > missing `specs_tracker.py`, so the specs watcher can't run.

   The first dispatch clones the target repo into `artisyn_code_repo` volume.
   Subsequent runs fast-forward only.

---

## Usage (via slash-command — preferred)

```bash
/artisyn-workspace:run "dispatch TICKET-123"   # dispatch one ticket
/artisyn-workspace:run "what's next"           # ask the lead what to pick up
/artisyn-workspace:run --dryrun                # verify mount, list agents, no token needed
/artisyn-workspace:run --watch                 # start autonomous GitLab poll loop
```

## Usage (direct docker compose — advanced)

```bash
# Manual dispatch:
docker compose run --rm artisyn-lead "dispatch TICKET-123"
docker compose run --rm artisyn-lead "what's next"

# Dry run (no token, no dispatch — verify workspace mount):
docker compose run --rm -e RUNNER_DRYRUN=1 artisyn-lead

# Watch mode (long-running daemon):
docker compose up -d artisyn-watch
docker compose logs -f artisyn-watch
docker compose stop artisyn-watch

# Reset and start from a fresh clone:
docker compose down -v
```

---

## Configuration

All configuration is in `runner/.env` (copy `.env.example` to start). Nothing
engagement-specific is baked into the image.

### Manual dispatch

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | _(required)_ | Long-lived subscription OAuth token |
| `ANTHROPIC_API_KEY` | _(fallback)_ | API key (per-token billing fallback) |
| `GIT_TOKEN` | _(required for push)_ | Scoped PAT (`read_repository + write_repository`) |
| `TARGET_REPO_URL` | _(required)_ | HTTPS URL of the target code repo to clone |
| `TARGET_BASE_BRANCH` | `main` | Base branch for cloning and MR target |
| `GIT_AUTHOR_NAME` | `Artisyn Agent` | Git committer name inside the container |
| `GIT_AUTHOR_EMAIL` | `artisyn.agent@dataart.com` | Git committer email inside the container |
| `CLAUDE_PERMISSION_MODE` | `acceptEdits` | `acceptEdits` or `bypassPermissions` |
| `OUTPUT_FORMAT` | `text` | `text`, `json`, or `stream-json` |
| `RUNNER_VERBOSE` | `1` | `1` = stream turn-by-turn; `0` = final result only |
| `RUNNER_DRYRUN` | `0` | `1` = list agents and exit without dispatch |

### Watch mode (additional variables)

| Variable | Default | Description |
|---|---|---|
| `TRACKER_TYPE` | `gitlab` | Tracker backend (`gitlab` built; others reserved) |
| `GITLAB_URL` | `https://gitlab.dataart.com` | GitLab base URL |
| `GITLAB_PROJECT_ID` | _(required)_ | Numeric ID or URL-encoded path |
| `TRACKER_READY_LABEL` | `ready-for-agent` | GitLab label that signals ready for dispatch |
| `TRACKER_ASSIGNEE_ID` | _(required)_ | GitLab user ID of the runner's own account (HITL gate) |
| `GITLAB_TOKEN` | _(required)_ | Scoped GitLab token (`api` or `read_api` scope) |
| `POLL_INTERVAL` | `300` | Seconds between polls |
| `TRACKER_MAX_RESULTS` | `50` | Max issues fetched per poll |
| `TRACKER_DISPATCH_TEMPLATE` | `dispatch issue #%s` | Printf template for the dispatch prompt |

---

## Notes

- **MR creation** is handled by `push.pushOption` (no `glab` needed). If the
  push prints `merge request … already exists`, that is expected on re-push.
- **MR title/description come from the commit message**: GitLab uses the commit
  SUBJECT as the MR title and the BODY as the description. The lead therefore
  briefs the implementer to write a structured commit body (Summary / Changes /
  Refs / Test plan) above the Co-Authored-By trailer.
- The `GIT_TOKEN` is written into the clone's remote URL inside the named volume
  (local dev convenience). Use a **scoped Project Access Token**; `docker compose
  down -v` wipes the volume and the stored token.
- Watch mode's `GITLAB_TOKEN` is passed via the `PRIVATE-TOKEN` HTTP header in
  the REST poll — never in the URL — and is not logged.
- Manual dispatch and watch mode share the clone volume; run one at a time.
