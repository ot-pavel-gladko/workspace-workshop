# backend-api

## Purpose

Assembles the FastAPI HTTP surface for the application. All REST endpoints are registered under the `/api/v1` prefix via a single `api_router` composed from per-domain sub-routers (login, users, items, utils, and a local-only private router). Shared dependency injection — database sessions, JWT token validation, and current-user resolution — is centralised in `deps.py` and consumed by every route module.

## Public Interface

`api_router` (from `backend/app/api/main.py`) is the single export mounted by the top-level FastAPI app.

### Shared dependencies (from `deps.py`)

| Name | Type | Description |
|------|------|-------------|
| `SessionDep` | `Annotated[Session, Depends(get_db)]` | SQLModel DB session, one per request |
| `TokenDep` | `Annotated[str, Depends(reusable_oauth2)]` | Raw Bearer token from Authorization header |
| `CurrentUser` | `Annotated[User, Depends(get_current_user)]` | Authenticated, active User object |
| `get_current_active_superuser` | dependency function | Raises 403 if `current_user.is_superuser` is False |

### Endpoints

All paths below are relative to `/api/v1`.

| Method | Path | Auth | Router file |
|--------|------|------|-------------|
| POST | `/login/access-token` | None (form credentials) | login |
| POST | `/login/test-token` | CurrentUser | login |
| POST | `/password-recovery/{email}` | None | login |
| POST | `/reset-password/` | None | login |
| POST | `/password-recovery-html-content/{email}` | Superuser | login |
| GET | `/users/` | Superuser | users |
| POST | `/users/` | Superuser | users |
| GET | `/users/me` | CurrentUser | users |
| PATCH | `/users/me` | CurrentUser | users |
| PATCH | `/users/me/password` | CurrentUser | users |
| DELETE | `/users/me` | CurrentUser (non-superuser) | users |
| POST | `/users/signup` | None | users |
| GET | `/users/{user_id}` | CurrentUser (superuser or self) | users |
| PATCH | `/users/{user_id}` | Superuser | users |
| DELETE | `/users/{user_id}` | Superuser | users |
| GET | `/items/` | CurrentUser | items |
| POST | `/items/` | CurrentUser | items |
| GET | `/items/{id}` | CurrentUser (owner or superuser) | items |
| PUT | `/items/{id}` | CurrentUser (owner or superuser) | items |
| DELETE | `/items/{id}` | CurrentUser (owner or superuser) | items |
| POST | `/utils/test-email/` | Superuser | utils |
| GET | `/utils/health-check/` | None | utils |
| POST | `/private/users/` | None (local env only) | private |

## Internal Structure

```
backend/app/api/
  main.py          — assembles api_router from sub-routers; gates private router on ENVIRONMENT=="local"
  deps.py          — all shared FastAPI dependencies (session, token, user resolution)
  routes/
    login.py       — auth and password-recovery flows
    users.py       — user CRUD + self-service account management
    items.py       — item CRUD with ownership-scoped access
    utils.py       — health-check and test-email helpers
    private.py     — direct user creation for local dev/seeding
    __init__.py    — empty package marker
  __init__.py      — empty package marker
```

`main.py` is the only file other modules should import from this package; route files are internal.

## Dependencies

**Internal modules:**
- `app.core.config` — `settings` (API prefix, environment, token config, email flags)
- `app.core.security` — `create_access_token`, `get_password_hash`, `verify_password`, `ALGORITHM`
- `app.core.db` — `engine` (used by `get_db`)
- `app.models` — `User`, `Item`, `Token`, `TokenPayload`, `UserPublic`, `UserCreate`, `UserUpdate`, `UserRegister`, `UserUpdateMe`, `UsersPublic`, `UpdatePassword`, `NewPassword`, `Message`
- `app.crud` — `authenticate`, `get_user_by_email`, `create_user`, `update_user`
- `app.utils` — email generation and sending helpers (`generate_password_reset_token`, `send_email`, etc.)

**External libraries:**
- `fastapi` — `APIRouter`, `Depends`, `HTTPException`, `status`, `OAuth2PasswordBearer`, `OAuth2PasswordRequestForm`
- `sqlmodel` — `Session`, `select`, `col`, `func`, `delete`
- `PyJWT` (`jwt`) — token decode in `deps.py`
- `pydantic` — `ValidationError`, `EmailStr`

## Conventions

- **Auth via deps** — inject `CurrentUser` (any authenticated user) or `Depends(get_current_active_superuser)` as a route `dependencies=[]` entry for superuser-only routes. Never re-implement token logic inside a route.
- **Response models** — always declare `response_model=` on every endpoint; use `UserPublic` / `ItemPublic` shapes from `app.models`, never raw ORM objects.
- **Pagination** — list endpoints accept `skip: int = 0, limit: int = 100` query params; return a wrapper model with `data` list and `count` total (e.g. `UsersPublic`, `ItemsPublic`).
- **Superuser guards** — use `dependencies=[Depends(get_current_active_superuser)]` on the router decorator; do not gate inside function bodies unless mixed-permission logic is required.
- **Ownership scoping** — item routes check `item.owner_id == current_user.id` and fall back to superuser bypass before raising 403/404.
- **Environment gates** — use `settings.ENVIRONMENT == "local"` in `main.py` to conditionally include routers; do not add environment checks inside route handlers.

## Files

| Path | One-line role |
|------|---------------|
| `backend/app/api/main.py` | Assembles `api_router`; conditionally mounts private router for local env |
| `backend/app/api/deps.py` | Shared dependencies: DB session, token extraction, user auth, superuser guard |
| `backend/app/api/routes/login.py` | OAuth2 token login, token test, password recovery and reset endpoints |
| `backend/app/api/routes/users.py` | Full user CRUD plus self-service profile and password management |
| `backend/app/api/routes/items.py` | Item CRUD with per-owner scoping and superuser override |
| `backend/app/api/routes/utils.py` | Health-check and superuser-only test-email endpoints |
| `backend/app/api/routes/private.py` | Local-only direct user creation endpoint (dev/seeding use) |
| `backend/app/api/routes/__init__.py` | Empty package marker |
| `backend/app/api/__init__.py` | Empty package marker |
