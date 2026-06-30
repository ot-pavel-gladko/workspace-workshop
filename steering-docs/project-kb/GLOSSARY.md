# Glossary

Project-specific terminology for the full-stack-fastapi-template. Industry-general
terms (JWT, SMTP, ACME, ORM…) live in `domain-kb/GLOSSARY.md`; this file covers how
those concepts are named and used **in this product**. Grounded in `backend/app/`.

| Term | Meaning | Notes / source |
|------|---------|----------------|
| **User** | Account holder entity: email, hashed password, active/superuser flags, full name, created_at. | `models.py` |
| **Item** | Generic per-user owned resource (title, description, owner). The template's example domain. | `models.py` |
| **Superuser** | A `User` with `is_superuser=True`; may manage all users and items and reach admin endpoints. | `api/deps.py`, routes |
| **Owner / owner_id** | The `User` a given `Item` belongs to; non-superusers are scoped to their own items. | `models.py`, `items.py` |
| **Access token** | The login JWT (`sub`=user id, `exp`), sent as `Authorization: Bearer …`; ~8-day lifetime. | `security.py`, `config.py` |
| **Password reset token** | A separate JWT (carries email, `exp`, `nbf`) emailed for recovery; 48-hour lifetime. | `utils.py`, `config.py` |
| **Prestart** | The one-off compose service that runs Alembic migrations and seeds the first superuser before `backend` starts. | `compose.yml`, `backend/scripts` |
| **First superuser** | The bootstrap admin account seeded from `FIRST_SUPERUSER` / `FIRST_SUPERUSER_PASSWORD` (default `admin@example.com` / `changethis`). | `core/db.py`, `config.py` |
| **Generated client** | The TypeScript SDK auto-generated from the backend's OpenAPI spec (`@hey-api/openapi-ts`); the frontend calls the API only through it. | `frontend/src/client/` |
| **`*Public` model** | Pydantic response models (`UserPublic`, `ItemPublic`, …) that shape API output, excluding secrets like `hashed_password`. | `models.py` |
| **`changethis`** | Sentinel placeholder for secrets; the app warns in local and refuses to boot in staging/prod if left unchanged. | `core/config.py` |
| **Health check** | Public `GET /api/v1/utils/health-check/` returning `true`; used by the Docker healthcheck and the workshop dev script. | `api/routes/utils.py` |
| **`ENVIRONMENT`** | Runtime mode: `local` \| `staging` \| `production`; gates secret validation and the private dev endpoint. | `core/config.py`, `api/main.py` |

## Naming conventions

- **Backend (Python):** modules/functions `snake_case`; SQLModel/Pydantic classes
  `PascalCase`; API models suffixed by intent (`…Create`, `…Update`, `…Public`).
- **Frontend (TypeScript):** components `PascalCase`; route files map to URL paths
  via TanStack file-based routing; generated services named `<Area>Service`
  (e.g. `UsersService`, `ItemsService`, `LoginService`).
- **API paths:** versioned under `/api/v1`, grouped by area (`/login`, `/users`,
  `/items`, `/utils`, `/private`).
