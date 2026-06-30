# Deployment Runbook — full-stack-fastapi-template

Source of truth: deployment.md, compose.yml, compose.traefik.yml, compose.override.yml,
backend/Dockerfile, frontend/Dockerfile.

---

## Architecture Overview

The stack is deployed as Docker Compose services behind a **Traefik 3.6** reverse proxy.
Traefik runs as a separate, persistent container (from `compose.traefik.yml`) and
communicates with application containers over an external Docker network named
`traefik-public`. This design allows multiple stacks to share one Traefik instance
on the same server.

### Service Graph (from compose.yml)

```
traefik-public network
  ├── traefik          (compose.traefik.yml — persistent, started once)
  ├── prestart         depends_on: db (healthy) — runs migrations + superuser seed
  ├── backend          depends_on: db (healthy), prestart (completed_successfully)
  ├── frontend         no runtime dependencies on backend
  └── adminer          depends_on: db
      db               postgres:18 with healthcheck
```

`backend` will **not start** until both conditions are met:
1. `db` healthcheck passes (`pg_isready -U $POSTGRES_USER -d $POSTGRES_DB`,
   interval 10s, 5 retries, 30s start period).
2. `prestart` exits with code 0 (`condition: service_completed_successfully`).

This is the migration ordering guarantee — `alembic upgrade head` always completes
before the API process accepts requests.

---

## Traefik Setup (One-Time Per Server)

All steps run on the remote server.

```bash
# 1. Create the shared public network
docker network create traefik-public

# 2. Copy compose.traefik.yml to the server
rsync -a compose.traefik.yml root@your-server.example.com:/root/code/traefik-public/

# 3. Set required environment variables (never commit these)
export DOMAIN=fastapi-project.example.com
export EMAIL=admin@example.com
export USERNAME=admin
export PASSWORD=<strong-password>
export HASHED_PASSWORD=$(openssl passwd -apr1 $PASSWORD)

# 4. Start Traefik
cd /root/code/traefik-public/
docker compose -f compose.traefik.yml up -d
```

Traefik stores Let's Encrypt certificates in a named volume
(`traefik-public-certificates`) and uses the **TLS challenge** (`tlschallenge=true`)
to obtain them. The cert resolver is named `le`.

The Traefik dashboard is protected by HTTP Basic auth using the `admin-auth`
middleware (USERNAME + HASHED_PASSWORD). It is reachable at
`https://traefik.$DOMAIN`.

HTTP-to-HTTPS redirect is handled by the `https-redirect` middleware, which is a
`redirectscheme.scheme=https` + `permanent=true` middleware applied to every HTTP
router in the stack.

---

## HTTPS / TLS Configuration (from compose.traefik.yml and compose.yml)

Every application service (backend, frontend, adminer) registers Traefik labels
that declare:
- An HTTP router (`entrypoints=http`) with the `https-redirect` middleware.
- An HTTPS router (`entrypoints=https`) with `tls=true` and `tls.certresolver=le`.

Traefik automatically requests and renews the certificate for each subdomain via
ACME / Let's Encrypt. Certificate files persist in the `traefik-public-certificates`
volume across container restarts.

Subdomains used (where `$DOMAIN` is the base domain):
- `api.$DOMAIN` → backend (port 8000)
- `dashboard.$DOMAIN` → frontend (port 80, served by Nginx inside container)
- `adminer.$DOMAIN` → adminer (port 8080)
- `traefik.$DOMAIN` → Traefik dashboard (port 8080)

---

## Application Deployment

### Environment Variables

The following variables **must be set** and must not retain the `changethis` default:

| Variable                   | Purpose |
|----------------------------|---------|
| `SECRET_KEY`               | JWT signing key |
| `POSTGRES_PASSWORD`        | Database password |
| `FIRST_SUPERUSER_PASSWORD` | Initial admin password |
| `DOMAIN`                   | Base domain (e.g. `fastapi-project.example.com`) |
| `STACK_NAME`               | Docker Compose project label (e.g. `fastapi-project-example-com`) |
| `ENVIRONMENT`              | `staging` or `production` |
| `FRONTEND_HOST`            | Full URL of the frontend (e.g. `https://dashboard.$DOMAIN`) |
| `BACKEND_CORS_ORIGINS`     | Comma-separated allowed origins |

Generate secure values with: `python -c "import secrets; print(secrets.token_urlsafe(32))"`

### Deploy Commands

```bash
# Copy code to server (respects .gitignore)
rsync -av --filter=":- .gitignore" ./ root@your-server.example.com:/root/code/app/

cd /root/code/app/

# Build images — explicitly use compose.yml only (no compose.override.yml in prod)
docker compose -f compose.yml build

# Start/update stack
docker compose -f compose.yml up -d
```

Passing `-f compose.yml` explicitly **disables** the auto-loading of
`compose.override.yml`. This is intentional — `compose.override.yml` contains
dev-only settings (hot-reload command, exposed Postgres port, mailcatcher, etc.)
that must not be present in staging or production.

---

## prestart Service — What It Does

`prestart` runs `bash scripts/prestart.sh` which executes in order:

1. `python app/backend_pre_start.py` — retries a `SELECT 1` against PostgreSQL
   for up to 5 minutes (60 × 5 attempts, 1s wait) using tenacity.
2. `alembic upgrade head` — applies all pending Alembic migrations.
3. `python app/initial_data.py` — calls `init_db(session)` which creates the
   first superuser if it does not already exist.

If any step fails, `prestart` exits non-zero. Because `backend` depends on
`prestart` with `condition: service_completed_successfully`, Docker will not
start the backend process and will mark it as failed.

---

## Backend Container

Base image: `python:3.10`

Build uses `uv` (copied from `ghcr.io/astral-sh/uv:0.9.26`) with:
- `UV_COMPILE_BYTECODE=1` — precompiles `.pyc` at build time.
- `UV_LINK_MODE=copy` — avoids hardlink issues across layers.
- Two-stage `uv sync --frozen`: first deps-only layer (cache-friendly), then
  full workspace sync.

Production startup command: `fastapi run --workers 4 app/main.py`

Backend healthcheck (from compose.yml):
```
test: ["CMD", "curl", "-f", "http://localhost:8000/api/v1/utils/health-check/"]
interval: 10s, timeout: 5s, retries: 5
```

---

## Frontend Container

Three-stage Dockerfile:
1. `deps` — `oven/bun:1`, installs `node_modules` only (used by local dev as build target).
2. `build-stage` — adds source, runs `bun run build` with `VITE_API_URL` build arg.
3. Final stage — `nginx:1`, copies `/app/frontend/dist/` and custom nginx config.

In production, `VITE_API_URL` is set to `https://api.$DOMAIN` (from compose.yml
build args).

---

## Rollback

```bash
# On the server — roll back to the previous image tag
docker compose -f compose.yml down
# Edit TAG variable in .env or override on the command line
TAG=<previous-tag> docker compose -f compose.yml up -d
```

No data is lost by rolling back the application images. If the migration that
needs to be undone is destructive, run `alembic downgrade -1` (or to a specific
revision) inside the `prestart` or `backend` container before downgrading the image.
