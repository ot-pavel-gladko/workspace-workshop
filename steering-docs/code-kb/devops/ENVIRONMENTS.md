# Environment Topology — full-stack-fastapi-template

Source of truth: deployment.md, development.md, LEARNINGS.md, compose.yml,
compose.override.yml, compose.dev.yml, scripts/dev.sh.

---

## Three-Environment Model

| Environment | `ENVIRONMENT` value | Compose files used | Deploy trigger |
|-------------|--------------------|--------------------|---------------|
| Local       | `local` (default)  | compose.yml + compose.override.yml | Manual: `docker compose watch` |
| Workshop    | `local`            | compose.yml + compose.override.yml + compose.dev.yml | Manual: `./scripts/dev.sh` |
| Staging     | `staging`          | compose.yml only   | Push/merge to `master` |
| Production  | `production`       | compose.yml only   | GitHub Release published |

---

## Local Development (standard)

**Entry point:** `docker compose watch` (from `src/full-stack-fastapi-template/`)

compose.yml is the base; compose.override.yml adds development overrides
automatically (Docker Compose loads both by default).

**compose.override.yml** differences from production:
- Adds a Traefik proxy container (`traefik:3.6`) on port 80 with
  `--api.insecure=true` and a no-op `https-redirect` middleware (no real
  HTTPS redirect locally).
- Exposes Postgres on host port `5432`.
- Exposes Adminer on host port `8080`.
- Backend command changed to `fastapi run --reload app/main.py` (single worker,
  hot-reload enabled).
- Backend uses Docker Compose `develop.watch` to sync `./backend` → `/app/backend`
  on save (excluding `.venv`).
- Backend healthcheck still runs against `http://localhost:8000/api/v1/utils/health-check/`.
- Mailcatcher service added (`schickling/mailcatcher`) on ports 1080 (web) and 1025 (SMTP).
  Backend is configured with `SMTP_HOST=mailcatcher`, `SMTP_PORT=1025`, `SMTP_TLS=false`.
- Playwright service added for E2E tests.
- `traefik-public` network is `external: false` (created locally, not pre-existing).

**Local URLs (default):**

| Service   | URL |
|-----------|-----|
| Frontend  | http://localhost:5173 |
| Backend   | http://localhost:8000 |
| API docs  | http://localhost:8000/docs |
| Adminer   | http://localhost:8080 |
| Traefik   | http://localhost:8090 |
| Mailcatcher | http://localhost:1080 |

**Subdomain mode** (optional): Set `DOMAIN=localhost.tiangolo.com` in `.env`.
`localhost.tiangolo.com` and all its subdomains resolve to `127.0.0.1` — this
lets you test `api.localhost.tiangolo.com` and `dashboard.localhost.tiangolo.com`
without DNS changes.

---

## Workshop / Demo Dev Environment

**Entry point:** `./scripts/dev.sh` (from `src/full-stack-fastapi-template/`)

Layers compose files in explicit order:
```
docker compose -f compose.yml -f compose.override.yml -f compose.dev.yml
```

**compose.dev.yml** changes on top of override:
- Postgres port binding is reset to `[]` — no host port exposed. Postgres is
  internal to the Docker network; access via `docker compose exec db psql`.
- Backend published on host port `${BACKEND_PORT:-18000}` (uncommon to avoid conflicts).
- Frontend published on host port `${FRONTEND_PORT:-15173}`.
- `BACKEND_CORS_ORIGINS` is set to `http://localhost:${FRONTEND_PORT:-15173}` so
  the browser can reach the API.
- `WATCHFILES_FORCE_POLLING=true` — forces file-system polling because inotify
  events do not cross the Docker VM boundary on macOS/Windows.
- Backend source bind-mounted: `./backend/app` → `/app/backend/app`.
- Frontend build targets the `deps` stage only (no production bundle); runs the
  Vite dev server: `bun run dev --host 0.0.0.0 --port ${FRONTEND_PORT:-15173}`.
- `VITE_USE_POLLING=true` enables Vite's polling watcher.
- Frontend source bind-mounted: `./frontend` → `/app/frontend` (with anonymous
  volume at `/app/frontend/node_modules` to preserve container node_modules).

Services started: `db prestart backend frontend` only. Traefik, playwright,
adminer, and mailcatcher are omitted.

**Workshop URLs (default ports):**

| Service   | URL |
|-----------|-----|
| Frontend  | http://localhost:15173 |
| API docs  | http://localhost:18000/docs |
| Login     | admin@example.com / changethis |

Port override: `BACKEND_PORT=18500 FRONTEND_PORT=15500 ./scripts/dev.sh`

**dev.sh subcommands:**

| Command               | Effect |
|-----------------------|--------|
| `./scripts/dev.sh`    | Build + start stack (detached), wait for backend health |
| `./scripts/dev.sh logs`  | Follow logs for db/prestart/backend/frontend |
| `./scripts/dev.sh down`  | Stop and remove containers (keeps DB volume) |
| `./scripts/dev.sh reset` | `down -v` — removes containers and database volume |

---

## Staging

- `ENVIRONMENT=staging`
- `DOMAIN` set from GitHub Environment secret `DOMAIN_STAGING`
- `STACK_NAME` set from `STACK_NAME_STAGING` (e.g. `staging-fastapi-project-example-com`)
- Only `compose.yml` is used — no override file.
- Self-hosted runner labeled `staging` executes the deploy.
- Subdomains: `dashboard.staging.$DOMAIN`, `api.staging.$DOMAIN`, `adminer.staging.$DOMAIN`
- GitHub Environment protection rules are configurable (no required reviewers by default).

---

## Production

- `ENVIRONMENT=production`
- `DOMAIN` set from `DOMAIN_PRODUCTION`
- `STACK_NAME` set from `STACK_NAME_PRODUCTION` (e.g. `fastapi-project-example-com`)
- Only `compose.yml` is used.
- Self-hosted runner labeled `production` executes the deploy.
- Subdomains: `dashboard.$DOMAIN`, `api.$DOMAIN`, `adminer.$DOMAIN`, `traefik.$DOMAIN`
- Production GitHub Environment should have required-reviewer protection configured.

---

## Configuration Gate: `changethis` Variables

The following variables have a default value of `changethis` in `.env`. Compose
uses the `?Variable not set` syntax on required variables — but `changethis` will
pass that check. It is the operator's responsibility to replace these before any
non-local deployment:

- `SECRET_KEY` (JWT signing)
- `POSTGRES_PASSWORD`
- `FIRST_SUPERUSER_PASSWORD`

Command to generate a replacement: `python -c "import secrets; print(secrets.token_urlsafe(32))"`

---

## `.env` File Handling

The `.env` file is read by Docker Compose via `env_file: - .env` on each service.
In local dev it lives in the repo root and may be committed if the repo is private.
For public repos, exclude `.env` from git and inject secrets via CI/CD environment
variables, then rewrite the relevant `env_file` reference in compose.yml or
pass vars directly on the command line.
