# Project Goals

## What this product is

A **production-ready full-stack web application template**: a FastAPI (Python)
backend and a React (TypeScript) frontend, wired together with JWT authentication,
a PostgreSQL database, email-based password recovery, and a Docker Compose
deployment story that includes automatic HTTPS. It is distributed as a
[Copier](https://copier.readthedocs.io/) template — teams generate a new project
from it and start shipping features instead of re-building the same auth/CRUD/deploy
scaffolding every time.

Source of truth: `README.md`, `backend/`, `frontend/`, and the `compose*.yml` files
in the `full-stack-fastapi-template` repo.

## Why it exists (objectives)

1. **Eliminate green-field setup cost.** Ship a working, secure baseline — auth,
   user management, a generic owned resource (Items), migrations, and CI — so a new
   project's first commit is feature work, not plumbing.
2. **Demonstrate a modern, end-to-end stack done correctly.** Typed models flow from
   the backend (SQLModel/Pydantic) into an auto-generated TypeScript client, so the
   frontend calls the backend through generated, type-safe services.
3. **Be deployable as-is.** A single `docker compose` story takes the same code from
   a laptop to staging and production, with Traefik terminating TLS and renewing
   Let's Encrypt certificates automatically.
4. **Be secure by default.** Argon2 password hashing (bcrypt fallback), JWT bearer
   tokens, superuser role separation, and timing-attack / email-enumeration
   protections are built in (see `backend/app/core/security.py`, `crud.py`).

## Intended users

- **Engineering teams** starting a new full-stack product who want a vetted baseline.
- **The DataArt workspace agents** in this workspace, who use this repo as the
  reference product when reasoning about features, architecture, and delivery.

## Scope phases (as the template presents them)

- **Phase 1 — Run it.** Stand up the stack locally via Docker Compose; log in as the
  seeded superuser; explore the API docs and the dashboard.
- **Phase 2 — Build features.** Add models + Alembic migrations on the backend,
  regenerate the frontend client, and build UI against the typed services.
- **Phase 3 — Deploy.** Promote to staging and production behind Traefik with HTTPS,
  driven by `deployment.md` and the CI/CD flow.

## Out of scope / known placeholders

- Business stakeholders, delivery dates, and client-specific requirements are **not**
  part of a template and are intentionally left unstated here.
- This KB describes the **template as product**; a real engagement layers its own
  product goals on top of this baseline.

## Success criteria

- A generated project boots with `docker compose` and serves the dashboard + API docs.
- Authentication, user management, and Items CRUD work without code changes.
- The same compose definitions deploy to staging/production with automatic HTTPS.
