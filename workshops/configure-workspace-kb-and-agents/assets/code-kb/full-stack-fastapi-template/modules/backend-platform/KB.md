# backend-platform

## Purpose

Application assembly and operational glue for the FastAPI backend. Constructs the `app` instance (CORS, Sentry, router mounting), provides email utilities (Jinja2 template rendering + SMTP dispatch) and JWT password-reset token helpers, runs DB-readiness checks and first-superuser seeding at startup, and owns the Alembic migration environment.

## Public Interface

- **`app`** (`backend/app/main.py`) — the FastAPI instance imported by the ASGI server (Uvicorn); exposes all routes under `settings.API_V1_STR`.
- **Email helpers** (`backend/app/utils.py`):
  - `send_email(email_to, subject, html_content)` — SMTP dispatch via the `emails` library.
  - `generate_test_email(email_to) -> EmailData`
  - `generate_reset_password_email(email_to, email, token) -> EmailData`
  - `generate_new_account_email(email_to, username, password) -> EmailData`
  - `render_email_template(template_name, context) -> str` — Jinja2 render from `email-templates/build/`.
- **Token helpers** (`backend/app/utils.py`):
  - `generate_password_reset_token(email) -> str` — HS256 JWT with `exp`/`nbf`/`sub`.
  - `verify_password_reset_token(token) -> str | None` — decodes or returns `None` on error.
- **Entrypoints**:
  - `backend/app/backend_pre_start.py` — DB readiness probe; run before Uvicorn starts.
  - `backend/app/tests_pre_start.py` — same probe, run before pytest.
  - `backend/app/initial_data.py` — seed first superuser; invoked as `python -m app.initial_data`.
- **Alembic env** (`backend/app/alembic/env.py`) — offline and online migration modes; reads `DATABASE_URI` from `settings`.

## Internal Structure

| Group | Files |
|-------|-------|
| App entry | `main.py` |
| Startup scripts | `backend_pre_start.py`, `tests_pre_start.py`, `initial_data.py` |
| Email utilities | `utils.py`, `email-templates/build/*.html` |
| Migrations | `alembic/env.py` |
| Package marker | `__init__.py` |

## Dependencies

**External:**
- `fastapi` — app factory, routing.
- `starlette` — `CORSMiddleware`.
- `sentry-sdk` — error/performance monitoring (conditional).
- `emails` — SMTP message construction and sending.
- `jinja2` — HTML email template rendering.
- `jwt` (PyJWT) — password-reset token generation and verification.
- `tenacity` — retry logic in pre-start DB probes.
- `alembic` / `sqlalchemy` — schema migration environment.

**Internal (this repo):**
- `backend-core` — `settings` (config), `engine` (DB connection), `init_db` (seed logic), `security.ALGORITHM`.
- `backend-api` — `api_router` mounted in `main.py`.
- `backend-domain` — `SQLModel` metadata imported by `alembic/env.py` to auto-detect models.

## Conventions

- **Sentry** is initialized only when `settings.SENTRY_DSN` is set **and** `settings.ENVIRONMENT != "local"`.
- **CORS** origins come from `settings.all_cors_origins`; middleware is skipped entirely when that list is empty.
- **OpenAPI operation IDs** use `custom_generate_unique_id`: `"{first_tag}-{route_name}"`, enabling clean TypeScript client generation.
- **Pre-start ordering**: `backend_pre_start.py` runs Alembic migrations (via shell script) before Uvicorn is launched, guaranteeing schema is current on every deploy.
- **Email templates** are pre-built HTML files in `email-templates/build/`; Jinja2 renders them at call time with a context dict.
- **Password-reset tokens** expire after `settings.EMAIL_RESET_TOKEN_EXPIRE_HOURS` hours; the reset link embeds `settings.FRONTEND_HOST`.

## Files

| Path | Role |
|------|------|
| `backend/app/main.py` | FastAPI app factory: Sentry init, CORS middleware, router mount, OpenAPI ID hook |
| `backend/app/utils.py` | Email rendering/dispatch and JWT password-reset token helpers |
| `backend/app/backend_pre_start.py` | DB readiness probe with tenacity retry — runs before server startup |
| `backend/app/tests_pre_start.py` | DB readiness probe with tenacity retry — runs before test suite |
| `backend/app/initial_data.py` | Seeds first superuser via `init_db`; invoked as a one-shot script |
| `backend/app/alembic/env.py` | Alembic migration environment (offline + online modes, SQLModel metadata) |
| `backend/app/__init__.py` | Package marker (empty) |
