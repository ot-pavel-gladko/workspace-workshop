# full-stack-fastapi-template — Code KB (Module Index)

Navigation index for the `full-stack-fastapi-template` repo. A monorepo with a
**FastAPI/PostgreSQL backend** (`backend/`) and a **React/TypeScript dashboard**
(`frontend/`), joined by a generated, typed API client. Use this map to route to
the right `modules/{name}/KB.md` before opening source. 90 source files across
9 modules (tests, generated client, and `routeTree.gen.ts` excluded from indexing).

See also the project-level KB: [[../../project-kb/TECH_ARCHITECTURE]],
[[../../project-kb/DOMAINS]], [[../../project-kb/FEATURES]].

## Module map

| Module | Tier | Purpose | Files |
|--------|------|---------|------:|
| [backend-api](modules/backend-api/KB.md) | backend | FastAPI HTTP surface — router assembly, route dependencies, all `/api/v1` endpoints (auth, users, items, utils, local-only private). | 9 |
| [backend-core](modules/backend-core/KB.md) | backend | Foundations every backend module imports — `settings`, the DB `engine` + `init_db`, and security (JWT, password hashing). | 4 |
| [backend-domain](modules/backend-domain/KB.md) | backend | Domain layer — SQLModel entities/schemas (`User`, `Item`, tokens) and CRUD persistence operations. | 2 |
| [backend-platform](modules/backend-platform/KB.md) | backend | App assembly & ops glue — app factory (CORS/Sentry/router mount), startup & pre-start scripts, email utilities, Alembic env. | 7 |
| [frontend-routing-pages](modules/frontend-routing-pages/KB.md) | frontend | TanStack Router file-based routes — public auth pages + authenticated `_layout` screens — and `main.tsx` app entry. | 11 |
| [frontend-features](modules/frontend-features/KB.md) | frontend | Feature CRUD components grouped by domain — Admin (users), Items, UserSettings, Pending skeletons. | 16 |
| [frontend-layout-common](modules/frontend-layout-common/KB.md) | frontend | Shared app chrome — sidebar, generic `DataTable`, auth layout, theme provider, error/404 fallbacks. | 11 |
| [frontend-ui-primitives](modules/frontend-ui-primitives/KB.md) | frontend | shadcn/ui primitives (Radix + Tailwind) — buttons, inputs, dialogs, tables, etc. Presentational only. | 24 |
| [frontend-state-hooks](modules/frontend-state-hooks/KB.md) | frontend | Client-side hooks (`useAuth`, toast, clipboard, mobile) and shared helpers (`cn()`, error/validation utils). | 6 |

## Relationships

```
                    backend-api ──uses──▶ backend-domain ──▶ backend-core
                        ▲                      ▲                 ▲
                        │                      │                 │
                  backend-platform ───────────┴─────────────────┘
                  (app factory mounts api router; init/seed; email)
                        │
                  exposes OpenAPI at /api/v1
                        │
                        ▼  (scripts/generate-client.sh)
              frontend/src/client  ── generated typed client (not indexed)
                        ▲
                        │ consumed by
   frontend-routing-pages ─▶ frontend-features ─▶ frontend-ui-primitives
            │                      │                      ▲
            └─▶ frontend-layout-common ───────────────────┘
            └─▶ frontend-state-hooks (useAuth gates routes; helpers everywhere)
```

- **Backend dependency direction**: `backend-api` → `backend-domain` → `backend-core`;
  `backend-platform` wires everything into the `app` and owns startup/migrations/email.
- **The contract between tiers** is the generated client under
  `frontend/src/client/` (produced from the backend OpenAPI schema). It is
  generated code — excluded from this index but depended on by every frontend
  module that calls the API. Regenerate it when backend routes/models change.
- **Frontend layering**: routes/pages compose feature components, which compose
  ui-primitives and shared layout pieces; `useAuth` (state-hooks) guards routes.

## Entry points

- **Backend app**: `backend/app/main.py` → `app` (FastAPI); served via
  `fastapi run`/uvicorn. API mounted at `settings.API_V1_STR` (`/api/v1`);
  docs at `/docs`, `/redoc`. → [backend-platform](modules/backend-platform/KB.md),
  [backend-api](modules/backend-api/KB.md).
- **DB seeding / pre-start**: `python -m app.initial_data`,
  `app/backend_pre_start.py`, `app/tests_pre_start.py`. → backend-platform.
- **Migrations**: Alembic in `backend/app/alembic/` (run by the `prestart`
  Compose service). → backend-platform.
- **Frontend app**: `frontend/src/main.tsx` → `RouterProvider` +
  `QueryClientProvider` + `ThemeProvider`; dev server on `:5173`. →
  [frontend-routing-pages](modules/frontend-routing-pages/KB.md).
- **Auth login**: `POST /api/v1/login/access-token`. → backend-api;
  client side via `useAuth` → frontend-state-hooks.

## Conventions (repo-wide)

- **Backend**: Pydantic/SQLModel schema split (`Base`/`Create`/`Update`/`Public`);
  UUID primary keys; auth via FastAPI dependencies (`CurrentUser`, `SessionDep`,
  superuser guard); secrets from env with the `changethis` guard outside `local`.
  Python ≥3.10, `uv` deps, `ruff`/`mypy`/`ty` lint.
- **Frontend**: TanStack Router file-based routes (`_layout` = authenticated
  shell), TanStack Query for server state with invalidation on mutation,
  `react-hook-form` + `zod` for forms, `cn()` for class merging, shadcn/ui
  primitives. Bun package manager, Biome lint/format.
- **Cross-tier**: never hand-edit `frontend/src/client/` — regenerate from the
  backend OpenAPI schema (`scripts/generate-client.sh`, enforced by a pre-commit
  hook). See [[../../project-kb/devops/PATTERNS]].

## Refresh

`_index/files.jsonl` caches one summary record (path, sha256, summary, exports,
deps, framework hints) per source file — rerun Stage 1 of `extract-code-kb` to
refresh only changed files; module KBs and this index are regenerated on demand.
