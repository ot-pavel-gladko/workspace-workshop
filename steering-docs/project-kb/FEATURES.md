# Feature Map

The product surface area, organised by user-visible capability. Grounded in
`backend/app/api/routes/` and `frontend/src/routes/` + `frontend/src/components/`.

## Authentication & account access (public)

- **Login** (`/login`) — email + password; on success the backend issues a JWT
  (`POST /api/v1/login/access-token`) which the SPA stores in `localStorage`.
- **Sign up** (`/signup`) — public self-registration (`POST /api/v1/users/signup`)
  with full name, email, password + confirmation (Zod-validated).
- **Password recovery** (`/recover-password`) — request a reset email
  (`POST /api/v1/password-recovery/{email}`). Always returns success to prevent
  email enumeration.
- **Password reset** (`/reset-password?token=…`) — set a new password using the
  emailed token (`POST /api/v1/reset-password/`).

User journey (recovery): request → backend emails a tokenized link → user opens
`/reset-password` → submits new password → redirected to login.

## User self-service (authenticated)

- **Dashboard** (`/`) — landing page greeting the current user.
- **My profile** (`/settings` → Profile tab) — view/edit own `full_name` and `email`
  (`PATCH /api/v1/users/me`).
- **Change password** (`/settings` → Password tab) — `PATCH /api/v1/users/me/password`.
- **Delete account** (`/settings` → Danger Zone) — self-delete for non-superusers
  (`DELETE /api/v1/users/me`).
- **Appearance / dark mode** — Light / Dark / System theme toggle (next-themes;
  persisted in `localStorage`).

## Items CRUD (authenticated)

`/items` page backed by `/api/v1/items`:

- **List** — paginated table; regular users see only their items, superusers see all.
- **Add** (`AddItem` modal → `POST`), **Edit** (`EditItem` → `PUT`),
  **Delete** (`DeleteItem` confirm → `DELETE`).
- **Copy ID** — copy an item's UUID to the clipboard from the table.
- React Query invalidates the `["items"]` cache after each mutation so the table
  refetches automatically.

## Administration (superuser only)

`/admin` page (guarded by an `is_superuser` check) backed by superuser-only
`/api/v1/users` endpoints:

- List all users; **Add user** (with `is_superuser` / `is_active` flags),
  **Edit user**, **Delete user** (warns that the user's items are cascade-deleted).
- The current user's row is badged "You".

## Operational endpoints

- **Health check** — public `GET /api/v1/utils/health-check/` (returns `true`); used
  by the Docker healthcheck.
- **Test email** — superuser-only `POST /api/v1/utils/test-email/`.
- **Private dev endpoint** — `POST /api/v1/private/users/` exists **only** when
  `ENVIRONMENT == "local"` (a test helper).

## Cross-cutting concerns

- **Authentication & authorisation** — JWT bearer tokens; superuser vs regular-user
  split enforced by FastAPI dependencies; SPA route guards mirror this client-side.
- **Observability** — optional Sentry error tracking (enabled when `SENTRY_DSN` set).
- **Internationalisation** — not implemented in the template.
- **Compliance / audit** — no audit log in the baseline.

## Out of scope

- Multi-tenant org structures, granular RBAC, and audit logging are deliberately not
  part of the template baseline.
