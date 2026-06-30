# Branching Strategy and PR Workflow — full-stack-fastapi-template

Source of truth: CONTRIBUTING.md, deployment.md, .github/labeler.yml, .pre-commit-config.yaml

---

## Default Branch

The repository uses **`master`** as its default and integration branch (not `main`).
All feature work is merged into `master`. Confirmed in README.md ("Push the code to
your new repository: `git push -u origin master`") and deployment.md ("staging: after
pushing (or merging) to the branch `master`").

---

## Branch Model

```
master          — integration; every merge triggers staging deploy
  └── feature/* — short-lived feature branches
  └── fix/*     — short-lived bug-fix branches
release         — cut by publishing a GitHub Release; triggers production deploy
```

There is no long-lived `develop` branch. Work flows directly to `master` via PR.

---

## PR Rules (from CONTRIBUTING.md)

1. All tests must pass before submitting.
2. PRs must be focused on a single change.
3. Tests must be updated whenever functionality changes.
4. Related issues must be referenced in the PR description.
5. PRs from non-team members are not allowed to modify `pyproject.toml` or `uv.lock`
   (supply-chain protection). Dependency additions require a GitHub Discussion first.
6. For large changes (new features, architectural changes, significant refactoring)
   open a GitHub Discussion before opening a PR.
7. Small, self-contained changes (typos, minor bug fixes, lint clean-up) can go
   directly to a PR.

---

## Automated Labels (from .github/labeler.yml)

Two labels are applied automatically by GitHub's label-sync action:

| Label      | Trigger files |
|------------|---------------|
| `docs`     | Any `*.md` outside `frontend/`, `backend/`, `.github/`, `scripts/` |
| `internal` | `.github/**`, `scripts/**`, `.gitignore`, `.pre-commit-config.yaml` (excluding `.md`, `frontend/`, `backend/`) |

These labels are used to categorise PRs in release notes.

---

## Dependabot (from .github/dependabot.yml)

Dependabot runs weekly across five ecosystems, all with a 7-day cooldown:

| Ecosystem       | Directory           | Commit prefix |
|-----------------|---------------------|---------------|
| github-actions  | `/`                 | `⬆`           |
| uv (Python)     | `/`                 | `⬆`           |
| bun (Node)      | `/`                 | `⬆`           |
| docker          | `/backend`, `/frontend` | `⬆`      |
| docker-compose  | `/`                 | `⬆`           |
| pre-commit      | `/`                 | `⬆`           |

Dependabot PRs are grouped (one PR per ecosystem per week). The `@hey-api/openapi-ts`
bun package is excluded from auto-updates.

Dependabot PRs carry the `internal` and `dependencies` labels. Accept them the same
way as any other PR — they go through the pre-commit hook suite before merge.

---

## Pre-commit Hooks (from .pre-commit-config.yaml and development.md)

The pre-commit tool is **prek** (a modern alternative to pre-commit), which is a
dev dependency in `backend/pyproject.toml`.

Install once inside the `backend/` directory:

```bash
uv run prek install -f
```

Hooks that run on every `git commit`:

| Hook ID                 | What it checks |
|-------------------------|---------------|
| check-added-large-files | Blocks large binary files |
| check-toml              | TOML syntax |
| check-yaml              | YAML syntax (--unsafe to support custom tags) |
| end-of-file-fixer       | Ensures files end with newline (excludes generated client + email templates) |
| trailing-whitespace     | Removes trailing spaces (excludes generated frontend client) |
| local-biome-check       | `npm run lint` — Biome linter on `frontend/` |
| local-ruff-check        | `uv run ruff check --force-exclude --fix` on Python files |
| local-ruff-format       | `uv run ruff format --force-exclude` on Python files |
| local-mypy              | `uv run mypy backend/app` — strict mypy on the whole backend app |
| local-ty                | `uv run ty check backend/app` — ty type checker |
| generate-frontend-sdk   | Runs `scripts/generate-client.sh` when any `backend/` file changes |
| add-release-date        | Stamps the latest release header in `release-notes.md` |
| zizmor                  | GitHub Actions workflow security audit (only runs when `.github/workflows/**` changes) |

Run all hooks manually without committing:

```bash
uv run prek run --all-files
```

**Important:** The `generate-frontend-sdk` hook regenerates the TypeScript API client
from the OpenAPI schema whenever backend files change. If this hook modifies files,
the commit is blocked — stage the regenerated client and commit again.

---

## Rollback

A bad merge to `master` that triggered a staging deploy can be reverted with:

```bash
git revert <merge-sha>
git push origin master
```

This creates a new commit visible in history and re-triggers the staging deploy
with the reverted code. Do not force-push `master`.
