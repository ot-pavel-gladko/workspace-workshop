# CI/CD Flow — full-stack-fastapi-template

Source of truth: deployment.md, README.md, .github/dependabot.yml,
root pyproject.toml, backend/pyproject.toml.

---

## Important: Workflow Files in This Checkout

**The `.github/workflows/` directory does not exist in this checkout.** There are no
YAML workflow files committed here. Only `.github/dependabot.yml` and
`.github/labeler.yml` are present.

The deployment.md and README.md describe a GitHub Actions CI/CD system that is
intended to exist once the template is used in a real project. The section below
documents that described design so it can be implemented consistently.

---

## CI — Continuous Integration

The README badges reference two CI workflows that run on GitHub Actions:

- **Test Docker Compose** — spins up the full stack and runs integration tests
  via `docker compose exec -T backend bash scripts/tests-start.sh`.
- **Test Backend** — runs the backend test suite with coverage, publishes the
  coverage report via Smokeshow.

Both workflows are triggered by pushes and pull requests to `master`.

### What the Backend Test Suite Does

`scripts/tests-start.sh` (the test entry point) runs:

1. `python app/tests_pre_start.py` — waits for the database with tenacity retry logic
   (same pattern as `backend_pre_start.py`).
2. `bash scripts/test.sh` — runs `coverage run -m pytest tests/`, then
   `coverage report` and `coverage html`.

Coverage is captured with `pytest-cov`. The HTML report is written to
`backend/htmlcov/`.

### CI Secrets Required

- `SMOKESHOW_AUTH_KEY` — needed to publish the coverage HTML to Smokeshow.
- `LATEST_CHANGES` — personal access token used by the `latest-changes` action
  to auto-append release notes from merged PRs.

Neither secret is inlined in source. Both must be set as environment-scoped
GitHub Secrets (preferably on the `staging` and `production` environments, not
as repository-wide secrets).

---

## CD — Continuous Deployment

Deployment uses **self-hosted GitHub Actions runners** registered on each
target server (see deployment.md for runner installation steps).

### Deployment Triggers

| Environment | Trigger | Runner label |
|-------------|---------|--------------|
| staging     | Push or merge to `master` | `staging` |
| production  | Publishing a GitHub Release | `production` |

Both deployments target their respective GitHub Environment (`staging`,
`production`), which enables:
- Environment-specific secrets scoped to that environment.
- Deployment protection rules (required reviewers, wait timers) configurable
  per environment in Settings > Environments.
- Deployment status visible in the repository's Environments panel.

### Deployment Steps (Per Workflow)

A deploy workflow on the self-hosted runner would:

1. SSH / run locally on the server (runner is on the server).
2. `rsync` or `git pull` latest code to `/root/code/app/`.
3. Build images: `docker compose -f compose.yml build`.
4. Roll the stack: `docker compose -f compose.yml up -d`.

Note: `compose.override.yml` is intentionally excluded from production deploys
(it adds dev-only settings like hot-reload and exposed Postgres port).

### Environment Secrets (from deployment.md)

The workflows read these secrets from their respective GitHub Environment:

```
DOMAIN_PRODUCTION          DOMAIN_STAGING
STACK_NAME_PRODUCTION      STACK_NAME_STAGING
EMAILS_FROM_EMAIL
FIRST_SUPERUSER
FIRST_SUPERUSER_PASSWORD
POSTGRES_PASSWORD
SECRET_KEY
LATEST_CHANGES
SMOKESHOW_AUTH_KEY
```

All secrets are read from GitHub Environment variables — none are inlined in
compose files or committed to the repository. Secrets with default value
`changethis` in `.env` (SECRET_KEY, POSTGRES_PASSWORD, FIRST_SUPERUSER_PASSWORD)
**must** be overridden before any non-local deploy.

---

## uv Workspace Layout (from pyproject.toml)

The root `pyproject.toml` defines a uv workspace with one member: `backend`.

```toml
[tool.uv.workspace]
members = ["backend"]

[dependency-groups]
dev = ["zizmor>=1.23.1"]
github-actions = ["smokeshow >=0.5.0"]
```

`zizmor` (GitHub Actions security linter) is a root dev dependency. It runs via
the `zizmor` pre-commit hook whenever `.github/workflows/` files change.

`smokeshow` is in the `github-actions` dependency group — only installed in the
CI environment, not locally.

---

## Lint Gate (local, from backend/scripts/lint.sh)

Before opening a PR, run the full lint suite:

```bash
cd backend
bash scripts/lint.sh
```

This runs: `mypy app`, `ty check app`, `ruff check app`, `ruff format app --check`.
All four must pass. mypy is strict (`strict = true` in `backend/pyproject.toml`).

---

## Rollback

**Staging:** `git revert <sha>` + push to `master` → re-triggers staging deploy.

**Production:** revert the GitHub Release tag or publish a new release from a
known-good commit. Self-hosted runner picks up the new release event.
