# External Integrations

Every system this product talks to. Agents check here before assuming an integration
is custom-built or vendor-provided. Grounded in `backend/app/core/config.py`,
`compose*.yml`, `deployment.md`, and `.env.example` (keys only — never values).

## Configured MCP integrations

- **GitHub** — `https://github.com` (wired via `.mcp.json` for the workspace agents).

## Runtime / infrastructure integrations

- **PostgreSQL** (database) — `postgres:18` image. Connection from
  `POSTGRES_SERVER`, `POSTGRES_PORT` (5432), `POSTGRES_USER`, `POSTGRES_PASSWORD`,
  `POSTGRES_DB`; DSN built as `SQLALCHEMY_DATABASE_URI` using the `psycopg` (v3)
  driver. Schema managed by **Alembic** migrations.
- **SMTP email provider** — outbound transactional email (password recovery, test
  email) via the `emails` library + Jinja2 templates. Keys: `SMTP_HOST`, `SMTP_PORT`
  (587), `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_TLS` (true), `SMTP_SSL` (false),
  `EMAILS_FROM_EMAIL`, `EMAILS_FROM_NAME`. Email is **enabled only** when `SMTP_HOST`
  and `EMAILS_FROM_EMAIL` are both set (`emails_enabled` computed property).
  In local dev, **Mailcatcher** (`schickling/mailcatcher`) captures mail instead.
- **Sentry** — optional error tracking/monitoring; activated when `SENTRY_DSN` is set
  (`sentry-sdk[fastapi]`).
- **Traefik** (`traefik:3.6`) — reverse proxy / load balancer. In production it
  terminates TLS and obtains/renews **Let's Encrypt (ACME)** certificates via the TLS
  challenge, storing them in a persistent volume. Routes by Docker service labels and
  the `DOMAIN` variable. See `compose.traefik.yml`.
- **Docker registry** — backend/frontend images published under
  `DOCKER_IMAGE_BACKEND` / `DOCKER_IMAGE_FRONTEND` for deployment.
- **Adminer** — web DB admin UI for local/ops inspection of PostgreSQL.

## CI/CD integration

- **GitHub Actions** drives CI and CD (per `deployment.md`): push to `master` deploys
  **staging**, publishing a `release` deploys **production**, both via self-hosted
  runners labelled `staging` / `production`. `.github/` ships `dependabot.yml`
  (dependency updates) and `labeler.yml` (PR labels); coverage is published via
  **smokeshow** and workflows are linted with **zizmor**.
  > Note: in this checkout the workflow YAML files are not committed — CI/CD is
  > documented in `deployment.md` rather than present as `.github/workflows/*`.

## Integration boundary conventions

- **Inbound vs outbound** call sites stay in dedicated modules — business logic never
  reaches into third-party SDKs directly (e.g. email goes through `app/utils.py`).
- **Secrets** (`SECRET_KEY`, `POSTGRES_PASSWORD`, `SMTP_PASSWORD`,
  `FIRST_SUPERUSER_PASSWORD`, `SENTRY_DSN`) come from the environment / `.env`
  (git-ignored). The config layer **refuses to boot** in staging/production if any of
  the critical secrets are still the literal `changethis`.
- **CORS** — allowed origins from `BACKEND_CORS_ORIGINS` plus `FRONTEND_HOST`.
