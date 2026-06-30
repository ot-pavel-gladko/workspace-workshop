# Bounded Contexts

The ubiquitous language for the full-stack-fastapi-template product. Entity names
here are canonical — agents and code refer to them by these names. Grounded in
`backend/app/models.py`, `backend/app/crud.py`, and `backend/app/api/routes/`.

## Identity & Access

Owns authentication, authorization, and the account lifecycle.

- **User** — the account holder. Fields: `id` (UUID PK), `email` (unique, indexed),
  `hashed_password`, `is_active` (default true), `is_superuser` (default false),
  `full_name` (optional), `created_at` (UTC). Defined in `models.py`.
- **Access Token** — a JWT (`Token` / `TokenPayload` models) issued on login,
  carrying the user id as `sub` and an `exp` claim. Bearer auth via
  `OAuth2PasswordBearer`. Default lifetime: 8 days (`ACCESS_TOKEN_EXPIRE_MINUTES`).
- **Password Reset Token** — a separate JWT (`NewPassword` model) carrying the user's
  email, `exp`, and `nbf`; valid 48h (`EMAIL_RESET_TOKEN_EXPIRE_HOURS`).
- **Roles:** a binary model — regular user vs **superuser**. There is no granular RBAC;
  `is_superuser` gates all administrative endpoints (`api/deps.py`
  `get_current_active_superuser`).

Key rules: passwords hashed with Argon2 (bcrypt fallback); authentication is
constant-time even for unknown emails (timing-attack prevention, `crud.py`); a
superuser cannot delete their own account (`api/routes/users.py`).

## Items (owned resource)

The template's generic example domain — a per-user resource demonstrating ownership
and CRUD.

- **Item** — fields: `id` (UUID PK), `title` (1–255 chars, required),
  `description` (optional, ≤255), `owner_id` (FK → `user.id`), `created_at` (UTC).
  Defined in `models.py`.
- **Ownership rule:** every Item belongs to exactly one User via `owner_id`.
  Non-superusers may read/modify only their own items; superusers see all
  (`api/routes/items.py`).
- **Cascade rule:** deleting a User cascade-deletes that user's Items
  (relationship `cascade_delete=True` in `models.py`).

## Administration

A capability that spans the above contexts rather than a separate data domain.

- Superuser-only management of **any** User (create/list/update/delete) and visibility
  into all Items.
- Surfaced in the frontend `/admin` route (guarded by an `is_superuser` check) and in
  the superuser-only backend endpoints under `/api/v1/users`.

## Conventions

- One context per top-level entry; entity names above are canonical.
- Cross-context interactions and external systems live in `INTEGRATIONS.md`, not here.
- The data model is deliberately small — it is a template baseline, meant to be
  extended with real domain entities per engagement.
