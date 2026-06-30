# DevOps Patterns and Gotchas — full-stack-fastapi-template

Source of truth: compose.yml, compose.dev.yml, compose.override.yml, scripts/dev.sh,
backend/scripts/prestart.sh, backend/app/backend_pre_start.py, deployment.md,
LEARNINGS.md, .pre-commit-config.yaml.

---

## Pattern 1: Migration Ordering via `service_completed_successfully`

**What it is:** The `backend` service will not start until `prestart` exits 0.
This is enforced in compose.yml with:

```yaml
backend:
  depends_on:
    db:
      condition: service_healthy
      restart: true
    prestart:
      condition: service_completed_successfully
```

**Why it matters:** `alembic upgrade head` runs inside `prestart`, guaranteeing the
schema is at `head` before any API request can touch the database. The `restart: true`
on the `db` dependency means that if the database container restarts, the dependent
services restart too.

**Gotcha:** If `prestart` fails (e.g. a migration error), Docker does not start
`backend` but also does not surface the failure loudly. Always check:

```bash
docker compose logs prestart
```

---

## Pattern 2: prestart Three-Step Init Sequence

`backend/scripts/prestart.sh` runs three commands in strict order:

1. `python app/backend_pre_start.py` — tenacity retry loop (up to 5 min, 1s wait)
   that issues `SELECT 1` to confirm Postgres is accepting connections. This is
   separate from and in addition to the Compose healthcheck, because the healthcheck
   only gates `prestart` starting, not the database being fully ready for queries.
2. `alembic upgrade head` — applies all migrations from `backend/app/alembic/versions/`.
   The Alembic `env.py` builds the DSN from `app.core.config.settings.SQLALCHEMY_DATABASE_URI`.
3. `python app/initial_data.py` — calls `init_db(session)` to create the first
   superuser from `FIRST_SUPERUSER` / `FIRST_SUPERUSER_PASSWORD` if it does not
   already exist.

**Gotcha:** `initial_data.py` is idempotent — re-running it does not create
duplicate users. Alembic is also idempotent against already-applied migrations.
Safe to re-run `prestart` after a failed deploy.

---

## Pattern 3: Compose File Layering

This repo uses explicit file layering rather than a single monolithic file.

| Use case | Files loaded | How |
|----------|-------------|-----|
| Standard local dev | compose.yml + compose.override.yml | `docker compose watch` (auto-load) |
| Workshop / demo dev | compose.yml + compose.override.yml + compose.dev.yml | `./scripts/dev.sh` (explicit `-f` flags) |
| Staging / production | compose.yml only | `docker compose -f compose.yml up -d` |

**Gotcha:** Passing any explicit `-f` flag to `docker compose` **disables** the
auto-loading of `compose.override.yml`. Always pass all three files explicitly when
using `compose.dev.yml`, as `scripts/dev.sh` does:

```bash
docker compose -f compose.yml -f compose.override.yml -f compose.dev.yml up -d ...
```

---

## Pattern 4: Uncommon Ports for Workshop Dev

`compose.dev.yml` uses ports 18000 (backend) and 15173 (frontend) instead of the
standard 8000 / 5173. This is intentional — chosen to avoid collisions with whatever
else is running on the developer's machine.

The port values are exported by `scripts/dev.sh` and interpolated by Compose:

```bash
export BACKEND_PORT="${BACKEND_PORT:-18000}"
export FRONTEND_PORT="${FRONTEND_PORT:-15173}"
```

Override per-run without editing any file:

```bash
BACKEND_PORT=18500 FRONTEND_PORT=15500 ./scripts/dev.sh
```

`BACKEND_CORS_ORIGINS` in `compose.dev.yml` is set dynamically to
`http://localhost:${FRONTEND_PORT:-15173}` so the browser can make cross-origin
requests regardless of which port the frontend is on.

---

## Pattern 5: File-System Polling Across the Docker VM Boundary

On macOS and Windows, filesystem events do not cross the Docker VM boundary
reliably. Both the backend and frontend dev servers are forced into polling mode:

- `WATCHFILES_FORCE_POLLING=true` — passed to the backend container; uvicorn's
  `--reload` watcher (which uses watchfiles internally) will poll.
- `VITE_USE_POLLING=true` — read by `vite.config.ts`; enables Vite's polling watcher.

**Effect:** Changes to source files apply within ~1 second (polling interval).
This is only set in `compose.dev.yml`; standard local and production environments
are not affected.

---

## Pattern 6: No-HTTPS-Redirect in Local Override

`compose.override.yml` defines the `https-redirect` middleware as a no-op:

```yaml
- traefik.http.middlewares.https-redirect.contenttype.autodetect=false
```

In production (`compose.traefik.yml`), the same middleware name is defined as a
real permanent redirect to HTTPS. Application service labels reference
`https-redirect` in both environments, so the same compose.yml works in both
contexts — the middleware behaviour is determined by which Traefik config is active.

---

## Pattern 7: Alembic Autogenerate Workflow

To add a new migration after changing SQLModel models:

```bash
# With the stack running (db must be up)
docker compose exec backend alembic revision --autogenerate -m "describe the change"
```

This generates a new file in `backend/app/alembic/versions/`. Review the generated
upgrade/downgrade functions before committing. Known autogenerate gap: column type
changes for nullable columns require manual verification.

Apply immediately without restarting:

```bash
docker compose exec backend alembic upgrade head
```

On the next full stack restart, `prestart` runs `alembic upgrade head` automatically.

**Migration ordering rule (from DEPLOYMENT.md / CICD.md):** A migration must be
merged to `master` and applied on the target environment before any code that
depends on the new schema is deployed. Deploy the migration PR first, verify it
applied, then deploy the code PR.

---

## Pattern 8: Frontend SDK Regeneration After API Changes

The TypeScript client (`frontend/src/client/`) is generated from the OpenAPI schema.
The `generate-frontend-sdk` pre-commit hook regenerates it whenever `backend/` files
change. If the hook modifies the client, the commit is blocked — stage the updated
files and re-commit.

To regenerate manually with the stack running:

```bash
docker compose exec frontend bun run generate-client
# or, with Node installed locally:
cd frontend && npm run generate-client
```

---

## Pattern 9: zizmor — GitHub Actions Security Gate

`zizmor` (version `>=1.23.1` in root `pyproject.toml`) is a GitHub Actions workflow
security scanner. It runs automatically via pre-commit whenever files under
`.github/workflows/` are modified:

```yaml
- id: zizmor
  entry: uv run zizmor .
  files: ^\.github\/workflows\/
```

**Gotcha:** `zizmor` is a root workspace dev dependency, not a `backend/` dependency.
Run it from the repo root: `uv run zizmor .`

If you add new workflow files (this checkout has none committed), they will be
audited before each commit. Never skip this hook.

---

## Pattern 10: `changethis` Secret Gate

The `.env` file ships with several values set to the literal string `changethis`:

- `SECRET_KEY`
- `POSTGRES_PASSWORD`
- `FIRST_SUPERUSER_PASSWORD`

Compose does not reject `changethis` — the `${VAR?Variable not set}` syntax only
blocks empty/unset variables. Deploying with `changethis` values creates a live
system with known credentials.

Checklist before any non-local deploy:
1. Replace all three secrets with `python -c "import secrets; print(secrets.token_urlsafe(32))"` output.
2. Confirm `ENVIRONMENT` is not `local`.
3. Confirm `DOMAIN` is not `localhost`.
4. Confirm GitHub Environment secrets (`POSTGRES_PASSWORD`, `SECRET_KEY`,
   `FIRST_SUPERUSER_PASSWORD`) are set and not the placeholder value.
