# backend-core

## Purpose

Cross-cutting foundations for the FastAPI backend. Provides a single validated `settings` singleton loaded from environment variables, a SQLAlchemy/SQLModel `engine` plus a first-superuser bootstrapper (`init_db`), and security primitives for JWT access-token creation/decoding and Argon2/Bcrypt password hashing. Almost every other backend module imports from here rather than from application-level code.

## Public Interface

### `settings` — `app.core.config.Settings` singleton

| Group | Fields |
|-------|--------|
| **DB** | `POSTGRES_SERVER`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `SQLALCHEMY_DATABASE_URI` (computed) |
| **SMTP / email** | `SMTP_HOST`, `SMTP_PORT`, `SMTP_TLS`, `SMTP_SSL`, `SMTP_USER`, `SMTP_PASSWORD`, `EMAILS_FROM_EMAIL`, `EMAILS_FROM_NAME`, `EMAIL_RESET_TOKEN_EXPIRE_HOURS`, `emails_enabled` (computed) |
| **Auth** | `SECRET_KEY`, `ACCESS_TOKEN_EXPIRE_MINUTES` (default 11 520 = 8 days), `FIRST_SUPERUSER`, `FIRST_SUPERUSER_PASSWORD` |
| **Env / misc** | `ENVIRONMENT` (`local`/`staging`/`production`), `API_V1_STR`, `FRONTEND_HOST`, `BACKEND_CORS_ORIGINS`, `all_cors_origins` (computed), `SENTRY_DSN` |

### `engine` — `app.core.db`
SQLModel/SQLAlchemy engine built from `settings.SQLALCHEMY_DATABASE_URI`.

### `init_db(session)` — `app.core.db`
Bootstraps the first superuser if absent. Called at application startup; assumes Alembic has already applied migrations.

### `create_access_token(subject, expires_delta)` — `app.core.security`
Returns a signed HS256 JWT string. Encodes `sub` and `exp` claims; uses `settings.SECRET_KEY`.

### `get_password_hash(password)` / `verify_password(plain, hashed)` — `app.core.security`
Hash with Argon2 (primary) + Bcrypt (fallback) via `pwdlib.PasswordHash`. `verify_password` returns `(bool, updated_hash | None)` to support transparent re-hashing.

## Internal Structure

| File | Responsibility |
|------|---------------|
| `core/config.py` | `Settings(BaseSettings)` — env-var parsing, CORS helpers, `SQLALCHEMY_DATABASE_URI` computed field, `changethis` secret guard |
| `core/db.py` | Engine construction, `init_db()` first-superuser seed |
| `core/security.py` | `ALGORITHM` constant, `password_hash` instance, `create_access_token`, `get_password_hash`, `verify_password` |
| `core/__init__.py` | Empty package marker |

## Dependencies

| Library | Used for |
|---------|----------|
| `pydantic-settings` | `BaseSettings` env-var loading with `.env` file support |
| `pydantic` | Field validators, `computed_field`, `model_validator`, `PostgresDsn` |
| `sqlmodel` / `sqlalchemy` | `create_engine`, `Session`, `select` |
| `pwdlib` + `argon2` + `bcrypt` | Password hashing and verification |
| `pyjwt` (`jwt`) | JWT encoding (HS256) |

Nearly every other backend module (`api/`, `crud.py`, `models.py`, `utils.py`, `tests/`) imports `settings`, `engine`, or security helpers from this package.

## Conventions

- **`changethis` guard**: `_enforce_non_default_secrets` raises `ValueError` in `staging`/`production` if `SECRET_KEY`, `POSTGRES_PASSWORD`, or `FIRST_SUPERUSER_PASSWORD` equal `"changethis"`; emits a warning in `local`.
- **JWT**: HS256 algorithm, default expiry 8 days (`ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 8`).
- **Password hashing**: Argon2 as primary hasher, Bcrypt as fallback; `verify_password` returns an updated hash when rehashing is needed.
- **`SQLALCHEMY_DATABASE_URI`**: Always computed from discrete `POSTGRES_*` fields via `PostgresDsn.build`; uses `postgresql+psycopg` driver scheme.
- **`.env` location**: resolved one level above `./backend/` (repo root `.env`).

## Files

| Path | Role |
|------|------|
| `backend/app/core/config.py` | Settings singleton — env vars, CORS, DB URI, secret guards |
| `backend/app/core/db.py` | SQLModel engine + first-superuser seed (`init_db`) |
| `backend/app/core/security.py` | JWT creation, password hash/verify, ALGORITHM constant |
| `backend/app/core/__init__.py` | Empty package marker |
