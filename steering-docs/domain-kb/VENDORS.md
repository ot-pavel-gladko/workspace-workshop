# Vendor & Integration Know-How

Reusable, project-agnostic facts about technologies and integration partners
commonly used in full-stack delivery. Protocol-level facts plus gotchas; extend
with edge cases and sandbox-vs-prod gaps as the team learns them.

For project-specific per-supplier mapping (env credentials, queue maps, data model
decisions), see `../project-kb/INTEGRATIONS.md`.

---

## How to use this file

When you discover a vendor quirk that any team integrating with the same supplier
would also hit, add it under the relevant section. Examples worth recording:

- Working auth flow (token rotation, scope quirks, certificate setup).
- API/version that actually works vs. one that looks correct but silently fails.
- Mapping edge cases (field semantics, multi-value handling, currency/timezone).
- Sandbox-vs-prod gaps the vendor docs don't mention.

Avoid: client business logic, project requirements, env-specific credentials, PII.

---

## PostgreSQL

- **Protocol:** SQL over the PostgreSQL wire protocol (default port 5432). Drivers:
  `psycopg` (v3) or `asyncpg` for Python.
- **Identity:** username/password (or TLS client certs); connection string is a DSN
  (`postgresql+psycopg://user:pass@host:5432/db`).
- **Gotchas:** a container is not "ready" when the port opens — wait on `pg_isready`
  or a real `SELECT 1`, not just TCP. Schema changes belong in ordered migrations,
  never ad-hoc DDL in prod. UUID PKs need the `uuid`/`pgcrypto` extension or app-side
  generation. Connection-pool exhaustion is a top production failure mode.

## SMTP email providers

- **Protocol:** SMTP (submission on 587 with STARTTLS, or 465 implicit TLS). Port 25
  is largely blocked by cloud providers for egress.
- **Identity:** SMTP username + password / app password, or an API key for HTTP APIs.
- **Gotchas:** deliverability depends on SPF/DKIM/DMARC DNS records, not code.
  Transactional mail should be sent asynchronously — SMTP latency must not block a
  request. Locally, capture mail with a fake SMTP sink (e.g. Mailcatcher/Mailpit)
  instead of sending real messages.

## Sentry (error monitoring)

- **Protocol:** SDK ships events to an ingest endpoint identified by a **DSN**.
- **Identity:** the DSN itself (project-scoped); enable only when set so local/dev
  runs stay quiet.
- **Gotchas:** scrub PII before sending; sample high-volume traces to control cost;
  tag events with environment/release to make them actionable.

## Traefik + Let's Encrypt (ACME)

- **Protocol:** reverse proxy with dynamic configuration via container labels; ACME
  for automatic TLS certs.
- **Gotchas:** the **TLS-ALPN-01** challenge needs port 443 reachable; **HTTP-01**
  needs port 80. Persist the ACME store (e.g. `acme.json`) on a volume or you
  re-issue certs every restart and hit Let's Encrypt **rate limits** (per
  registered domain/week). Use the **staging** ACME endpoint while iterating.

## GitHub Actions (CI/CD)

- **Protocol:** YAML workflows under `.github/workflows/` triggered by repo events
  (push, pull_request, release) or schedules.
- **Identity:** the auto-provided `GITHUB_TOKEN` (scoped per run) or app/PAT secrets.
- **Gotchas:** secrets are not exposed to forked-PR runs by default; self-hosted
  runners need network reach to deploy targets and should be labelled per
  environment; pin third-party actions to a SHA to avoid supply-chain drift.

## Docker / Docker Compose

- **Protocol:** OCI images; Compose orchestrates multi-service local/prod stacks.
- **Gotchas:** `depends_on` only orders start, not readiness — gate on healthchecks
  or a one-off init/migration service. Bind-mount source for live reload in dev;
  on macOS/Windows the VM filesystem boundary often needs file-polling for watchers.
  Multiple `-f` compose files merge in order; passing `-f` disables auto-loading of
  `compose.override.yml`.

---

## Adding a new vendor section

For each vendor include: **Protocol** (API style + auth), **Identity** (how it
authenticates), **Key field semantics**, and **Known gotchas** (sandbox-vs-prod,
rate limits, pagination). Keep it project-agnostic; promote durable findings here
from `PATTERNS.md` once they stabilise.
