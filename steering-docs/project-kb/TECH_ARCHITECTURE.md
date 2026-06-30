# Tech Architecture

Runtime topology, data flow, and deployment shape for the full-stack-fastapi-template.
Source-of-truth for cross-repo questions. Grounded in `backend/pyproject.toml`,
`frontend/package.json`, `compose*.yml`, `development.md`, and `deployment.md`.

## Runtime topology

```
Browser ──HTTPS──> Traefik ──> Frontend (React SPA, served static)
                      │
                      └──────> Backend (FastAPI /api/v1) ──> PostgreSQL
                                       │
                                       ├─> SMTP (transactional email)
                                       └─> Sentry (optional error tracking)
```

The React SPA talks to the backend **only** through an auto-generated, type-safe
TypeScript client (built from the backend's OpenAPI schema). The JWT access token is
stored in `localStorage` and injected as a Bearer header on every request.

## Backend (Python)

- **FastAPI** (>=0.114) — async web framework, OpenAPI docs at `/docs`.
- **SQLModel** (SQLAlchemy + Pydantic) for the ORM; **Pydantic v2** for validation;
  **pydantic-settings** for config.
- **PostgreSQL 18** via **psycopg v3**; schema migrations via **Alembic**.
- **Auth/security:** **PyJWT** (HS256) for tokens; **pwdlib** with **Argon2** (bcrypt
  fallback) for password hashing.
- **Email:** `emails` + **Jinja2** templates; **httpx** HTTP client; **tenacity**
  retries; **sentry-sdk** for monitoring.
- **Tooling:** `uv` (deps/venv), **ruff** (lint/format), **mypy** (types),
  **pytest** + coverage.

Entry points: `app/main.py` (FastAPI app), `app/api/main.py` (router wiring under
`/api/v1`), `app/core/` (config, db engine, security), `app/models.py`,
`app/crud.py`, `app/api/routes/` (login, users, items, utils, private).

## Frontend (TypeScript)

- **React 19** + **TypeScript 5** built with **Vite 7**.
- **TanStack Router** (file-based routing), **TanStack Query** (server state/caching),
  **TanStack Table** (data tables).
- **Tailwind CSS v4** + **shadcn/ui** (Radix primitives) for components;
  **next-themes** for light/dark/system mode; **Sonner** for toasts;
  **react-hook-form** + **Zod** for forms/validation.
- **Generated client** via **@hey-api/openapi-ts**; **axios** under the hood.
- **Tooling:** **Biome** (lint/format), **Playwright** (E2E), **bun** for scripts.

## Repos

| Repo | Language | Role |
|------|----------|------|
| `full-stack-fastapi-template` | Python + TypeScript | The product: FastAPI backend (`backend/`) + React frontend (`frontend/`), deployed together via Docker Compose. |

## Deployment shape

- **Containers / services** (`compose.yml`): `db` (Postgres), `prestart`
  (migrations + superuser seed, runs once), `backend` (FastAPI, healthchecked on
  `/api/v1/utils/health-check/`), `frontend`, `adminer`. Dev overrides add a Traefik
  `proxy` and `mailcatcher` (`compose.override.yml`); the workshop override
  (`compose.dev.yml`) pins uncommon host ports and keeps Postgres internal.
- **Environments:** `local`, `staging` (`staging.example.com`), `production`
  (`example.com`) — distinguished by `ENVIRONMENT`, `DOMAIN`, and per-env secrets.
- **Ingress / TLS:** public **Traefik** terminates HTTPS and auto-renews Let's Encrypt
  (ACME) certs; services are discovered by Docker labels on a shared `traefik-public`
  network (`compose.traefik.yml`).
- **CI/CD:** **GitHub Actions** — push to `master` → staging, `release` → production,
  via self-hosted runners (per `deployment.md`).

## Cross-cutting

- **Observability** — optional Sentry; FastAPI access logs; Traefik dashboard.
- **Secrets** — environment / `.env` (git-ignored); critical secrets must not remain
  `changethis` outside local (enforced in `core/config.py`).
- **Migrations** — Alembic; the `prestart` service runs `alembic upgrade head` before
  the backend starts, so schema changes apply in deploy order automatically.
