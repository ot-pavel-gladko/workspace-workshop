# Domain Patterns — append-only journal

Industry and vendor findings discovered during engagement work that are **non-obvious** and **reusable across engagements**. DataArt IP. Project-agnostic.

> **Recording rule.** Append a pattern **only** when the finding is:
> 1. **Non-obvious** — required reading vendor docs, scanning code, or empirical testing to discover, AND
> 2. **Reusable** — would save effort on the next engagement integrating the same vendor or concept, AND
> 3. **Project-agnostic** — describes the vendor / concept itself, not the project's mapping of it.
>
> **Do NOT record** routine answers, glossary lookups, things already obvious from `GLOSSARY.md`/`VENDORS.md`, or anything project-specific (those belong in `../project-kb/`). The agent is not pushed to record after every operation — only when a real, durable finding surfaces.
>
> When a pattern stabilises and is consulted often, promote it into the curated `VENDORS.md` (per-vendor section) or `GLOSSARY.md` (terminology), and delete it from this journal.

## Format

```
## <Short, specific title>
- **Where:** vendor / protocol / concept this applies to
- **What:** one-line description of the finding
- **Detail:** why it matters / what breaks without it / workaround
- **Source:** vendor doc URL, ticket reference, or "empirical"
- **Discovered:** YYYY-MM-DD
```

---

<!-- Agents: append new patterns below this line. Newest at the bottom. -->

## `depends_on` orders start, not readiness

- **Where:** Docker Compose (any multi-service stack with a database)
- **What:** `depends_on` waits for a container to *start*, not to become usable.
- **Detail:** A dependent service can boot before the database accepts connections, causing flaky first-run failures. Gate readiness explicitly — `depends_on: condition: service_healthy` with a real healthcheck (`pg_isready`/`SELECT 1`), or run a one-off init/migration service that must complete first. Don't rely on `sleep`.
- **Source:** empirical; Docker Compose docs
- **Discovered:** 2026-06-30

## Run schema migrations before the app starts, in deploy order

- **Where:** relational DB migrations (Alembic-style) in containerized deploys
- **What:** Apply `upgrade head` as a dedicated pre-start step, not from inside the app process.
- **Detail:** Running migrations in app startup races across replicas (N replicas → N concurrent migrations). A single one-shot "prestart" job that runs migrations + idempotent seed, gated before the app, makes schema changes apply exactly once and in order. The app then starts already at head.
- **Source:** empirical
- **Discovered:** 2026-06-30

## Persist the ACME store or you'll hit Let's Encrypt rate limits

- **Where:** Traefik / any ACME client (Let's Encrypt)
- **What:** Certificate state (`acme.json`) must live on a durable volume.
- **Detail:** If the ACME store is ephemeral, every container restart re-issues certs and can trip Let's Encrypt's per-domain weekly rate limit, breaking HTTPS until it resets. Mount the store on a volume and use the ACME **staging** endpoint while iterating to avoid burning quota.
- **Source:** empirical; Let's Encrypt rate-limit docs
- **Discovered:** 2026-06-30

## Prevent user enumeration on password-recovery endpoints

- **Where:** authentication (JWT/OAuth2 login + recovery flows)
- **What:** Return an identical response whether or not the account exists.
- **Detail:** A recovery endpoint that 404s for unknown emails but 200s for known ones leaks who has an account. Always respond "if the address exists, an email was sent." Pair with constant-time password verification (hash a dummy value when the user is absent) so latency doesn't leak existence either.
- **Source:** empirical; OWASP guidance
- **Discovered:** 2026-06-30

## Multiple `-f` compose files disable override auto-loading

- **Where:** Docker Compose CLI with layered config files
- **What:** Passing any `-f` flag turns off automatic loading of `compose.override.yml`.
- **Detail:** Compose normally auto-merges `compose.yml` + `compose.override.yml`. The moment you pass `-f` explicitly, that auto-load stops — you must list every file (`-f compose.yml -f compose.override.yml -f compose.dev.yml`) or silently lose the override layer. Files merge in the order given.
- **Source:** empirical; Docker Compose docs
- **Discovered:** 2026-06-30
