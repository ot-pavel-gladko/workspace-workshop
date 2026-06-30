# backend-domain

## Purpose

Defines all persistent entities (User, Item) as SQLModel table models and the full hierarchy of Pydantic-validated API schemas derived from them. Provides the sole CRUD layer (`crud.py`) through which the rest of the backend reads and writes those entities, keeping all database I/O in one place.

## Public Interface

**User family**

| Class | Role |
|---|---|
| `UserBase` | Shared fields: `email` (unique, indexed, max 255), `is_active`, `is_superuser`, `full_name` |
| `UserCreate` | `UserBase` + `password` (8–128 chars) — admin creation payload |
| `UserRegister` | Self-registration payload (email, password, full_name — no superuser flag) |
| `UserUpdate` | All fields optional; used by admin update endpoint |
| `UserUpdateMe` | `full_name` + `email` only — current-user self-edit |
| `UpdatePassword` | `current_password` + `new_password` (both 8–128) |
| `User` | `table=True`; PK `id: UUID4`; adds `hashed_password`, `created_at` (UTC, tz-aware), `items` relationship (cascade delete) |
| `UserPublic` | `UserBase` + `id` + `created_at` — safe API response shape |
| `UsersPublic` | `data: list[UserPublic]` + `count` — paginated list response |

**Item family**

| Class | Role |
|---|---|
| `ItemBase` | `title` (1–255), `description` (optional, max 255) |
| `ItemCreate` | Identical to `ItemBase` — creation payload |
| `ItemUpdate` | `title` optional — partial update payload |
| `Item` | `table=True`; PK `id: UUID4`; `owner_id` FK → `user.id` (CASCADE DELETE); `created_at`; `owner` back-ref |
| `ItemPublic` | `ItemBase` + `id` + `owner_id` + `created_at` |
| `ItemsPublic` | `data: list[ItemPublic]` + `count` |

**Auxiliary models**

| Class | Role |
|---|---|
| `Token` | `access_token` + `token_type` ("bearer") — login response |
| `TokenPayload` | `sub: str | None` — JWT claims decoded from token |
| `NewPassword` | `token` + `new_password` (8–128) — password-reset flow |
| `Message` | `message: str` — generic API response envelope |

**CRUD functions** (`crud.py`)

| Function | Signature summary |
|---|---|
| `create_user` | `(session, user_create: UserCreate) -> User` — hashes password, inserts row |
| `update_user` | `(session, db_user: User, user_in: UserUpdate) -> User` — partial update, re-hashes if password changed |
| `get_user_by_email` | `(session, email: str) -> User | None` |
| `authenticate` | `(session, email, password) -> User | None` — constant-time comparison via `DUMMY_HASH` to prevent timing attacks; handles Argon2 hash upgrades |
| `create_item` | `(session, item_in: ItemCreate, owner_id: UUID) -> Item` |

## Internal Structure

`models.py` contains all class definitions — both `table=True` SQLModel entities and the pure-Pydantic schema variants. `crud.py` imports from `models.py` and from `app.core.security`, and is the only place that calls `session.add/commit/refresh` for these entities.

## Dependencies

- `sqlmodel` — `SQLModel`, `Field`, `Relationship`, `Session`, `select`
- `pydantic` — `EmailStr` for validated email fields
- `sqlalchemy` — `DateTime(timezone=True)` column type for aware timestamps
- `backend-core` (`app.core.security`) — `get_password_hash`, `verify_password` (Argon2-based); consumed only by `crud.py`

## Conventions

- **Schema split**: Base → Create/Update → table model → Public; keeps DB fields (`hashed_password`) off API shapes.
- **UUID PKs**: All table models use `uuid.UUID` with `default_factory=uuid.uuid4`.
- **Cascade delete**: `User.items` uses `cascade_delete=True`; `Item.owner_id` FK has `ondelete="CASCADE"` — deleting a user removes their items at both ORM and DB levels.
- **Length constraints**: passwords 8–128, most strings max 255, item title min 1.
- **Timing-safe auth**: `DUMMY_HASH` (Argon2id) is verified even on missing-user lookups to equalise response time.

## Files

| Path | Role |
|---|---|
| `backend/app/models.py` | All SQLModel entity and Pydantic schema definitions |
| `backend/app/crud.py` | CRUD operations: create/update/query users, authenticate, create items |
